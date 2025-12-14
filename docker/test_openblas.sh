#!/bin/bash
# Test script to verify OpenBLAS detection and architecture support
# This script can be run inside the container after build

set -e

echo "=== OpenBLAS Detection Test ==="
echo ""

# Check architecture
echo "1. System Architecture:"
uname -m
echo ""

# Check if OpenBLAS library is found
echo "2. Checking for OpenBLAS library:"
if [ -f /usr/lib/x86_64-linux-gnu/libopenblas.so ] || [ -f /usr/lib/x86_64-linux-gnu/libopenblas.a ]; then
    echo "   Found OpenBLAS in /usr/lib/x86_64-linux-gnu/"
    ls -lh /usr/lib/x86_64-linux-gnu/libopenblas* 2>/dev/null || true
elif [ -f /usr/lib/aarch64-linux-gnu/libopenblas.so ] || [ -f /usr/lib/aarch64-linux-gnu/libopenblas.a ]; then
    echo "   Found OpenBLAS in /usr/lib/aarch64-linux-gnu/"
    ls -lh /usr/lib/aarch64-linux-gnu/libopenblas* 2>/dev/null || true
elif [ -f /usr/lib/libopenblas.so ] || [ -f /usr/lib/libopenblas.a ]; then
    echo "   Found OpenBLAS in /usr/lib/"
    ls -lh /usr/lib/libopenblas* 2>/dev/null || true
else
    echo "   WARNING: OpenBLAS library not found in standard locations"
    echo "   Searching in common paths..."
    find /usr/lib -name "*openblas*" 2>/dev/null | head -5 || echo "   No OpenBLAS found"
fi
echo ""

# Check if OpenBLAS headers are found
echo "3. Checking for OpenBLAS headers:"
if [ -f /usr/include/openblas/f77blas.h ]; then
    echo "   Found OpenBLAS headers in /usr/include/openblas/"
elif [ -f /usr/include/f77blas.h ]; then
    echo "   Found OpenBLAS headers in /usr/include/"
else
    echo "   WARNING: OpenBLAS headers not found"
    find /usr/include -name "f77blas.h" 2>/dev/null | head -3 || echo "   No f77blas.h found"
fi
echo ""

# Test CMake detection (if build directory exists)
if [ -d /root/openface/build ]; then
    echo "4. Testing CMake OpenBLAS detection:"
    cd /root/openface/build
    cmake .. 2>&1 | grep -i "openblas" || echo "   Run 'cmake ..' to see OpenBLAS detection output"
    echo ""
fi

# Check installed packages
echo "5. Installed OpenBLAS packages:"
dpkg -l | grep -i openblas || echo "   No OpenBLAS packages found via dpkg"
echo ""

echo "=== Test Complete ==="

