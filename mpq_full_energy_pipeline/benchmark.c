#include <stdint.h>

#define MARK_PACK_START  (*(volatile uint32_t *)0x0001FF00u)
#define MARK_PACK_END    (*(volatile uint32_t *)0x0001FF04u)
#define MARK_GEMM_START  (*(volatile uint32_t *)0x0001FF08u)
#define MARK_GEMM_END    (*(volatile uint32_t *)0x0001FF0Cu)
#define RESULT_DOT2      (*(volatile uint32_t *)0x0001FF10u)
#define RESULT_DOT4      (*(volatile uint32_t *)0x0001FF14u)
#define RESULT_DOT8      (*(volatile uint32_t *)0x0001FF18u)
#define RESULT_CHECKSUM  (*(volatile uint32_t *)0x0001FF1Cu)
#define MARK_DONE        (*(volatile uint32_t *)0x0001FF20u)

static inline int32_t dot2_hw(uint32_t a, uint32_t b)
{
    int32_t rd;
    __asm__ volatile (
        ".insn r 0x0b, 0, 0, %0, %1, %2"
        : "=r"(rd) : "r"(a), "r"(b)
    );
    return rd;
}

static inline int32_t dot4_hw(uint32_t a, uint32_t b)
{
    int32_t rd;
    __asm__ volatile (
        ".insn r 0x0b, 1, 0, %0, %1, %2"
        : "=r"(rd) : "r"(a), "r"(b)
    );
    return rd;
}

static inline int32_t dot8_hw(uint32_t a, uint32_t b)
{
    int32_t rd;
    __asm__ volatile (
        ".insn r 0x0b, 2, 0, %0, %1, %2"
        : "=r"(rd) : "r"(a), "r"(b)
    );
    return rd;
}

__attribute__((noinline))
static uint32_t pack_int8_4(const int8_t *x)
{
    uint32_t p = 0;
    p |= ((uint32_t)(uint8_t)x[0]) << 0;
    p |= ((uint32_t)(uint8_t)x[1]) << 8;
    p |= ((uint32_t)(uint8_t)x[2]) << 16;
    p |= ((uint32_t)(uint8_t)x[3]) << 24;
    return p;
}

static int8_t clamp_i4(int8_t x)
{
    if (x > 7)  return 7;
    if (x < -8) return -8;
    return x;
}

__attribute__((noinline))
static uint32_t pack_int4_8(const int8_t *x)
{
    uint32_t p = 0;
    for (int i = 0; i < 8; ++i) {
        uint32_t nib = (uint32_t)((uint8_t)clamp_i4(x[i]) & 0x0Fu);
        p |= nib << (4 * i);
    }
    return p;
}

static int8_t clamp_i2(int8_t x)
{
    if (x > 1)  return 1;
    if (x < -2) return -2;
    return x;
}

__attribute__((noinline))
static uint32_t pack_int2_16(const int8_t *x)
{
    uint32_t p = 0;
    for (int i = 0; i < 16; ++i) {
        uint32_t two = (uint32_t)((uint8_t)clamp_i2(x[i]) & 0x03u);
        p |= two << (2 * i);
    }
    return p;
}

// Pressure-heavy GEMM microkernel. No artificial spill/fill instructions.
__attribute__((noinline))
static int32_t gemm_pressure_kernel(const int8_t *A, const int8_t *B, int K)
{
    int32_t c00=0,c01=0,c02=0,c03=0;
    int32_t c10=0,c11=0,c12=0,c13=0;
    int32_t c20=0,c21=0,c22=0,c23=0;
    int32_t c30=0,c31=0,c32=0,c33=0;

    for (int k=0; k<K; ++k) {
        int32_t a0=A[0*K+k], a1=A[1*K+k], a2=A[2*K+k], a3=A[3*K+k];
        int32_t b0=B[k*4+0], b1=B[k*4+1], b2=B[k*4+2], b3=B[k*4+3];

        c00+=a0*b0; c01+=a0*b1; c02+=a0*b2; c03+=a0*b3;
        c10+=a1*b0; c11+=a1*b1; c12+=a1*b2; c13+=a1*b3;
        c20+=a2*b0; c21+=a2*b1; c22+=a2*b2; c23+=a2*b3;
        c30+=a3*b0; c31+=a3*b1; c32+=a3*b2; c33+=a3*b3;
    }

    return c00+c01+c02+c03+c10+c11+c12+c13+
           c20+c21+c22+c23+c30+c31+c32+c33;
}

static const int8_t a_vals[16] = {
     1,-1, 1,-1,  1,-1, 1,-1,
     1,-1, 1,-1,  1,-1, 1,-1
};

static const int8_t b_vals[16] = {
     1, 1,-1,-1,  1, 1,-1,-1,
     1, 1,-1,-1,  1, 1,-1,-1
};

static const int8_t gemm_A[32] = {
    1,2,3,4,5,6,7,8,
    2,1,0,-1,-2,-3,-4,-5,
    1,1,1,1,1,1,1,1,
    -1,2,-3,4,-5,6,-7,7
};

static const int8_t gemm_B[32] = {
    1,0,-1,2,
    2,1,0,-1,
    1,2,1,0,
    0,1,2,1,
    -1,0,1,2,
    2,-1,0,1,
    1,2,-1,0,
    0,1,2,-1
};

int main(void)
{
    uint32_t a2, b2, a4, b4, a8, b8;

    // Runtime packing region. Testbench observes executed instructions here.
    MARK_PACK_START = 1;

    a2 = pack_int2_16(a_vals);
    b2 = pack_int2_16(b_vals);

    a4 = pack_int4_8(a_vals);
    b4 = pack_int4_8(b_vals);

    a8 = pack_int8_4(a_vals);
    b8 = pack_int8_4(b_vals);

    MARK_PACK_END = 1;

    // Real custom accelerator operations.
    int32_t r2 = dot2_hw(a2, b2);
    int32_t r4 = dot4_hw(a4, b4);
    int32_t r8 = dot8_hw(a8, b8);

    RESULT_DOT2 = (uint32_t)r2;
    RESULT_DOT4 = (uint32_t)r4;
    RESULT_DOT8 = (uint32_t)r8;

    // Region used to measure dynamic compiler-created stack traffic.
    MARK_GEMM_START = 1;
    int32_t checksum = gemm_pressure_kernel(gemm_A, gemm_B, 8);
    MARK_GEMM_END = 1;

    RESULT_CHECKSUM = (uint32_t)checksum;
    MARK_DONE = 0xC0DEC0DEu;

    for (;;)
        __asm__ volatile ("nop");
}
