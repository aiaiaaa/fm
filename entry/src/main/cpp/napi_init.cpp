/**
 * NAPI bindings for the X.FM spectrum analyzer.
 *
 * Exposed JS API (see types/libxfm_spectrum/Index.d.ts):
 *   create(onBands)           -> handle
 *   feedAdts(handle, bytes)
 *   reset(handle)
 *   destroy(handle)
 *
 * Threading & pacing:
 *   HLS delivers a whole 5s segment in one network burst, which the codec
 *   then chews through in ~200ms producing ~215 FFT-band frames back to back.
 *   If we forward those raw to ArkTS the UI sees a 200ms flurry followed by
 *   ~4.8s of silence — visually it looks like the spectrum is "barely
 *   moving". To fix that we keep an internal ring buffer of band frames
 *   and drain it on a steady ~30fps pacing thread that hands them to JS at
 *   the *playback* rate, not the *decode* rate.
 *
 *   layout per instance:
 *     codec thread  →  analyzer  →  ring buffer (this file)
 *                                       │
 *                                pacing thread (33ms tick)
 *                                       │
 *                                 napi_threadsafe_function
 *                                       │
 *                                  ArkTS bands callback
 *
 * Note on logging:
 *   HarmonyOS hilog redacts every numeric/string format placeholder as
 *   <private> by default. Use %{public}... explicitly when we want the
 *   real value to show up.
 */

#include <atomic>
#include <chrono>
#include <condition_variable>
#include <cstring>
#include <deque>
#include <memory>
#include <mutex>
#include <thread>
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

// Pace bands out at FFT-frame rate (1024 samples / 44.1kHz ≈ 23.2ms).
// Each AAC frame produces exactly one bands frame in the analyzer, so a
// 5-second segment of audio decodes to ~217 bands frames; emitting them
// at 23ms each yields ~5 seconds of UI updates — exactly matching audio
// playback time. If the pacer ever drains faster than decode (e.g. the
// network stalls), we hold the last emitted frame so the UI doesn't
// freeze visibly. If decode bursts faster, we cap the ring at 256
// frames (~6s) and drop oldest, keeping latency bounded.
constexpr int kPaceIntervalMs = 23;
// Cap ring at ~750ms of bands. Anything bigger and the visualization drifts
// behind the audio: HLS bursts a 5s segment of decoded frames at once, the
// pacer can only drain 23ms each tick, so a fat ring guarantees lag.
// 32 frames * 23ms ≈ 736ms — enough cushion to ride out one segment fetch
// without underrun, while keeping bands within ~1s of what the user hears.
constexpr size_t kRingMax = 32;

// One instance per ArkTS visualizer. Identified by a numeric handle.
struct Instance {
    std::unique_ptr<xfm::AacDecoder> decoder;
    std::unique_ptr<xfm::SpectrumAnalyzer> analyzer;
    napi_threadsafe_function tsfn = nullptr;
    bool decoder_inited = false;

    // pacing
    std::thread pacer;
    std::mutex ring_mtx;
    std::condition_variable ring_cv;
    std::deque<std::vector<float>> ring; // FIFO of band frames waiting to emit
    std::atomic<bool> pacer_run{false};
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

// Track stats so you can grep hilog and see what's actually going on
std::atomic<uint32_t> g_adts_fed{0};
std::atomic<uint32_t> g_bands_produced{0};
std::atomic<uint32_t> g_bands_emitted{0};

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

/**
 * Pacer thread: every kPaceIntervalMs, pop one frame from the ring (or hold
 * the last emitted frame if empty) and dispatch it to JS via tsfn.
 *
 * Why a dedicated thread vs. an in-thread timer: napi has no native timer,
 * and we don't want to depend on the JS event loop for pacing (it stalls
 * during heavy ArkTS work). std::thread + sleep_for is dead simple and
 * gives us a steady drumbeat.
 */
void PacerLoop(std::shared_ptr<Instance> inst) {
    while (inst->pacer_run.load(std::memory_order_acquire)) {
        auto next_tick = std::chrono::steady_clock::now() +
                         std::chrono::milliseconds(kPaceIntervalMs);

        std::vector<float> frame;
        {
            std::unique_lock<std::mutex> lk(inst->ring_mtx);
            if (!inst->ring.empty()) {
                frame = std::move(inst->ring.front());
                inst->ring.pop_front();
            } else {
                // Underrun: skip the tick — do NOT re-emit a stale frame.
                // Re-emission produced a stutter pattern (frame, frame,
                // frame, NEW, frame, frame, NEW, ...) that looked like
                // jitter; skipping ticks lets the UI hold steady on
                // whatever it last had until fresh data arrives.
                std::this_thread::sleep_until(next_tick);
                continue;
            }
        }

        if (inst->tsfn != nullptr) {
            uint32_t emitted = ++g_bands_emitted;
            if (emitted == 1 || emitted == 30 || (emitted % 300) == 0) {
                LOGW("paced bands emit: total=%{public}u (b0=%{public}.2f b8=%{public}.2f b15=%{public}.2f)",
                     emitted, frame.empty() ? 0.0f : frame[0],
                     frame.size() > 8 ? frame[8] : 0.0f,
                     frame.size() > 15 ? frame[15] : 0.0f);
            }
            auto* copy = new std::vector<float>(std::move(frame));
            napi_status status = napi_call_threadsafe_function(inst->tsfn, copy, napi_tsfn_nonblocking);
            if (status != napi_ok) {
                delete copy;
            }
        }

        std::this_thread::sleep_until(next_tick);
    }
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

    // Analyzer pushes into the ring, the pacer drains it. Capture a weak
    // shared_ptr-like raw pointer on the analyzer side; lifetime is bounded
    // by Destroy() which joins the pacer before returning.
    Instance* raw = inst.get();
    inst->analyzer = std::make_unique<xfm::SpectrumAnalyzer>([raw](const std::vector<float>& bands) {
        ++g_bands_produced;
        std::lock_guard<std::mutex> lk(raw->ring_mtx);
        if (raw->ring.size() >= kRingMax) {
            // Drop oldest to bound latency. Visualization doesn't care about
            // a 200ms-ago band frame when 8s of newer ones are queued.
            raw->ring.pop_front();
        }
        raw->ring.emplace_back(bands);
        raw->ring_cv.notify_one();
    });

    inst->decoder = std::make_unique<xfm::AacDecoder>();

    // Start pacing thread.
    inst->pacer_run.store(true, std::memory_order_release);
    inst->pacer = std::thread(PacerLoop, inst);

    uint32_t handle = g_next_handle.fetch_add(1);
    {
        std::lock_guard<std::mutex> lock(g_mtx);
        g_instances[handle] = inst;
    }

    napi_value result;
    napi_create_uint32(env, handle, &result);
    LOGW("create -> handle=%{public}u (paced @ %{public}dms)", handle, kPaceIntervalMs);
    return result;
}

napi_value FeedAdts(napi_env env, napi_callback_info info) {
    // Diagnostic: track entries to feedAdts itself so we can prove ArkTS
    // is actually calling us. Print on entry 1 / 5 / 10 / every 200 thereafter.
    static std::atomic<uint32_t> entries{0};
    uint32_t entry = ++entries;
    if (entry == 1 || entry == 5 || entry == 10 || (entry % 200) == 0) {
        LOGW("feedAdts ENTRY #%{public}u", entry);
    }

    size_t argc = 2;
    napi_value argv[2];
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    if (argc < 2) {
        LOGE("feedAdts: missing args (argc=%{public}zu)", argc);
        napi_throw_error(env, nullptr, "feedAdts(handle, frame): missing args");
        return nullptr;
    }
    uint32_t handle = 0;
    napi_get_value_uint32(env, argv[0], &handle);
    auto inst = FindInstance(handle);
    if (!inst) {
        if (entry < 10) LOGW("feedAdts: no instance for handle=%{public}u", handle);
        return nullptr;
    }

    bool is_typedarray = false;
    napi_is_typedarray(env, argv[1], &is_typedarray);
    if (!is_typedarray) {
        LOGE("feedAdts: frame must be Uint8Array");
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
        if (entry < 10) {
            LOGW("feedAdts: typedarray rejected status=%{public}d type=%{public}d len=%{public}zu",
                 (int)s, (int)type, length);
        }
        return nullptr;
    }
    const uint8_t* bytes = static_cast<const uint8_t*>(data);

    // Lazy decoder init from first frame's ADTS header
    if (!inst->decoder_inited) {
        AdtsHeader hdr{};
        if (!ParseAdtsHeader(bytes, length, hdr)) {
            if (entry < 5) {
                LOGW("feedAdts: ADTS header parse failed (b0=%{public}02x b1=%{public}02x len=%{public}zu)",
                     bytes[0], length > 1 ? bytes[1] : 0, length);
            }
            return nullptr; // wait for a valid frame
        }
        // PCM callback hops directly into the analyzer (same internal thread).
        xfm::SpectrumAnalyzer* analyzer_ptr = inst->analyzer.get();
        bool ok = inst->decoder->Init(hdr.sample_rate, hdr.channels,
            [analyzer_ptr](const int16_t* samples, size_t count, int sr, int ch) {
                if (analyzer_ptr) analyzer_ptr->FeedPcm(samples, count, sr, ch);
            });
        if (!ok) {
            LOGE("decoder init FAILED (sr=%{public}d ch=%{public}d) -- check xfm_aac log",
                 hdr.sample_rate, hdr.channels);
            return nullptr;
        }
        inst->decoder_inited = true;
        LOGW("decoder inited from first ADTS: sr=%{public}d ch=%{public}d", hdr.sample_rate, hdr.channels);
    }

    inst->decoder->FeedAdts(bytes, length);
    uint32_t fed = ++g_adts_fed;
    if (fed == 1 || fed == 10 || fed == 50 || (fed % 200) == 0) {
        LOGW("feedAdts stats: total=%{public}u (last frame=%{public}zub)", fed, length);
    }
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
    {
        std::lock_guard<std::mutex> lk(inst->ring_mtx);
        inst->ring.clear();
    }
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
        // Stop pacer first so it doesn't try to use tsfn after we release it.
        inst->pacer_run.store(false, std::memory_order_release);
        {
            std::lock_guard<std::mutex> lk(inst->ring_mtx);
            inst->ring.clear();
        }
        inst->ring_cv.notify_all();
        if (inst->pacer.joinable()) inst->pacer.join();

        if (inst->decoder) inst->decoder->Release();
        if (inst->tsfn) {
            napi_release_threadsafe_function(inst->tsfn, napi_tsfn_release);
            inst->tsfn = nullptr;
        }
    }
    LOGW("destroy handle=%{public}u (produced=%{public}u emitted=%{public}u)",
         handle, g_bands_produced.load(), g_bands_emitted.load());
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
    LOGW("xfm_spectrum module loaded");
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
