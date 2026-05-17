#ifndef XFM_FFT_H
#define XFM_FFT_H

#include <cstddef>
#include <vector>

namespace xfm {

/**
 * Power-of-two radix-2 Cooley-Tukey FFT.
 * Operates in-place on parallel real/imag arrays.
 *
 * Allocation-free hot path: tables are precomputed in the constructor.
 */
class Fft {
public:
    explicit Fft(size_t size);

    size_t size() const { return size_; }

    /**
     * Forward FFT in place.
     * re/im must each be at least size() floats long.
     */
    void forward(float* re, float* im) const;

private:
    size_t size_;
    size_t log_size_;
    std::vector<float> cos_table_;
    std::vector<float> sin_table_;
    std::vector<unsigned int> bit_reverse_;
};

} // namespace xfm

#endif // XFM_FFT_H
