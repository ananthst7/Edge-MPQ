#include <stdint.h>

// Small GEMM-style inner kernel with 16 simultaneously-live accumulators.
// The compiler decides register allocation naturally. We do NOT insert
// artificial spill/fill loads or stores.
//
// A and B are interpreted as 4xK and Kx4 matrices respectively.
// C is 4x4.
//
// Compile with different -ffixed-<reg> sets to reduce the allocator's
// usable GPR pool. This allows spills to emerge organically.
__attribute__((noinline))
void gemm4x4_i8(const int8_t *A,
                const int8_t *B,
                int32_t *C,
                int K)
{
    int32_t c00 = 0, c01 = 0, c02 = 0, c03 = 0;
    int32_t c10 = 0, c11 = 0, c12 = 0, c13 = 0;
    int32_t c20 = 0, c21 = 0, c22 = 0, c23 = 0;
    int32_t c30 = 0, c31 = 0, c32 = 0, c33 = 0;

    for (int k = 0; k < K; ++k) {
        int32_t a0 = A[0*K + k];
        int32_t a1 = A[1*K + k];
        int32_t a2 = A[2*K + k];
        int32_t a3 = A[3*K + k];

        int32_t b0 = B[k*4 + 0];
        int32_t b1 = B[k*4 + 1];
        int32_t b2 = B[k*4 + 2];
        int32_t b3 = B[k*4 + 3];

        c00 += a0 * b0;  c01 += a0 * b1;
        c02 += a0 * b2;  c03 += a0 * b3;

        c10 += a1 * b0;  c11 += a1 * b1;
        c12 += a1 * b2;  c13 += a1 * b3;

        c20 += a2 * b0;  c21 += a2 * b1;
        c22 += a2 * b2;  c23 += a2 * b3;

        c30 += a3 * b0;  c31 += a3 * b1;
        c32 += a3 * b2;  c33 += a3 * b3;
    }

    C[0]  = c00; C[1]  = c01; C[2]  = c02; C[3]  = c03;
    C[4]  = c10; C[5]  = c11; C[6]  = c12; C[7]  = c13;
    C[8]  = c20; C[9]  = c21; C[10] = c22; C[11] = c23;
    C[12] = c30; C[13] = c31; C[14] = c32; C[15] = c33;
}
