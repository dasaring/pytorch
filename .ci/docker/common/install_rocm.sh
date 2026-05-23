#!/bin/bash
# Script to install ROCm (AMD GPU) dependencies in Docker containers
# This is used by the CI Docker build process

set -ex

# Supported ROCm versions
ROCM_VERSION=${1:-"5.7"}

# Validate ROCm version format
if [[ ! "$ROCM_VERSION" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
    echo "ERROR: Invalid ROCm version format: $ROCM_VERSION"
    echo "Expected format: X.Y or X.Y.Z (e.g., 5.7 or 5.7.1)"
    exit 1
fi

echo "Installing ROCm version: $ROCM_VERSION"

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID=$ID
    OS_VERSION=$VERSION_ID
else
    echo "ERROR: Cannot detect OS version"
    exit 1
fi

# Install ROCm repository key and repo
install_rocm_ubuntu() {
    local rocm_ver="$1"
    local ubuntu_ver="$2"

    apt-get update -q
    apt-get install -y --no-install-recommends \
        wget \
        gnupg2 \
        ca-certificates

    # Add ROCm apt repository
    wget -q -O - https://repo.radeon.com/rocm/rocm.gpg.key | apt-key add -
    echo "deb [arch=amd64] https://repo.radeon.com/rocm/apt/${rocm_ver} ubuntu${ubuntu_ver} main" \
        > /etc/apt/sources.list.d/rocm.list

    apt-get update -q
    apt-get install -y --no-install-recommends \
        rocm-dev \
        rocm-libs \
        miopen-hip \
        rocblas \
        rocfft \
        rocrand \
        rocsolver \
        rocsparse \
        hipsparse \
        hipfft \
        hipblas \
        rccl

    # Clean up apt cache
    apt-get clean
    rm -rf /var/lib/apt/lists/*
}

install_rocm_centos() {
    local rocm_ver="$1"

    # Install prerequisites
    yum install -y \
        wget \
        gnupg2 \
        ca-certificates

    # Add ROCm yum repository
    cat > /etc/yum.repos.d/rocm.repo <<EOF
[ROCm]
name=ROCm
baseurl=https://repo.radeon.com/rocm/yum/${rocm_ver}/main
enabled=1
gpgcheck=1
gpgkey=https://repo.radeon.com/rocm/rocm.gpg.key
EOF

    yum install -y \
        rocm-dev \
        rocm-libs \
        miopen-hip \
        rocblas \
        rocfft \
        rocrand \
        rocsolver \
        rocsparse

    # Clean up yum cache
    yum clean all
    rm -rf /var/cache/yum
}

# Install based on detected OS
case "$OS_ID" in
    ubuntu)
        # Strip minor version from Ubuntu version (e.g., 22.04 -> 2204)
        UBUNTU_VER=$(echo "$OS_VERSION" | tr -d '.')
        install_rocm_ubuntu "$ROCM_VERSION" "$UBUNTU_VER"
        ;;
    centos | almalinux | rhel)
        install_rocm_centos "$ROCM_VERSION"
        ;;
    *)
        echo "ERROR: Unsupported OS: $OS_ID"
        exit 1
        ;;
esac

# Set ROCm environment variables
ROCM_PATH=/opt/rocm
echo "export ROCM_PATH=${ROCM_PATH}" >> /etc/environment
echo "export HIP_PATH=${ROCM_PATH}" >> /etc/environment
echo "export PATH=\$PATH:${ROCM_PATH}/bin:${ROCM_PATH}/hip/bin" >> /etc/environment
echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:${ROCM_PATH}/lib:${ROCM_PATH}/lib64" >> /etc/environment

echo "ROCm ${ROCM_VERSION} installation complete."
