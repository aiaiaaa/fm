#ifndef XFM_AAC_DECODER_H
#define XFM_AAC_DECODER_H

#include <cstdint>
#include <functional>
#include <mutex>
#include <queue>
#include <vector>

#include <multimedia/player_framework/native_avcodec_audiocodec.h>
#include <multimedia/player_framework/native_avbuffer.h>

namespace xfm {

/**
 * Wraps OH_AudioCodec for one-shot AAC ADTS -> PCM decoding.
 *
 * Lifecycle:
 *   1) Init() with the sample rate / channel count parsed from the first ADTS frame.
 *   2) FeedAdts(...) called for each frame. Buffers are queued asynchronously into the
 *      codec; PCM comes back via on_pcm callback (always s16le interleaved).
 *   3) Reset() to flush internal state on stream change / pause.
 *   4) Destructor releases all native resources.
 *
 * Thread model:
 *   The OH_AudioCodec callbacks fire on a codec-internal thread. We funnel input
 *   buffer indices into input_idx_queue_ guarded by mtx_; FeedAdts() pulls from there
 *   when called from the caller thread (FeedAdts is expected to be called from the
 *   single demux thread).
 */
class AacDecoder {
public:
    using PcmCallback = std::function<void(const int16_t* samples, size_t count, int sample_rate, int channels)>;

    AacDecoder();
    ~AacDecoder();

    /**
     * Initialize with sample rate and channel count parsed from ADTS.
     * Returns false if codec creation/configure/start fails.
     */
    bool Init(int sample_rate, int channels, PcmCallback on_pcm);

    /**
     * Queue an ADTS frame (with header). Non-blocking: drops frames if input queue is starved.
     * Safe to call only from the same thread.
     */
    void FeedAdts(const uint8_t* data, size_t size);

    /**
     * Flush internal state, keep the codec alive.
     */
    void Reset();

    /**
     * Stop and release.
     */
    void Release();

    bool IsReady() const { return ready_; }

    // === codec callbacks (public so static thunks can reach them) ===
    void OnInputBufferAvailable(uint32_t index, OH_AVBuffer* buffer);
    void OnOutputBufferAvailable(uint32_t index, OH_AVBuffer* buffer);
    void OnError(int32_t error_code);
    void OnStreamChanged(OH_AVFormat* format);

private:
    OH_AVCodec* codec_ = nullptr;
    bool ready_ = false;
    int sample_rate_ = 44100;
    int channels_ = 2;

    PcmCallback on_pcm_;

    std::mutex mtx_;

    // Input queue: indices the codec has handed us; we fill them with ADTS bytes when caller feeds.
    std::queue<std::pair<uint32_t, OH_AVBuffer*>> free_input_buffers_;

    // Output buffers waiting to be released back to codec
    int64_t pts_us_ = 0;
};

} // namespace xfm

#endif // XFM_AAC_DECODER_H
