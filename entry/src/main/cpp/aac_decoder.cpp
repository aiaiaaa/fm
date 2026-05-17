#include "aac_decoder.h"

#include <cstring>
#include <hilog/log.h>
#include <multimedia/player_framework/native_avformat.h>
#include <multimedia/player_framework/native_avcodec_base.h>

#define LOG_TAG "xfm_aac"
#define LOGI(fmt, ...) OH_LOG_Print(LOG_APP, LOG_INFO, 0x0000, LOG_TAG, fmt, ##__VA_ARGS__)
#define LOGW(fmt, ...) OH_LOG_Print(LOG_APP, LOG_WARN, 0x0000, LOG_TAG, fmt, ##__VA_ARGS__)
#define LOGE(fmt, ...) OH_LOG_Print(LOG_APP, LOG_ERROR, 0x0000, LOG_TAG, fmt, ##__VA_ARGS__)

namespace xfm {

namespace {

// Static thunks: OH_AudioCodec callbacks pass userData. We forward to the instance.
void OnErrorThunk(OH_AVCodec* /*codec*/, int32_t errorCode, void* userData) {
    if (userData) static_cast<AacDecoder*>(userData)->OnError(errorCode);
}
void OnStreamChangedThunk(OH_AVCodec* /*codec*/, OH_AVFormat* format, void* userData) {
    if (userData) static_cast<AacDecoder*>(userData)->OnStreamChanged(format);
}
void OnInputBufferAvailableThunk(OH_AVCodec* /*codec*/, uint32_t index, OH_AVBuffer* buffer, void* userData) {
    if (userData) static_cast<AacDecoder*>(userData)->OnInputBufferAvailable(index, buffer);
}
void OnOutputBufferAvailableThunk(OH_AVCodec* /*codec*/, uint32_t index, OH_AVBuffer* buffer, void* userData) {
    if (userData) static_cast<AacDecoder*>(userData)->OnOutputBufferAvailable(index, buffer);
}

} // namespace

AacDecoder::AacDecoder() = default;

AacDecoder::~AacDecoder() {
    Release();
}

bool AacDecoder::Init(int sample_rate, int channels, PcmCallback on_pcm) {
    sample_rate_ = sample_rate;
    channels_ = channels;
    on_pcm_ = std::move(on_pcm);

    // OH_AVCODEC_MIMETYPE_AUDIO_AAC = "audio/mp4a-latm"
    codec_ = OH_AudioCodec_CreateByMime(OH_AVCODEC_MIMETYPE_AUDIO_AAC, false /* isEncoder */);
    if (codec_ == nullptr) {
        LOGE("OH_AudioCodec_CreateByMime returned null");
        return false;
    }

    OH_AVCodecCallback cb {
        .onError = OnErrorThunk,
        .onStreamChanged = OnStreamChangedThunk,
        .onNeedInputBuffer = OnInputBufferAvailableThunk,
        .onNewOutputBuffer = OnOutputBufferAvailableThunk
    };
    OH_AVErrCode rc = OH_AudioCodec_RegisterCallback(codec_, cb, this);
    if (rc != AV_ERR_OK) {
        LOGE("RegisterCallback failed: %d", rc);
        return false;
    }

    OH_AVFormat* fmt = OH_AVFormat_Create();
    OH_AVFormat_SetIntValue(fmt, OH_MD_KEY_AUD_SAMPLE_RATE, sample_rate);
    OH_AVFormat_SetIntValue(fmt, OH_MD_KEY_AUD_CHANNEL_COUNT, channels);
    // Output PCM is signed 16 LE (1 = AUDIO_SAMPLE_S16LE in the OH_BitsPerSample enum).
    OH_AVFormat_SetIntValue(fmt, OH_MD_KEY_AUDIO_SAMPLE_FORMAT, 1);
    // Input is ADTS framed
    OH_AVFormat_SetIntValue(fmt, OH_MD_KEY_AAC_IS_ADTS, 1);

    rc = OH_AudioCodec_Configure(codec_, fmt);
    OH_AVFormat_Destroy(fmt);
    if (rc != AV_ERR_OK) {
        LOGE("Configure failed: %d", rc);
        return false;
    }

    rc = OH_AudioCodec_Prepare(codec_);
    if (rc != AV_ERR_OK) {
        LOGE("Prepare failed: %d", rc);
        return false;
    }

    rc = OH_AudioCodec_Start(codec_);
    if (rc != AV_ERR_OK) {
        LOGE("Start failed: %d", rc);
        return false;
    }

    ready_ = true;
    LOGI("AAC decoder ready @ %dHz x%d", sample_rate, channels);
    return true;
}

void AacDecoder::FeedAdts(const uint8_t* data, size_t size) {
    if (!ready_ || codec_ == nullptr || data == nullptr || size == 0) return;

    uint32_t index = 0;
    OH_AVBuffer* buffer = nullptr;
    {
        std::lock_guard<std::mutex> lock(mtx_);
        if (free_input_buffers_.empty()) {
            // No input slot available; drop. ADTS frames are 23ms each, occasional drops are fine
            // for visualization (we can't pre-buffer indefinitely without bloating memory).
            return;
        }
        auto front = free_input_buffers_.front();
        free_input_buffers_.pop();
        index = front.first;
        buffer = front.second;
    }
    if (buffer == nullptr) return;

    uint8_t* addr = OH_AVBuffer_GetAddr(buffer);
    int32_t cap = OH_AVBuffer_GetCapacity(buffer);
    if (addr == nullptr || cap <= 0 || static_cast<int32_t>(size) > cap) {
        LOGW("input buffer too small: cap=%d need=%zu", cap, size);
        return;
    }
    std::memcpy(addr, data, size);

    OH_AVCodecBufferAttr attr{};
    attr.size = static_cast<int32_t>(size);
    attr.offset = 0;
    attr.pts = pts_us_;
    attr.flags = 0;
    pts_us_ += static_cast<int64_t>(1024.0 * 1'000'000.0 / sample_rate_);

    OH_AVErrCode rc = OH_AVBuffer_SetBufferAttr(buffer, &attr);
    if (rc != AV_ERR_OK) {
        LOGW("SetBufferAttr failed: %d", rc);
        return;
    }
    rc = OH_AudioCodec_PushInputBuffer(codec_, index);
    if (rc != AV_ERR_OK) {
        LOGW("PushInputBuffer failed: %d", rc);
    }
}

void AacDecoder::Reset() {
    if (codec_ == nullptr) return;
    OH_AudioCodec_Flush(codec_);
    {
        std::lock_guard<std::mutex> lock(mtx_);
        // The codec gives us fresh indices after flush, so drop stale ones.
        std::queue<std::pair<uint32_t, OH_AVBuffer*>> empty;
        std::swap(free_input_buffers_, empty);
    }
    pts_us_ = 0;
    OH_AudioCodec_Start(codec_);
}

void AacDecoder::Release() {
    ready_ = false;
    if (codec_ != nullptr) {
        OH_AudioCodec_Stop(codec_);
        OH_AudioCodec_Destroy(codec_);
        codec_ = nullptr;
    }
    on_pcm_ = nullptr;
    {
        std::lock_guard<std::mutex> lock(mtx_);
        std::queue<std::pair<uint32_t, OH_AVBuffer*>> empty;
        std::swap(free_input_buffers_, empty);
    }
}

void AacDecoder::OnInputBufferAvailable(uint32_t index, OH_AVBuffer* buffer) {
    std::lock_guard<std::mutex> lock(mtx_);
    free_input_buffers_.emplace(index, buffer);
}

void AacDecoder::OnOutputBufferAvailable(uint32_t index, OH_AVBuffer* buffer) {
    if (codec_ == nullptr || buffer == nullptr) return;

    OH_AVCodecBufferAttr attr{};
    OH_AVErrCode rc = OH_AVBuffer_GetBufferAttr(buffer, &attr);
    if (rc != AV_ERR_OK || attr.size <= 0) {
        OH_AudioCodec_FreeOutputBuffer(codec_, index);
        return;
    }
    uint8_t* addr = OH_AVBuffer_GetAddr(buffer);
    if (addr != nullptr && on_pcm_) {
        // attr.size is in bytes (s16le interleaved); samples per channel = size/2/channels
        const int16_t* pcm = reinterpret_cast<const int16_t*>(addr + attr.offset);
        size_t total_i16 = static_cast<size_t>(attr.size) / sizeof(int16_t);
        on_pcm_(pcm, total_i16, sample_rate_, channels_);
    }
    OH_AudioCodec_FreeOutputBuffer(codec_, index);
}

void AacDecoder::OnError(int32_t error_code) {
    LOGE("codec error: %d", error_code);
}

void AacDecoder::OnStreamChanged(OH_AVFormat* format) {
    if (format == nullptr) return;
    int32_t sr = sample_rate_, ch = channels_;
    OH_AVFormat_GetIntValue(format, OH_MD_KEY_AUD_SAMPLE_RATE, &sr);
    OH_AVFormat_GetIntValue(format, OH_MD_KEY_AUD_CHANNEL_COUNT, &ch);
    sample_rate_ = sr;
    channels_ = ch;
    LOGI("stream changed: %dHz x%d", sr, ch);
}

} // namespace xfm
