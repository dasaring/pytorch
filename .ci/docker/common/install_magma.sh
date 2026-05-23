#!/bin/bash
# Script to install MAGMA (Matrix Algebra on GPU and Multicore Architectures)
# MAGMA provides GPU-accelerated linear algebra routines used by PyTorch

set -ex

# MAGMA version to install
MAGMA_VERSION=${MAGMA_VERSION:-2.6.1}

# Determine CUDA version for selecting the right MAGMA package
if [ -z "$CUDA_VERSION" ]; then
    echo "CUDA_VERSION is not set, skipping MAGMA installation"
    exit 0
fi

# Extract major and minor version numbers
CUDA_VERSION_SHORT=$(echo "$CUDA_VERSION" | cut -d. -f1,2 | tr -d '.')

echo "Installing MAGMA ${MAGMA_VERSION} for CUDA ${CUDA_VERSION}"

# Map CUDA version to MAGMA package suffix
case "$CUDA_VERSION_SHORT" in
    118)
        MAGMA_CUDA_VERSION="cuda118"
        ;;
    121)
        MAGMA_CUDA_VERSION="cuda121"
        ;;
    124)
        MAGMA_CUDA_VERSION="cuda124"
        ;;
    126)
        MAGMA_CUDA_VERSION="cuda126"
        ;;
    *)
        echo "Unsupported CUDA version for MAGMA: ${CUDA_VERSION}"
        echo "Supported versions: 11.8, 12.1, 12.4, 12.6"
        exit 1
        ;;
esac

# Install MAGMA from conda-forge or the PyTorch conda channel
if command -v conda &> /dev/null; then
    conda install -y \
        -c pytorch \
        "magma-${MAGMA_CUDA_VERSION}=${MAGMA_VERSION}" \
        || conda install -y \
            -c conda-forge \
            "magma-${MAGMA_CUDA_VERSION}"
else
    # Fallback: build MAGMA from source or use pre-built binaries
    MAGMA_URL="https://icl.utk.edu/projectsfiles/magma/downloads/magma-${MAGMA_VERSION}.tar.gz"
    MAGMA_DIR="/tmp/magma-${MAGMA_VERSION}"
    MAGMA_INSTALL_DIR="/usr/local/magma"

    # Download MAGMA source
    curl -fsSL "${MAGMA_URL}" -o /tmp/magma.tar.gz
    mkdir -p "${MAGMA_DIR}"
    tar -xzf /tmp/magma.tar.gz -C "${MAGMA_DIR}" --strip-components=1

    # Configure and build MAGMA
    cd "${MAGMA_DIR}"
    cp make.inc-examples/make.inc.openblas make.inc

    # Update GPU target based on CUDA version
    sed -i 's/GPU_TARGET ?= .*/GPU_TARGET ?= Volta Turing Ampere/' make.inc
    sed -i "s|CUDADIR ?= .*|CUDADIR ?= /usr/local/cuda|" make.inc

    make -j"$(nproc)" lib sparse-lib
    make prefix="${MAGMA_INSTALL_DIR}" install

    # Set environment variables for downstream builds
    echo "export MAGMA_HOME=${MAGMA_INSTALL_DIR}" >> /etc/environment
    echo "export LD_LIBRARY_PATH=${MAGMA_INSTALL_DIR}/lib:\$LD_LIBRARY_PATH" >> /etc/environment

    # Cleanup
    rm -rf /tmp/magma.tar.gz "${MAGMA_DIR}"
fi

echo "MAGMA installation complete"
