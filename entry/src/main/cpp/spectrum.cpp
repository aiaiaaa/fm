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

    // 3) Bin into 16 bands, RMS per bin, dB-mapped
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
        const float db = rms > 0.0f ? 20.0f * std::log10(rms) : -100.0f;
        // Map -50dB..0dB -> 0..1
        float v = (db + 50.0f) / 50.0f;
        if (v < 0.0f) v = 0.0f;
        if (v > 1.0f) v = 1.0f;
        bands[b] = v;
    }

    // 4) Asymmetric smoothing (snap up, decay down)
    for (size_t i = 0; i < kBandCount; ++i) {
        const float prev = prev_bands_[i];
        const float target = bands[i];
        bands[i] = target > prev
            ? prev + (target - prev) * 0.6f
            : prev + (target - prev) * 0.25f;
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
