/**
 * NAPI bindings for the X.FM spectrum analyzer.
 *
 * Exposed JS API (see types/libxfm_spectrum/Index.d.ts):
 *   create(onBands)           -> handle
 *   feedAdts(handle, bytes)
 *   reset(handle)
 *   destroy(handle)
 *
 * Threading:
 *   The OH_AudioCodec dispatches output buffers on a codec-internal thread.
 *   We funnel each band frame through napi_threadsafe_function so the JS
 *   callback always runs on the original ArkTS thread.
 */

#include <atomic>
#include <cstring>
#include <memory>
#include <mutex>
#include <unordered_map>
#include <vector>

#include <hilog/log.h>
#include <napi/native_api.h>

#include "aac_decoder.h"
#include "spectrum.h"

#define LOG_TAG "xfm_napi"
#define LOGI(fmt, ...) OH_LOG_Print(LOG_APP, LOG_INFO, 0x0000, LOG_TAG, fmt, ##__VA_ARGS__)
#define LOGW(fmt, ...) OH_LOG_Print(LOG_APP, LOG_WARN, 0x0000, LOG_TAG, fmt, ##__VA_ARGS__)
#define LOGE(fmt, ...) OH_LOG_Print(LOG_APP, LOG_ERROR, 0x0000, LOG_TAG, fmt, ##__VA_ARGS__)

namespace {

// One instance per ArkTS visualizer. Identified by a numeric handle.
struct Instance {
    std::unique_ptr<xfm::AacDecoder> decoder;
    std::unique_ptr<xfm::SpectrumAnalyzer> analyzer;
    napi_threadsafe_function tsfn = nullptr;
    bool decoder_inited = false;
};

// Global registry of instances. Handle 0 is reserved as "invalid".
std::mutex g_mtx;
std::unordered_map<uint32_t, std::shared_ptr<Instance>> g_instances;
std::atomic<uint32_t> g_next_handle{1};

std::shared_ptr<Instance> FindInstance(uint32_t handle) {
    std::lock_guard<std::mutex> lock(g_mtx);
    auto it = g_instances.find(handle);
    if (it == g_instances.end()) return nullptr;
    return it->second;
}

/**
 * Parse ADTS sampling rate + channel count from a frame header.
 *   sampling_frequency_index = bits 18..21 (0-indexed from MSB)
 *   channel_configuration   = bits 23..25
 */
struct AdtsHeader {
    int sample_rate;
    int channels;
};
bool ParseAdtsHeader(const uint8_t* data, size_t size, AdtsHeader& out) {
    if (size < 7) return false;
    if (data[0] != 0xFF || (data[1] & 0xF0) != 0xF0) return false;
    static const int kSampleRateTable[16] = {
        96000, 88200, 64000, 48000, 44100, 32000, 24000, 22050,
        16000, 12000, 11025, 8000, 7350, 0, 0, 0
    };
    int sf_index = (data[2] >> 2) & 0x0F;
    int channels = ((data[2] & 0x01) << 2) | ((data[3] >> 6) & 0x03);
    int sr = kSampleRateTable[sf_index];
    if (sr == 0 || channels == 0) return false;
    out.sample_rate = sr;
    out.channels = channels;
    return true;
}

/**
 * Bands callback target: called on JS thread by napi_threadsafe_function.
 * `data` is a heap-allocated std::vector<float>* we own and must delete.
 */
void CallJsBands(napi_env env, napi_value js_callback, void* /*context*/, void* data) {
    auto* bands = static_cast<std::vector<float>*>(data);
    if (env == nullptr || js_callback == nullptr || bands == nullptr) {
        delete bands;
        return;
    }
    napi_value array;
    napi_create_array_with_length(env, bands->size(), &array);
    for (size_t i = 0; i < bands->size(); ++i) {
        napi_value v;
        napi_create_double(env, static_cast<double>((*bands)[i]), &v);
        napi_set_element(env, array, i, v);
    }
    napi_value undefined;
    napi_get_undefined(env, &undefined);
    napi_value argv[1] = { array };
    napi_call_function(env, undefined, js_callback, 1, argv, nullptr);
    delete bands;
}

// === JS-exposed methods ===

napi_value Create(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value argv[1];
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    if (argc < 1) {
        napi_throw_error(env, nullptr, "create(onBands): missing callback");
        return nullptr;
    }
    napi_valuetype t;
    napi_typeof(env, argv[0], &t);
    if (t != napi_function) {
        napi_throw_error(env, nullptr, "create(onBands): callback must be a function");
        return nullptr;
    }

    auto inst = std::make_shared<Instance>();

    napi_value name;
    napi_create_string_utf8(env, "xfmSpectrumBands", NAPI_AUTO_LENGTH, &name);
    napi_status s = napi_create_threadsafe_function(
        env, argv[0], nullptr, name,
        /*max_queue_size*/ 0, /*initial_thread_count*/ 1,
        /*thread_finalize_data*/ nullptr,
        /*finalize_cb*/ nullptr,
        /*context*/ nullptr,
        CallJsBands,
        &inst->tsfn);
    if (s != napi_ok || inst->tsfn == nullptr) {
        napi_throw_error(env, nullptr, "create: napi_create_threadsafe_function failed");
        return nullptr;
    }

    // Analyzer emits std::vector<float>; we marshal to JS thread.
    napi_threadsafe_function tsfn = inst->tsfn;
    inst->analyzer = std::make_unique<xfm::SpectrumAnalyzer>([tsfn](const std::vector<float>& bands) {
        auto* copy = new std::vector<float>(bands);
        napi_status status = napi_call_threadsafe_function(tsfn, copy, napi_tsfn_nonblocking);
        if (status != napi_ok) {
            // Queue full or thread-safe func dead; drop this frame.
            delete copy;
        }
    });

    inst->decoder = std::make_unique<xfm::AacDecoder>();

    uint32_t handle = g_next_handle.fetch_add(1);
    {
        std::lock_guard<std::mutex> lock(g_mtx);
        g_instances[handle] = inst;
    }

    napi_value result;
    napi_create_uint32(env, handle, &result);
    LOGI("create -> handle=%u", handle);
    return result;
}

napi_value FeedAdts(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value argv[2];
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    if (argc < 2) {
        napi_throw_error(env, nullptr, "feedAdts(handle, frame): missing args");
        return nullptr;
    }
    uint32_t handle = 0;
    napi_get_value_uint32(env, argv[0], &handle);
    auto inst = FindInstance(handle);
    if (!inst) return nullptr;

    bool is_typedarray = false;
    napi_is_typedarray(env, argv[1], &is_typedarray);
    if (!is_typedarray) {
        napi_throw_error(env, nullptr, "feedAdts: frame must be Uint8Array");
        return nullptr;
    }

    napi_typedarray_type type;
    size_t length = 0;
    void* data = nullptr;
    napi_value array_buffer;
    size_t byte_offset = 0;
    napi_status s = napi_get_typedarray_info(env, argv[1], &type, &length, &data,
                                             &array_buffer, &byte_offset);
    if (s != napi_ok || data == nullptr || length == 0 || type != napi_uint8_array) {
        return nullptr;
    }
    const uint8_t* bytes = static_cast<const uint8_t*>(data);

    // Lazy decoder init from first frame's ADTS header
    if (!inst->decoder_inited) {
        AdtsHeader hdr{};
        if (!ParseAdtsHeader(bytes, length, hdr)) {
            return nullptr; // wait for a valid frame
        }
        // PCM callback hops directly into the analyzer (same internal thread).
        xfm::SpectrumAnalyzer* analyzer_ptr = inst->analyzer.get();
        bool ok = inst->decoder->Init(hdr.sample_rate, hdr.channels,
            [analyzer_ptr](const int16_t* samples, size_t count, int sr, int ch) {
                if (analyzer_ptr) analyzer_ptr->FeedPcm(samples, count, sr, ch);
            });
        if (!ok) {
            LOGE("decoder init failed (handle=%u, sr=%d, ch=%d)", handle, hdr.sample_rate, hdr.channels);
            return nullptr;
        }
        inst->decoder_inited = true;
    }

    inst->decoder->FeedAdts(bytes, length);
    return nullptr;
}

napi_value Reset(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value argv[1];
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    if (argc < 1) return nullptr;
    uint32_t handle = 0;
    napi_get_value_uint32(env, argv[0], &handle);
    auto inst = FindInstance(handle);
    if (!inst) return nullptr;
    if (inst->decoder) inst->decoder->Reset();
    if (inst->analyzer) inst->analyzer->Reset();
    return nullptr;
}

napi_value Destroy(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value argv[1];
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    if (argc < 1) return nullptr;
    uint32_t handle = 0;
    napi_get_value_uint32(env, argv[0], &handle);

    std::shared_ptr<Instance> inst;
    {
        std::lock_guard<std::mutex> lock(g_mtx);
        auto it = g_instances.find(handle);
        if (it == g_instances.end()) return nullptr;
        inst = it->second;
        g_instances.erase(it);
    }
    if (inst) {
        if (inst->decoder) inst->decoder->Release();
        if (inst->tsfn) {
            napi_release_threadsafe_function(inst->tsfn, napi_tsfn_release);
            inst->tsfn = nullptr;
        }
    }
    LOGI("destroy handle=%u", handle);
    return nullptr;
}

napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor descs[] = {
        { "create",   nullptr, Create,   nullptr, nullptr, nullptr, napi_default, nullptr },
        { "feedAdts", nullptr, FeedAdts, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "reset",    nullptr, Reset,    nullptr, nullptr, nullptr, napi_default, nullptr },
        { "destroy",  nullptr, Destroy,  nullptr, nullptr, nullptr, napi_default, nullptr },
    };
    napi_define_properties(env, exports, sizeof(descs) / sizeof(descs[0]), descs);
    return exports;
}

} // namespace

extern "C" __attribute__((constructor)) void RegisterXfmSpectrum(void) {
    static napi_module module = {
        .nm_version = 1,
        .nm_flags = 0,
        .nm_filename = nullptr,
        .nm_register_func = Init,
        .nm_modname = "xfm_spectrum",
        .nm_priv = nullptr,
        .reserved = { nullptr },
    };
    napi_module_register(&module);
}
