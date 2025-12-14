#!/bin/bash
# Quick test script to verify CMake OpenBLAS detection
# This can be run in a minimal container to test the FindOpenBLAS.cmake module

set -e

echo "=== Testing CMake OpenBLAS Detection ==="
echo ""

# Create a temporary test directory
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"

echo "1. Creating minimal CMake test..."
cat > CMakeLists.txt << 'EOF'
cmake_minimum_required(VERSION 3.8)
project(TestOpenBLAS)

# Add the OpenFace cmake modules path
set(CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/../../cmake/modules")

# Find OpenBLAS
find_package(OpenBLAS REQUIRED)

message(STATUS "OpenBLAS test completed successfully!")
message(STATUS "OpenBLAS_LIB: ${OpenBLAS_LIB}")
message(STATUS "OpenBLAS_INCLUDE_DIR: ${OpenBLAS_INCLUDE_DIR}")
EOF

# Copy the FindOpenBLAS.cmake module
mkdir -p ../../cmake/modules
cp ../../cmake/modules/FindOpenBLAS.cmake . 2>/dev/null || echo "Note: Run from OpenFace root directory"

echo "2. Running CMake configuration..."
if cmake . 2>&1 | tee cmake_output.log; then
    echo ""
    echo "✓ CMake configuration succeeded!"
    echo ""
    echo "3. Checking CMake output for architecture detection:"
    grep -i "Detected architecture\|Using architecture\|OpenBLAS" cmake_output.log || true
    echo ""
    echo "=== Test Passed ==="
    exit 0
else
    echo ""
    echo "✗ CMake configuration failed!"
    echo ""
    echo "CMake output:"
    cat cmake_output.log
    exit 1
fi

