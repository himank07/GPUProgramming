# Makefile for GPU Programming Assignment - Matrix Exponentiation
# Author: GPU Programming Course
# Optimization: Binary Exponentiation + Shared Memory Tiling

NVCC = nvcc
CFLAGS = -O3 -arch=sm_86 -std=c++11 --ptxas-options=-v
DEBUG_FLAGS = -g -G -lineinfo

# Targets
TARGET = matrix_exp
SOURCE = matrix_exponentiation/main.cu
PYTHON_SOURCE = matrix_exponentiation/main.py

.PHONY: all clean run run-small run-medium run-large help profile

all: $(TARGET)

# Default compilation
$(TARGET): $(SOURCE)
	@echo "════════════════════════════════════════════════════════"
	@echo "  Compiling GPU Matrix Exponentiation (A^100)"
	@echo "════════════════════════════════════════════════════════"
	$(NVCC) $(CFLAGS) $(SOURCE) -o $@
	@echo "✓ Successfully compiled: $(TARGET)"
	@echo ""

# Debug build with debugging symbols
debug: $(SOURCE)
	@echo "Compiling with debug symbols..."
	$(NVCC) $(DEBUG_FLAGS) $(CFLAGS) $(SOURCE) -o $(TARGET)_debug
	@echo "✓ Debug build created: $(TARGET)_debug"

# Run with default parameters (512x512, power 100)
run: $(TARGET)
	@echo ""
	@echo "════════════════════════════════════════════════════════"
	@echo "  Running: Default (512x512 matrix, A^100)"
	@echo "════════════════════════════════════════════════════════"
	@echo ""
	./$(TARGET)

# Run performance tests with multiple sizes
run-all: $(TARGET)
	@echo ""
	@echo "════════════════════════════════════════════════════════"
	@echo "  Running Performance Tests: Multiple Matrix Sizes"
	@echo "════════════════════════════════════════════════════════"
	@echo ""
	@echo "--- Test 1: 256x256 Matrix ---"
	./$(TARGET) 256 100
	@echo ""
	@echo "--- Test 2: 512x512 Matrix ---"
	./$(TARGET) 512 100
	@echo ""
	@echo "--- Test 3: 1024x1024 Matrix ---"
	./$(TARGET) 1024 100
	@echo ""

# Run small matrix (quick test)
run-small: $(TARGET)
	@echo "Running: 256x256 matrix"
	./$(TARGET) 256 100

# Run medium matrix
run-medium: $(TARGET)
	@echo "Running: 512x512 matrix (default)"
	./$(TARGET) 512 100

# Run large matrix
run-large: $(TARGET)
	@echo "Running: 1024x1024 matrix (takes longer)"
	./$(TARGET) 1024 100

# Profile with NVIDIA Nsight Systems
profile: $(TARGET)
	@echo "Profiling with NVIDIA Nsight Systems..."
	nsys profile --trace cuda,osrt,mpi ./$(TARGET)
	@echo "✓ Profile saved as report.sqlite"
	@echo ""
	@echo "View detailed stats with: nsys stats report.sqlite"

# Performance profiling with detailed metrics
perf-detailed: $(TARGET)
	@echo "Running detailed performance profile..."
	ncu --set full ./$(TARGET) 512 100 > performance_report.txt
	@echo "✓ Detailed metrics saved to performance_report.txt"

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -f $(TARGET) $(TARGET)_debug
	rm -f *.exe *.o *.d
	rm -f report.sqlite
	rm -f performance_report.txt
	@echo "✓ Clean complete"

# Show help
help:
	@echo ""
	@echo "╔════════════════════════════════════════════════════════════╗"
	@echo "║  GPU Matrix Exponentiation (A^100) - Makefile Help        ║"
	@echo "╚════════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "Available targets:"
	@echo "  make all              - Build the program (default)"
	@echo "  make run              - Build and run with default size (512x512)"
	@echo "  make run-all          - Run with multiple matrix sizes (256, 512, 1024)"
	@echo "  make run-small        - Run with 256x256 matrix (quick test)"
	@echo "  make run-medium       - Run with 512x512 matrix"
	@echo "  make run-large        - Run with 1024x1024 matrix"
	@echo "  make debug            - Build with debug symbols"
	@echo "  make profile          - Profile with NVIDIA Nsight Systems"
	@echo "  make perf-detailed    - Generate detailed performance metrics"
	@echo "  make clean            - Remove build artifacts"
	@echo "  make help             - Show this help message"
	@echo ""
	@echo "Usage examples:"
	@echo "  make                  # Compile only"
	@echo "  make run              # Compile and run"
	@echo "  make run-all          # Run performance tests"
	@echo "  ./matrix_exp 256 100  # Run custom size (256x256, power 100)"
	@echo ""
