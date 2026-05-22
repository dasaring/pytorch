#!/bin/bash
# Script to install base dependencies for PyTorch CI Docker images
# This script is sourced by various Dockerfiles to set up common system packages

set -ex

# Function to install packages with retry logic
install_with_retry() {
    local max_attempts=3
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        if "$@"; then
            return 0
        fi
        echo "Attempt $attempt failed. Retrying..."
        attempt=$((attempt + 1))
        sleep 5
    done
    echo "All $max_attempts attempts failed."
    return 1
}

# Detect OS and set package manager
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID=$ID
else
    echo "Cannot detect OS"
    exit 1
fi

echo "Detected OS: $OS_ID"

# Install base packages based on OS
case "$OS_ID" in
    ubuntu|debian)
        export DEBIAN_FRONTEND=noninteractive
        install_with_retry apt-get update -qq
        install_with_retry apt-get install -y --no-install-recommends \
            build-essential \
            ca-certificates \
            ccache \
            cmake \
            curl \
            git \
            libjpeg-dev \
            libpng-dev \
            sudo \
            unzip \
            wget \
            vim \
            ninja-build \
            libssl-dev \
            pkg-config
        # Clean up apt cache to reduce image size
        rm -rf /var/lib/apt/lists/*
        ;;
    almalinux|rhel|centos|fedora)
        install_with_retry yum update -y
        install_with_retry yum install -y \
            bzip2 \
            ca-certificates \
            cmake \
            curl \
            gcc \
            gcc-c++ \
            git \
            libjpeg-devel \
            libpng-devel \
            make \
            openssl-devel \
            sudo \
            unzip \
            wget \
            vim \
            ninja-build \
            pkgconfig
        # Clean up yum cache
        yum clean all
        rm -rf /var/cache/yum
        ;;
    *)
        echo "Unsupported OS: $OS_ID"
        exit 1
        ;;
esac

# Set up ccache
if command -v ccache &> /dev/null; then
    echo "Configuring ccache..."
    ccache --max-size 25Gi
    # Add ccache to PATH for compiler wrapping
    export PATH="/usr/lib/ccache:$PATH"
fi

# Configure git safe directory to avoid ownership issues in containers
git config --global --add safe.directory '*'

echo "Base installation complete."
