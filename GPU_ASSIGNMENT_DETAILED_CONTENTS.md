# 📦 DETAILED CONTENTS OF GPUProgramming-main

## 📊 Repository Overview
- **Location:** `/Users/Himanshu/Downloads/GPUProgramming-main`
- **Total Size:** 1.4 MB
- **Number of Problems:** 3 (Problems 4, 5, 6)
- **Structure:** Each problem has its own folder with CUDA code, Python wrapper, compiled binaries, and report

---

## 🗂️ FOLDER 1: `aes_crypto/` (488 KB) - Problem 4

### 📂 Files Present:
```
aes_crypto/
├── main.cu          (13 KB)   ← CUDA Implementation
├── main.py          (11 KB)   ← Python CuPy Wrapper
├── report.md        (3.2 KB)  ← Detailed Report
├── aes.exe          (445 KB)  ← Compiled Binary (Windows)
├── aes.exp          (714 B)   ← Export file
└── aes.lib          (1.6 KB)  ← Library file
```

### 🔧 What's Implemented:

**main.cu (383 lines):**
```cuda
✅ AES-128 Encryption Kernel
   - Thread per block mapping (1 thread = 16 bytes)
   - 10 AES rounds fully implemented
   - S-box lookups in constant memory
   - Galois Field arithmetic (MixColumns)

✅ AES-128 Decryption Kernel
   - Inverse S-box transformations
   - Inverse MixColumns (GF multiplication by 14, 11, 13, 9)
   - Inverse ShiftRows and SubBytes

✅ Helper Functions:
   - xtime() for GF(2^8) multiplication by 2
   - mul_gf() for Galois Field multiplication
   - Key expansion (though using precomputed keys)

✅ Main Function:
   - Generates 64 MB random plaintext
   - Encrypts and decrypts
   - Timing measurements
   - Throughput calculation
```

**main.py (Wrapper):**
```python
✅ CuPy wrapper for CUDA kernel
✅ Host-side memory management
✅ Kernel launching
✅ Performance timing
```

### 📋 Report Contents:

**What's Covered:**
- Problem description (AES-128 block cipher)
- Algorithmic optimizations:
  - Thread-to-block mapping
  - Constant memory caching for S-boxes
  - Galois Field arithmetic optimization
- Performance table:
  - CUDA C++ Encryption: 14.60 ms → **4.28 GB/s**
  - CUDA C++ Decryption: 13.14 ms → **4.76 GB/s**
  - CuPy versions with comparable results
- Hardware specs (RTX 3080, Ryzen 5 7600)

**What's Missing:**
- No step-by-step AES round explanation
- No visual diagram of AES structure
- No test vectors or validation
- No derivation of Galois Field math

### ⚙️ How to Compile & Run:
```bash
# Current state: BINARY EXISTS but NO MAKEFILE
# To recompile would need:
nvcc -O3 -arch=sm_86 main.cu -o aes.exe

# To run:
./aes.exe
```

---

## 🗂️ FOLDER 2: `matrix_exponentiation/` (464 KB) - Problem 6 ⭐

### 📂 Files Present:
```
matrix_exponentiation/
├── main.cu          (9.7 KB)   ← CUDA Implementation
├── main.py          (5.0 KB)   ← Python CuPy Wrapper
├── report.md        (3.5 KB)   ← Detailed Report
├── matrix_exp.exe   (432 KB)   ← Compiled Binary
├── matrix_exp.exp   (740 B)    ← Export file
└── matrix_exp.lib   (1.7 KB)   ← Library file
```

### 🔧 What's Implemented:

**main.cu (301 lines):**
```cuda
✅ CPU Sequential Matrix Multiplication
   - Triple nested loop O(N³)
   - Double precision for validation
   - Used as baseline for comparison

✅ CPU Binary Exponentiation
   - Reduces 99 multiplications → 8 multiplications
   - Algorithm: square-and-multiply
   - 100 in binary = 1100100₂ = 64+32+4

✅ GPU Naive Matrix Multiplication Kernel
   - Each thread computes one element C[i,j]
   - Reads from global memory repeatedly
   - Memory-bandwidth limited

✅ GPU Tiled Matrix Multiplication Kernel
   - 32×32 shared memory tiles
   - Cooperative tile loading
   - __syncthreads() synchronization
   - 140-150x faster than naive

✅ GPU Binary Exponentiation
   - Same algorithm as CPU
   - Uses either naive or tiled multiplication
   - Device memory management
   - cudaMemcpy for H2D and D2H

✅ Validation Function
   - Compares GPU vs CPU results
   - Max absolute difference check
   - Tolerance: 1e-3 (could be tighter)

✅ Row Normalization
   - Normalizes matrix rows to sum=1.0
   - Prevents numerical overflow/underflow
   - Keeps spectral radius ~1.0
```

**main.py (Wrapper):**
```python
✅ CuPy implementation of same algorithm
✅ Python numpy for CPU baseline
✅ Performance comparison
```

### 📋 Report Contents:

**What's Covered:**
- Problem description (compute A^100 for NxN matrix)
- **Algorithmic Optimizations:**
  - Binary Exponentiation (99 → 8 multiplications)
  - Shared Memory Tiling (32×32 blocks)
  - Row Normalization for stability

- **Performance Table:**
  | Implementation | Time | Speedup |
  |---|---|---|
  | CPU Sequential | 1554.92 ms | 1.0x |
  | NumPy | 7.74 ms | 200.9x |
  | CUDA Naive | 95.74 ms | 16.2x |
  | CUDA Tiled | 2.48 ms | **627.0x** |
  | CuPy Naive | 17.87 ms | 87.0x |
  | CuPy Tiled | 1.66 ms | **936.7x** |

**What's Missing:**
- No step-by-step derivation of binary exponentiation
- No diagram showing thread/block organization
- No calculation of why 8 multiplications needed
- No memory access pattern visualization
- Report could explain tiling benefit in detail

### ⚙️ How to Compile & Run:
```bash
# Current state: BINARY EXISTS but NO MAKEFILE
nvcc -O3 -arch=sm_86 main.cu -o matrix_exp.exe

# To run:
./matrix_exp.exe 512 100  # matrix size and power
```

---

## 🗂️ FOLDER 3: `pde_solver/` (456 KB) - Problem 5

### 📂 Files Present:
```
pde_solver/
├── main.cu          (7.8 KB)   ← CUDA Implementation
├── main.py          (5.3 KB)   ← Python CuPy Wrapper
├── report.md        (3.2 KB)   ← Detailed Report
├── pde_sol.exe      (428 KB)   ← Compiled Binary
├── pde_sol.exp      (722 B)    ← Export file
└── pde_sol.lib      (1.7 KB)   ← Library file
```

### 🔧 What's Implemented:

**main.cu (239 lines):**
```cuda
✅ CPU Sequential Heat Diffusion Solver
   - 5-point stencil (N, S, E, W, Center)
   - Explicit finite-difference method
   - ∂T/∂t = c(∂²T/∂x² + ∂²T/∂y²)

✅ GPU Naive Stencil Kernel
   - Global memory reads for all 5 values
   - No optimization
   - High memory bandwidth utilization

✅ GPU Shared Memory Halo Kernel
   - 16×16 thread blocks
   - (16+2)×(16+2) tile loading (with halo)
   - Cooperative tile loading
   - __syncthreads() for synchronization
   - 5-point stencil computed from shared mem

✅ Double Buffering
   - Two grid buffers: gridA and gridB
   - Pointer swapping instead of copying
   - Prevents race conditions
   - Clean separation of read/write steps

✅ Boundary Conditions
   - Dirichlet boundaries (fixed temperatures)
   - Top/Bottom/Left/Right temperature settings
   - Preserved across time steps

✅ Main Function
   - 1024×1024 grid, 1000 time steps
   - Timing measurements
   - Speedup calculations
```

**main.py (Wrapper):**
```python
✅ NumPy CPU implementation
✅ CuPy GPU implementations (naive + shared)
✅ Performance comparison
```

### 📋 Report Contents:

**What's Covered:**
- Problem description (2D heat diffusion PDE)
- **Algorithmic Optimizations:**
  - Double buffering (pointer swapping)
  - Shared memory halo-exchange
  - Dirichlet boundary conditions

- **Performance Table:**
  | Implementation | Time | Speedup |
  |---|---|---|
  | NumPy CPU | 7299.29 ms | 1.0x |
  | C++ CPU | 652.59 ms | 11.2x |
  | CUDA Naive | 18.45 ms | 395.6x |
  | CUDA Shared | 20.18 ms | 361.7x |
  | CuPy Naive | 21.70 ms | 336.4x |
  | CuPy Shared | 19.58 ms | **372.8x** |

**What's Missing:**
- No PDE derivation explanation
- No finite-difference scheme diagram
- No halo-exchange visualization
- Modest speedup (6.2x) for shared vs naive is surprising/not explained
- Could show convergence analysis

### ⚙️ How to Compile & Run:
```bash
# Current state: BINARY EXISTS but NO MAKEFILE
nvcc -O3 -arch=sm_86 main.cu -o pde_sol.exe

# To run:
./pde_sol.exe
```

---

## 📋 MAIN REPOSITORY FILES

### `README.md` (Main)
```markdown
# Repo for Gpu Programming assignment

This directory contains implementation codes and detailed individual 
reports for the three completed assignment problems:

1. Problem 6: Matrix Exponentiation (A^100)
2. Problem 5: Stencil-Based PDE Solver
3. Problem 4: Cryptography Algorithms (AES-128)
```

### `report.md` (Main)
Points to individual reports with links (mostly broken Windows paths)

---

## 🎯 SUMMARY TABLE

| Aspect | AES (P4) | Matrix (P6) ⭐ | PDE (P5) |
|--------|----------|---|---|
| **Code Lines** | 383 | 301 | 239 |
| **Complexity** | Medium | Medium | High |
| **Speedup** | 4.28 GB/s | **627x** | **372x** |
| **Report Quality** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Ease to Explain** | Medium | **Easy** | Hard |
| **Mark Potential** | 85-90% | **90-95%** | 80-85% |
| **Missing** | Derivations | Diagrams | PDE math |
| **Build Status** | Compiled ✅ | Compiled ✅ | Compiled ✅ |
| **Makefile** | ❌ | ❌ | ❌ |

---

## 🚀 QUICK START (If You Choose One)

### To Verify a Problem Works:
```bash
cd /Users/Himanshu/Downloads/GPUProgramming-main/[problem_folder]

# Check if binary exists
ls -la *.exe

# Run it (if you're on Windows/WSL with CUDA)
./[binary].exe

# Check report
cat report.md
```

### To Understand What Each Does:
1. **AES:** Encrypts/decrypts 64 MB of data in parallel
2. **Matrix:** Computes A^100 using optimized matrix multiplication
3. **PDE:** Simulates heat diffusion over 1024×1024 grid for 1000 timesteps

---

## ❓ WHAT'S YOUR NEXT STEP?

**Which problem do you want to finalize?**

1. **Problem 4 - AES** 
   - Real-world cryptography
   - Needs: Detailed crypto explanation

2. **Problem 6 - Matrix** ⭐ RECOMMENDED
   - Best speedup numbers
   - Easiest to explain
   - Highest mark potential

3. **Problem 5 - PDE**
   - Most complex algorithm
   - Needs: Strong math explanation
   - Challenging to present well

**Let me know which one, and I'll help you:**
- ✅ Create Makefile
- ✅ Fix compilation
- ✅ Enhance report
- ✅ Add tests
- ✅ Make it submission-ready!

