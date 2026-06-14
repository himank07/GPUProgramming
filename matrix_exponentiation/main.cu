#include <iostream>
#include <chrono>
#include <cmath>
#include <cstdlib>
#include <cuda_runtime.h>
#include <fstream>
#include <iomanip>
#include <vector>

#define TILE_DIM 32
#define CUDA_CHECK(call) { \
    cudaError_t err = call; \
    if (err != cudaSuccess) { \
        fprintf(stderr, "CUDA error in %s:%d - %s\n", __FILE__, __LINE__, cudaGetErrorString(err)); \
        exit(EXIT_FAILURE); \
    } \
}

// ============================================================================
// ENHANCED VERSION: Professional GPU Programming Assignment
// Matrix Exponentiation A^100 with Advanced Features
// ============================================================================

// Performance tracking structure
struct PerformanceMetrics {
    float cpu_time_ms;
    float gpu_naive_time_ms;
    float gpu_tiled_time_ms;
    float h2d_time_ms;
    float d2h_time_ms;
    float max_diff_naive;
    float max_diff_tiled;
};

// CPU Matrix Multiplication (Sequential)
void cpuMatrixMul(const float* A, const float* B, float* C, int N) {
    for (int i = 0; i < N; ++i) {
        for (int j = 0; j < N; ++j) {
            double sum = 0.0;
            for (int k = 0; k < N; ++k) {
                sum += (double)A[i * N + k] * (double)B[k * N + j];
            }
            C[i * N + j] = (float)sum;
        }
    }
}

// CPU Matrix Exponentiation (Binary Exponentiation)
void cpuMatrixExp(const float* A, float* C, int N, int power) {
    float* temp_base = (float*)malloc(N * N * sizeof(float));
    float* temp_acc = (float*)malloc(N * N * sizeof(float));
    float* temp_mul = (float*)malloc(N * N * sizeof(float));

    memcpy(temp_base, A, N * N * sizeof(float));
    memset(temp_acc, 0, N * N * sizeof(float));
    for (int i = 0; i < N; ++i) {
        temp_acc[i * N + i] = 1.0f;
    }

    int p = power;
    while (p > 0) {
        if (p & 1) {
            cpuMatrixMul(temp_acc, temp_base, temp_mul, N);
            memcpy(temp_acc, temp_mul, N * N * sizeof(float));
        }
        if (p > 1) {
            cpuMatrixMul(temp_base, temp_base, temp_mul, N);
            memcpy(temp_base, temp_mul, N * N * sizeof(float));
        }
        p >>= 1;
    }

    memcpy(C, temp_acc, N * N * sizeof(float));

    free(temp_base);
    free(temp_acc);
    free(temp_mul);
}

// Naive GPU Matrix Multiplication Kernel
__global__ void gpuNaiveMatrixMul(const float* A, const float* B, float* C, int N) {
    int row = blockIdx.y * blockDim.y + threadIdx.y;
    int col = blockIdx.x * blockDim.x + threadIdx.x;

    if (row < N && col < N) {
        float sum = 0.0f;
        for (int k = 0; k < N; ++k) {
            sum += A[row * N + k] * B[k * N + col];
        }
        C[row * N + col] = sum;
    }
}

// Tiled GPU Matrix Multiplication Kernel using Shared Memory
__global__ void gpuTiledMatrixMul(const float* A, const float* B, float* C, int N) {
    __shared__ float sh_A[TILE_DIM][TILE_DIM];
    __shared__ float sh_B[TILE_DIM][TILE_DIM];

    int bx = blockIdx.x; int by = blockIdx.y;
    int tx = threadIdx.x; int ty = threadIdx.y;

    int row = by * TILE_DIM + ty;
    int col = bx * TILE_DIM + tx;

    float sum = 0.0f;

    for (int m = 0; m < (N + TILE_DIM - 1) / TILE_DIM; ++m) {
        if (row < N && (m * TILE_DIM + tx) < N) {
            sh_A[ty][tx] = A[row * N + m * TILE_DIM + tx];
        } else {
            sh_A[ty][tx] = 0.0f;
        }

        if (col < N && (m * TILE_DIM + ty) < N) {
            sh_B[ty][tx] = B[(m * TILE_DIM + ty) * N + col];
        } else {
            sh_B[ty][tx] = 0.0f;
        }

        __syncthreads();

        for (int k = 0; k < TILE_DIM; ++k) {
            sum += sh_A[ty][k] * sh_B[k][tx];
        }

        __syncthreads();
    }

    if (row < N && col < N) {
        C[row * N + col] = sum;
    }
}

// Helper to launch matrix multiplication kernel
void launchMatrixMul(const float* d_A, const float* d_B, float* d_C, int N, bool use_tiled,
                     cudaStream_t stream = 0) {
    dim3 threadsPerBlock(TILE_DIM, TILE_DIM);
    dim3 numBlocks((N + TILE_DIM - 1) / TILE_DIM, (N + TILE_DIM - 1) / TILE_DIM);

    if (use_tiled) {
        gpuTiledMatrixMul<<<numBlocks, threadsPerBlock, 0, stream>>>(d_A, d_B, d_C, N);
    } else {
        gpuNaiveMatrixMul<<<numBlocks, threadsPerBlock, 0, stream>>>(d_A, d_B, d_C, N);
    }
    CUDA_CHECK(cudaGetLastError());
}

// GPU Binary Exponentiation
void gpuMatrixExp(const float* d_A, float* d_C, int N, int power, bool use_tiled) {
    float *d_temp_base, *d_temp_acc, *d_temp_mul;
    CUDA_CHECK(cudaMalloc(&d_temp_base, N * N * sizeof(float)));
    CUDA_CHECK(cudaMalloc(&d_temp_acc, N * N * sizeof(float)));
    CUDA_CHECK(cudaMalloc(&d_temp_mul, N * N * sizeof(float)));

    CUDA_CHECK(cudaMemcpy(d_temp_base, d_A, N * N * sizeof(float), cudaMemcpyDeviceToDevice));

    float* h_I = (float*)malloc(N * N * sizeof(float));
    memset(h_I, 0, N * N * sizeof(float));
    for (int i = 0; i < N; ++i) {
        h_I[i * N + i] = 1.0f;
    }
    CUDA_CHECK(cudaMemcpy(d_temp_acc, h_I, N * N * sizeof(float), cudaMemcpyHostToDevice));
    free(h_I);

    int p = power;
    while (p > 0) {
        if (p & 1) {
            launchMatrixMul(d_temp_acc, d_temp_base, d_temp_mul, N, use_tiled);
            CUDA_CHECK(cudaMemcpy(d_temp_acc, d_temp_mul, N * N * sizeof(float), cudaMemcpyDeviceToDevice));
        }
        if (p > 1) {
            launchMatrixMul(d_temp_base, d_temp_base, d_temp_mul, N, use_tiled);
            CUDA_CHECK(cudaMemcpy(d_temp_base, d_temp_mul, N * N * sizeof(float), cudaMemcpyDeviceToDevice));
        }
        p >>= 1;
    }

    CUDA_CHECK(cudaMemcpy(d_C, d_temp_acc, N * N * sizeof(float), cudaMemcpyDeviceToDevice));

    CUDA_CHECK(cudaFree(d_temp_base));
    CUDA_CHECK(cudaFree(d_temp_acc));
    CUDA_CHECK(cudaFree(d_temp_mul));
}

// Enhanced Validation function with statistics
bool validateResults(const float* cpu_res, const float* gpu_res, int N, float tolerance = 1e-3f) {
    float max_diff = 0.0f;
    float avg_diff = 0.0f;
    int errors = 0;

    for (int i = 0; i < N * N; ++i) {
        float diff = std::abs(cpu_res[i] - gpu_res[i]);
        avg_diff += diff;
        if (diff > max_diff) {
            max_diff = diff;
        }
        if (diff > tolerance) {
            errors++;
        }
    }

    avg_diff /= (N * N);

    std::cout << "  Max Diff: " << std::scientific << std::setprecision(6) << max_diff
              << " | Avg Diff: " << avg_diff << " | Errors: " << errors << " (Tolerance: "
              << tolerance << ")\n";

    return max_diff < tolerance;
}

// Print system information
void printSystemInfo() {
    int device;
    CUDA_CHECK(cudaGetDevice(&device));

    cudaDeviceProp prop;
    CUDA_CHECK(cudaGetDeviceProperties(&prop, device));

    std::cout << "\n╔════════════════════════════════════════════════════════════╗\n";
    std::cout << "║              SYSTEM INFORMATION                            ║\n";
    std::cout << "╠════════════════════════════════════════════════════════════╣\n";
    std::cout << "║ GPU: " << std::left << std::setw(51) << prop.name << "║\n";
    std::cout << "║ Compute Capability: " << std::setw(40) << std::to_string(prop.major) + "." + std::to_string(prop.minor) << "║\n";
    std::cout << "║ Max Threads per Block: " << std::setw(37) << prop.maxThreadsPerBlock << "║\n";
    std::cout << "║ Shared Memory per Block: " << std::setw(34) << (prop.sharedMemPerBlock / 1024) << " KB║\n";
    std::cout << "║ Number of SMs: " << std::setw(46) << prop.multiProcessorCount << "║\n";
    std::cout << "║ Memory Clock Rate: " << std::setw(42) << (prop.memoryClockRate / 1000) << " MHz║\n";
    std::cout << "║ Peak Bandwidth: " << std::setw(45) << (2.0 * prop.memoryClockRate * prop.memoryBusWidth / 8.0 / 1e6) << " GB/s║\n";
    std::cout << "╚════════════════════════════════════════════════════════════╝\n\n";
}

// Print performance summary
void printPerformanceSummary(const PerformanceMetrics& metrics, int N, int power) {
    double gflops_cpu = (2.0 * N * N * N * 8) / (metrics.cpu_time_ms * 1e6);  // 8 multiplications
    double gflops_gpu_naive = (2.0 * N * N * N * 8) / (metrics.gpu_naive_time_ms * 1e6);
    double gflops_gpu_tiled = (2.0 * N * N * N * 8) / (metrics.gpu_tiled_time_ms * 1e6);

    std::cout << "\n╔════════════════════════════════════════════════════════════╗\n";
    std::cout << "║            PERFORMANCE SUMMARY                             ║\n";
    std::cout << "╠════════════════════════════════════════════════════════════╣\n";
    std::cout << "║ Problem: A^" << power << " for " << N << "x" << N << " Matrix" << std::string(30, ' ') << "║\n";
    std::cout << "║ Total Multiplications: 8 (from 99 using binary exponentiation)" << std::string(6, ' ') << "║\n";
    std::cout << "╠════════════════════════════════════════════════════════════╣\n";
    std::cout << "║ Method            │ Time (ms)   │ GFLOPs    │ Speedup    ║\n";
    std::cout << "╠════════════════════════════════════════════════════════════╣\n";
    std::cout << "║ CPU Sequential    │ " << std::setw(10) << std::fixed << std::setprecision(2) << metrics.cpu_time_ms
              << " │ " << std::setw(9) << std::fixed << std::setprecision(2) << gflops_cpu << " │ 1.0x       ║\n";
    std::cout << "║ GPU Naive         │ " << std::setw(10) << std::fixed << std::setprecision(2) << metrics.gpu_naive_time_ms
              << " │ " << std::setw(9) << std::fixed << std::setprecision(2) << gflops_gpu_naive
              << " │ " << std::setw(7) << std::fixed << std::setprecision(1) << (metrics.cpu_time_ms / metrics.gpu_naive_time_ms) << "x      ║\n";
    std::cout << "║ GPU Tiled (32x32) │ " << std::setw(10) << std::fixed << std::setprecision(2) << metrics.gpu_tiled_time_ms
              << " │ " << std::setw(9) << std::fixed << std::setprecision(2) << gflops_gpu_tiled
              << " │ " << std::setw(7) << std::fixed << std::setprecision(1) << (metrics.cpu_time_ms / metrics.gpu_tiled_time_ms) << "x      ║\n";
    std::cout << "╚════════════════════════════════════════════════════════════╝\n\n";
}

int main(int argc, char* argv[]) {
    int N = 512;
    int power = 100;

    if (argc > 1) N = atoi(argv[1]);
    if (argc > 2) power = atoi(argv[2]);

    // Print system info
    printSystemInfo();

    std::cout << "╔════════════════════════════════════════════════════════════╗\n";
    std::cout << "║  GPU-ACCELERATED MATRIX EXPONENTIATION (A^" << power << ")                 ║\n";
    std::cout << "║  Matrix Size: " << N << "x" << N << std::string(47 - std::to_string(N).length(), ' ') << "║\n";
    std::cout << "╚════════════════════════════════════════════════════════════╝\n\n";

    size_t bytes = N * N * sizeof(float);
    PerformanceMetrics metrics = {0};

    // Host memory allocation
    float* h_A = (float*)malloc(bytes);
    float* h_C_cpu = (float*)malloc(bytes);
    float* h_C_gpu_naive = (float*)malloc(bytes);
    float* h_C_gpu_tiled = (float*)malloc(bytes);

    // Initialize Matrix A with row-normalized random values
    srand(42);
    for (int i = 0; i < N; ++i) {
        float row_sum = 0.0f;
        for (int j = 0; j < N; ++j) {
            h_A[i * N + j] = ((float)rand() / RAND_MAX);
            row_sum += h_A[i * N + j];
        }
        for (int j = 0; j < N; ++j) {
            h_A[i * N + j] /= row_sum;
        }
    }

    // Device memory allocation
    float *d_A, *d_C;
    CUDA_CHECK(cudaMalloc(&d_A, bytes));
    CUDA_CHECK(cudaMalloc(&d_C, bytes));

    // H2D transfer timing
    cudaEvent_t h2d_start, h2d_stop;
    CUDA_CHECK(cudaEventCreate(&h2d_start));
    CUDA_CHECK(cudaEventCreate(&h2d_stop));

    CUDA_CHECK(cudaEventRecord(h2d_start));
    CUDA_CHECK(cudaMemcpy(d_A, h_A, bytes, cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaEventRecord(h2d_stop));
    CUDA_CHECK(cudaEventSynchronize(h2d_stop));
    CUDA_CHECK(cudaEventElapsedTime(&metrics.h2d_time_ms, h2d_start, h2d_stop));

    // CPU Execution
    if (N <= 512) {
        std::cout << "Running CPU Sequential Computation...\n";
        auto start = std::chrono::high_resolution_clock::now();
        cpuMatrixExp(h_A, h_C_cpu, N, power);
        auto end = std::chrono::high_resolution_clock::now();
        metrics.cpu_time_ms = std::chrono::duration<double, std::milli>(end - start).count();
        std::cout << "✓ CPU Time: " << std::fixed << std::setprecision(2) << metrics.cpu_time_ms << " ms\n\n";
    } else {
        std::cout << "⊘ Skipping CPU (N=" << N << " too large for reasonable CPU timing)\n\n";
        metrics.cpu_time_ms = -1;
    }

    // GPU Naive Execution
    std::cout << "Running GPU Naive (No Optimization)...\n";
    cudaEvent_t start_naive, stop_naive;
    CUDA_CHECK(cudaEventCreate(&start_naive));
    CUDA_CHECK(cudaEventCreate(&stop_naive));

    CUDA_CHECK(cudaEventRecord(start_naive));
    gpuMatrixExp(d_A, d_C, N, power, false);
    CUDA_CHECK(cudaEventRecord(stop_naive));
    CUDA_CHECK(cudaEventSynchronize(stop_naive));

    CUDA_CHECK(cudaEventElapsedTime(&metrics.gpu_naive_time_ms, start_naive, stop_naive));
    CUDA_CHECK(cudaMemcpy(h_C_gpu_naive, d_C, bytes, cudaMemcpyDeviceToHost));
    std::cout << "✓ GPU Naive Time: " << std::fixed << std::setprecision(2) << metrics.gpu_naive_time_ms << " ms\n\n";

    // GPU Tiled Execution
    std::cout << "Running GPU Tiled (32x32 Shared Memory Optimization)...\n";
    cudaEvent_t start_tiled, stop_tiled;
    CUDA_CHECK(cudaEventCreate(&start_tiled));
    CUDA_CHECK(cudaEventCreate(&stop_tiled));

    CUDA_CHECK(cudaEventRecord(start_tiled));
    gpuMatrixExp(d_A, d_C, N, power, true);
    CUDA_CHECK(cudaEventRecord(stop_tiled));
    CUDA_CHECK(cudaEventSynchronize(stop_tiled));

    CUDA_CHECK(cudaEventElapsedTime(&metrics.gpu_tiled_time_ms, start_tiled, stop_tiled));

    // D2H transfer timing
    cudaEvent_t d2h_start, d2h_stop;
    CUDA_CHECK(cudaEventCreate(&d2h_start));
    CUDA_CHECK(cudaEventCreate(&d2h_stop));

    CUDA_CHECK(cudaEventRecord(d2h_start));
    CUDA_CHECK(cudaMemcpy(h_C_gpu_tiled, d_C, bytes, cudaMemcpyDeviceToHost));
    CUDA_CHECK(cudaEventRecord(d2h_stop));
    CUDA_CHECK(cudaEventSynchronize(d2h_stop));
    CUDA_CHECK(cudaEventElapsedTime(&metrics.d2h_time_ms, d2h_start, d2h_stop));

    std::cout << "✓ GPU Tiled Time: " << std::fixed << std::setprecision(2) << metrics.gpu_tiled_time_ms << " ms\n\n";

    // Validation
    std::cout << "╔════════════════════════════════════════════════════════════╗\n";
    std::cout << "║                   VALIDATION RESULTS                       ║\n";
    std::cout << "╠════════════════════════════════════════════════════════════╣\n";

    if (N <= 512) {
        std::cout << "║ GPU Naive vs CPU:  ";
        bool valid_naive = validateResults(h_C_cpu, h_C_gpu_naive, N);
        std::cout << (valid_naive ? "✓ PASS" : "✗ FAIL") << std::string(43, ' ') << "║\n";

        std::cout << "║ GPU Tiled vs CPU:  ";
        bool valid_tiled = validateResults(h_C_cpu, h_C_gpu_tiled, N);
        std::cout << (valid_tiled ? "✓ PASS" : "✗ FAIL") << std::string(43, ' ') << "║\n";
    }

    std::cout << "║ GPU Tiled vs Naive: ";
    bool valid_opt = validateResults(h_C_gpu_naive, h_C_gpu_tiled, N);
    std::cout << (valid_opt ? "✓ PASS" : "✗ FAIL") << std::string(41, ' ') << "║\n";
    std::cout << "╚════════════════════════════════════════════════════════════╝\n";

    // Print performance summary
    printPerformanceSummary(metrics, N, power);

    // Print speedup comparison
    std::cout << "╔════════════════════════════════════════════════════════════╗\n";
    std::cout << "║              SPEEDUP ANALYSIS                              ║\n";
    std::cout << "╠════════════════════════════════════════════════════════════╣\n";
    std::cout << "║ Tiling Benefit (Naive→Tiled): " << std::setw(25)
              << std::fixed << std::setprecision(1) << (metrics.gpu_naive_time_ms / metrics.gpu_tiled_time_ms)
              << "x faster       ║\n";
    if (metrics.cpu_time_ms > 0) {
        std::cout << "║ GPU Tiled vs CPU:            " << std::setw(25)
                  << std::fixed << std::setprecision(1) << (metrics.cpu_time_ms / metrics.gpu_tiled_time_ms)
                  << "x faster       ║\n";
    }
    std::cout << "║ Memory Transfer Time:                                    ║\n";
    std::cout << "║   Host → Device: " << std::setw(9) << std::fixed << std::setprecision(3) << metrics.h2d_time_ms
              << " ms                      ║\n";
    std::cout << "║   Device → Host: " << std::setw(9) << std::fixed << std::setprecision(3) << metrics.d2h_time_ms
              << " ms                      ║\n";
    std::cout << "╚════════════════════════════════════════════════════════════╝\n\n";

    // Cleanup
    CUDA_CHECK(cudaFree(d_A));
    CUDA_CHECK(cudaFree(d_C));
    free(h_A);
    free(h_C_cpu);
    free(h_C_gpu_naive);
    free(h_C_gpu_tiled);

    CUDA_CHECK(cudaEventDestroy(h2d_start));
    CUDA_CHECK(cudaEventDestroy(h2d_stop));
    CUDA_CHECK(cudaEventDestroy(d2h_start));
    CUDA_CHECK(cudaEventDestroy(d2h_stop));
    CUDA_CHECK(cudaEventDestroy(start_naive));
    CUDA_CHECK(cudaEventDestroy(stop_naive));
    CUDA_CHECK(cudaEventDestroy(start_tiled));
    CUDA_CHECK(cudaEventDestroy(stop_tiled));

    std::cout << "✓ Program completed successfully!\n\n";

    return 0;
}
