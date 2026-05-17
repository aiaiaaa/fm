#include "fft.h"

#include <cmath>
#include <stdexcept>

namespace xfm {

Fft::Fft(size_t size) : size_(size), log_size_(0) {
    if (size < 2 || (size & (size - 1)) != 0) {
        throw std::invalid_argument("Fft size must be a power of 2 >= 2");
    }
    size_t s = size;
    while (s > 1) { s >>= 1; ++log_size_; }

    const size_t half = size_ >> 1;
    cos_table_.resize(half);
    sin_table_.resize(half);
    for (size_t i = 0; i < half; ++i) {
        const double angle = -2.0 * M_PI * static_cast<double>(i) / static_cast<double>(size_);
        cos_table_[i] = static_cast<float>(std::cos(angle));
        sin_table_[i] = static_cast<float>(std::sin(angle));
    }

    bit_reverse_.resize(size_);
    for (size_t i = 0; i < size_; ++i) {
        unsigned int r = 0;
        unsigned int v = static_cast<unsigned int>(i);
        for (size_t j = 0; j < log_size_; ++j) {
            r = (r << 1) | (v & 1u);
            v >>= 1;
        }
        bit_reverse_[i] = r;
    }
}

void Fft::forward(float* re, float* im) const {
    const size_t n = size_;

    // 1) Bit-reverse permutation
    for (size_t i = 0; i < n; ++i) {
        const size_t j = bit_reverse_[i];
        if (j > i) {
            float t = re[i]; re[i] = re[j]; re[j] = t;
            t = im[i]; im[i] = im[j]; im[j] = t;
        }
    }

    // 2) Butterflies
    for (size_t s = 1; s <= log_size_; ++s) {
        const size_t m = 1u << s;
        const size_t halfM = m >> 1;
        const size_t step = n / m;
        for (size_t k = 0; k < n; k += m) {
            for (size_t j = 0; j < halfM; ++j) {
                const size_t tIdx = j * step;
                const float c = cos_table_[tIdx];
                const float si = sin_table_[tIdx];
                const float ar = re[k + j + halfM];
                const float ai = im[k + j + halfM];
                const float tr = ar * c - ai * si;
                const float ti = ar * si + ai * c;
                re[k + j + halfM] = re[k + j] - tr;
                im[k + j + halfM] = im[k + j] - ti;
                re[k + j] = re[k + j] + tr;
                im[k + j] = im[k + j] + ti;
            }
        }
    }
}

} // namespace xfm
