#!/bin/bash
# Script to install CUDA toolkit and cuDNN for PyTorch CI Docker images
# Supports multiple CUDA versions across different Linux distributions

set -ex

# Validate required environment variables
if [ -z "$CUDA_VERSION" ]; then
    echo "ERROR: CUDA_VERSION is not set"
    exit 1
fi

CUDA_MAJOR=$(echo "$CUDA_VERSION" | cut -d. -f1)
CUDA_MINOR=$(echo "$CUDA_VERSION" | cut -d. -f2)
CUDA_PATCH=$(echo "$CUDA_VERSION" | cut -d. -f3)

echo "Installing CUDA ${CUDA_VERSION} (major=${CUDA_MAJOR}, minor=${CUDA_MINOR})"

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID=$ID
    OS_VERSION_ID=$VERSION_ID
else
    echo "ERROR: Cannot detect OS version"
    exit 1
fi

install_cuda_ubuntu() {
    local cuda_ver=$1
    local ubuntu_ver
    ubuntu_ver=$(echo "$OS_VERSION_ID" | tr -d '.')

    # Add NVIDIA CUDA repository
    local repo_url="https://developer.download.nvidia.com/compute/cuda/repos/ubuntu${ubuntu_ver}/x86_64"
    local pin_file="cuda-ubuntu${ubuntu_ver}.pin"

    wget -q "${repo_url}/${pin_file}" -O /etc/apt/preferences.d/cuda-repository-pin-600
    apt-key adv --fetch-keys "${repo_url}/3bf863cc.pub" 2>/dev/null || true
    add-apt-repository "deb ${repo_url}/ /" -y

    apt-get update -q

    # Install CUDA toolkit packages
    local cuda_pkg_ver
    cuda_pkg_ver=$(echo "$cuda_ver" | tr '.' '-')

    apt-get install -y --no-install-recommends \
        "cuda-cudart-${cuda_pkg_ver}" \
        "cuda-libraries-${cuda_pkg_ver}" \
        "cuda-nvtx-${cuda_pkg_ver}" \
        "libcufft-dev-${cuda_pkg_ver}" \
        "libcurand-dev-${cuda_pkg_ver}" \
        "libcusolver-dev-${cuda_pkg_ver}" \
        "libcusparse-dev-${cuda_pkg_ver}" \
        "cuda-compiler-${cuda_pkg_ver}" \
        "cuda-libraries-dev-${cuda_pkg_ver}" \
        "cuda-nvml-dev-${cuda_pkg_ver}" \
        "cuda-minimal-build-${cuda_pkg_ver}"

    # Clean up apt cache
    rm -rf /var/lib/apt/lists/*
}

install_cuda_almalinux() {
    local cuda_ver=$1
    local rhel_ver
    rhel_ver=$(echo "$OS_VERSION_ID" | cut -d. -f1)

    # Add NVIDIA CUDA repository for RHEL/AlmaLinux
    dnf config-manager --add-repo \
        "https://developer.download.nvidia.com/compute/cuda/repos/rhel${rhel_ver}/x86_64/cuda-rhel${rhel_ver}.repo"

    dnf clean all

    # Install CUDA toolkit packages
    local cuda_pkg_ver
    cuda_pkg_ver=$(echo "$cuda_ver" | tr '.' '-')

    dnf install -y \
        "cuda-cudart-${cuda_pkg_ver}" \
        "cuda-libraries-${cuda_pkg_ver}" \
        "cuda-nvtx-${cuda_pkg_ver}" \
        "cuda-compiler-${cuda_pkg_ver}" \
        "cuda-libraries-devel-${cuda_pkg_ver}" \
        "cuda-minimal-build-${cuda_pkg_ver}"

    dnf clean all
}

# Set CUDA environment variables
configure_cuda_env() {
    local cuda_ver=$1
    local cuda_home="/usr/local/cuda-${cuda_ver}"

    if [ ! -d "$cuda_home" ]; then
        cuda_home="/usr/local/cuda"
    fi

    cat >> /etc/environment <<EOF
CUDA_HOME=${cuda_home}
CUDA_PATH=${cuda_home}
PATH=${cuda_home}/bin:\$PATH
LD_LIBRARY_PATH=${cuda_home}/lib64:\$LD_LIBRARY_PATH
EOF

    # Create symlink if versioned directory exists
    if [ -d "/usr/local/cuda-${cuda_ver}" ] && [ ! -L "/usr/local/cuda" ]; then
        ln -sf "/usr/local/cuda-${cuda_ver}" /usr/local/cuda
    fi
}

# Main installation logic
case "$OS_ID" in
    ubuntu)
        install_cuda_ubuntu "${CUDA_MAJOR}.${CUDA_MINOR}"
        ;;
    almalinux | rhel | centos)
        install_cuda_almalinux "${CUDA_MAJOR}.${CUDA_MINOR}"
        ;;
    *)
        echo "ERROR: Unsupported OS: ${OS_ID}"
        exit 1
        ;;
esac

configure_cuda_env "${CUDA_MAJOR}.${CUDA_MINOR}"

echo "CUDA ${CUDA_VERSION} installation complete"
