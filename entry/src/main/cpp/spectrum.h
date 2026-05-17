#ifndef XFM_SPECTRUM_H
#define XFM_SPECTRUM_H

#include <cstddef>
#include <cstdint>
#include <functional>
#include <vector>

#include "fft.h"

namespace xfm {

/**
 * Streaming PCM -> 16 log-spaced frequency bands.
 *
 * Threading: not thread-safe; call FeedPcm and Reset from the same thread.
 *
 * Pipeline per analysis tick:
 *   downmix to mono -> Hann window -> 1024-pt FFT -> RMS per log-spaced bin
 *   -> dB map (-50..0 dB) -> asymmetric smoothing -> callback
 */
class SpectrumAnalyzer {
public:
    using OnBandsCallback = std::function<void(const std::vector<float>& bands)>;

    explicit SpectrumAnalyzer(OnBandsCallback cb);

    void FeedPcm(const int16_t* samples, size_t count, int sample_rate, int channels);
    void Reset();

private:
    void Analyze(const float* samples);
    void RecomputeBands();

    Fft fft_;
    std::vector<float> window_;
    std::vector<float> re_;
    std::vector<float> im_;
    std::vector<float> buffer_;
    std::vector<float> prev_bands_;
    std::vector<size_t> band_low_;
    std::vector<size_t> band_high_;

    OnBandsCallback on_bands_;
    int sample_rate_at_calc_;
    int sample_rate_;
};

} // namespace xfm

#endif // XFM_SPECTRUM_H
