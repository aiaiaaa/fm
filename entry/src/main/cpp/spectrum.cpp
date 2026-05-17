#include "spectrum.h"

#include <algorithm>
#include <cmath>

namespace xfm {

constexpr size_t kFftSize = 1024;
constexpr size_t kBandCount = 16;

SpectrumAnalyzer::SpectrumAnalyzer(OnBandsCallback cb)
    : fft_(kFftSize),
      window_(kFftSize),
      re_(kFftSize, 0.0f),
      im_(kFftSize, 0.0f),
      buffer_(),
      prev_bands_(kBandCount, 0.0f),
      band_low_(kBandCount, 0),
      band_high_(kBandCount, 0),
      on_bands_(std::move(cb)),
      sample_rate_at_calc_(-1),
      sample_rate_(44100) {
    for (size_t i = 0; i < kFftSize; ++i) {
        window_[i] = 0.5f - 0.5f * std::cos(2.0f * static_cast<float>(M_PI) * i / (kFftSize - 1));
    }
    buffer_.reserve(kFftSize * 4);
}

void SpectrumAnalyzer::FeedPcm(const int16_t* samples, size_t count, int sample_rate, int channels) {
    if (samples == nullptr || count == 0 || channels < 1) return;

    if (sample_rate != sample_rate_) {
        sample_rate_ = sample_rate;
        RecomputeBands();
    } else if (sample_rate_at_calc_ != sample_rate_) {
        RecomputeBands();
    }

    // Downmix to mono float, append to buffer
    const size_t frames = count / static_cast<size_t>(channels);
    const size_t prev_size = buffer_.size();
    buffer_.resize(prev_size + frames);
    if (channels == 1) {
        for (size_t i = 0; i < frames; ++i) {
            buffer_[prev_size + i] = static_cast<float>(samples[i]) / 32768.0f;
        }
    } else {
        for (size_t i = 0; i < frames; ++i) {
            int sum = 0;
            for (int c = 0; c < channels; ++c) {
                sum += samples[i * channels + c];
            }
            buffer_[prev_size + i] = static_cast<float>(sum) / (32768.0f * channels);
        }
    }

    while (buffer_.size() >= kFftSize) {
        Analyze(buffer_.data());
        // Slide buffer left by kFftSize (no overlap; ~43 fps @ 44.1kHz which is plenty)
        buffer_.erase(buffer_.begin(), buffer_.begin() + kFftSize);
    }
    // Cap buffer to avoid unbounded growth on backpressure
    if (buffer_.size() > kFftSize * 4) {
        buffer_.erase(buffer_.begin(), buffer_.begin() + (buffer_.size() - kFftSize * 4));
    }
}

void SpectrumAnalyzer::Reset() {
    buffer_.clear();
    std::fill(prev_bands_.begin(), prev_bands_.end(), 0.0f);
}

void SpectrumAnalyzer::Analyze(const float* samples) {
    // 1) Apply Hann window
    for (size_t i = 0; i < kFftSize; ++i) {
        re_[i] = samples[i] * window_[i];
        im_[i] = 0.0f;
    }
    // 2) FFT in place
    fft_.forward(re_.data(), im_.data());

    // 3) Bin into 16 bands, RMS per bin, dB-mapped.
    //
    // Two adjustments vs. a "naive" linear FFT->bar mapping:
    //
    //  a) Wider dynamic range: -65dB .. -5dB instead of -50..0. Real audio
    //     rarely fills the whole scale; mapping all the way to 0dB leaves
    //     bars perpetually at half-mast. A -65dB floor and -5dB ceiling
    //     gives us ~60dB of room while saturating much sooner.
    //
    //  b) Per-band gain compensation. Acoustic energy is far stronger in
    //     the lows (vocals, drums) than the highs (cymbals, sibilance), so
    //     a flat dB scale leaves the right side of the spectrum dead. We
    //     apply a +9dB tilt across the 16 bands (linear in band index) to
    //     match what the ear perceives as "balanced", similar to what
    //     audio analyzer plugins call "perceptual weighting".
    std::vector<float> bands(kBandCount, 0.0f);
    const size_t half = kFftSize >> 1;
    for (size_t b = 0; b < kBandCount; ++b) {
        size_t lo = std::max<size_t>(1, band_low_[b]);
        size_t hi = std::min<size_t>(half, band_high_[b]);
        if (hi <= lo) hi = lo + 1;
        float sum_sq = 0.0f;
        size_t count = 0;
        for (size_t k = lo; k < hi; ++k) {
            const float mag2 = re_[k] * re_[k] + im_[k] * im_[k];
            sum_sq += mag2;
            ++count;
        }
        const float rms = count > 0 ? std::sqrt(sum_sq / count) / kFftSize : 0.0f;
        float db = rms > 0.0f ? 20.0f * std::log10(rms) : -100.0f;
        // Perceptual tilt: 0dB at band 0, +9dB at band 15.
        db += 9.0f * (static_cast<float>(b) / (kBandCount - 1));
        // Map -65dB..-5dB -> 0..1 (60dB dynamic range, saturates more easily)
        float v = (db + 65.0f) / 60.0f;
        if (v < 0.0f) v = 0.0f;
        if (v > 1.0f) v = 1.0f;
        bands[b] = v;
    }

    // 4) Asymmetric smoothing: snap up fast, decay slow. Tuned aggressive
    //    so the bars feel reactive rather than mushy. ArkTS-side smoothing
    //    has been removed — this is the only smoothing layer now.
    for (size_t i = 0; i < kBandCount; ++i) {
        const float prev = prev_bands_[i];
        const float target = bands[i];
        bands[i] = target > prev
            ? prev + (target - prev) * 0.85f   // attack
            : prev + (target - prev) * 0.35f;  // release
    }
    prev_bands_ = bands;

    if (on_bands_) {
        on_bands_(bands);
    }
}

void SpectrumAnalyzer::RecomputeBands() {
    // 16 log-spaced bands from 30Hz to min(sr/2, 10kHz)
    const float f_min = 30.0f;
    const float f_max = std::min(static_cast<float>(sample_rate_) / 2.0f, 10000.0f);
    const float log_min = std::log(f_min);
    const float log_max = std::log(f_max);
    for (size_t b = 0; b < kBandCount; ++b) {
        const float t1 = static_cast<float>(b) / kBandCount;
        const float t2 = static_cast<float>(b + 1) / kBandCount;
        const float f1 = std::exp(log_min + (log_max - log_min) * t1);
        const float f2 = std::exp(log_min + (log_max - log_min) * t2);
        const size_t k1 = static_cast<size_t>(std::floor(f1 * kFftSize / sample_rate_));
        const size_t k2 = static_cast<size_t>(std::ceil(f2 * kFftSize / sample_rate_));
        band_low_[b] = k1;
        band_high_[b] = std::max(k1 + 1, k2);
    }
    sample_rate_at_calc_ = sample_rate_;
}

} // namespace xfm
