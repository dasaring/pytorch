#!/bin/bash
# Script to install Python and common Python packages in Docker containers
# Used across different base images (Ubuntu, AlmaLinux, etc.)

set -ex

# Default Python version if not specified
PYTHON_VERSION=${PYTHON_VERSION:-3.10}

echo "Installing Python ${PYTHON_VERSION}..."

# Detect OS type
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID=$ID
else
    OS_ID="unknown"
fi

install_python_ubuntu() {
    # Add deadsnakes PPA for multiple Python versions
    apt-get update
    apt-get install -y software-properties-common
    add-apt-repository -y ppa:deadsnakes/ppa
    apt-get update

    apt-get install -y \
        python${PYTHON_VERSION} \
        python${PYTHON_VERSION}-dev \
        python${PYTHON_VERSION}-distutils \
        python${PYTHON_VERSION}-venv

    # Install pip for the target Python version
    curl -sS https://bootstrap.pypa.io/get-pip.py | python${PYTHON_VERSION}

    # Create symlinks if this is the primary Python version
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python${PYTHON_VERSION} 1
    update-alternatives --install /usr/bin/python python /usr/bin/python${PYTHON_VERSION} 1
}

install_python_almalinux() {
    # AlmaLinux / RHEL-based systems
    dnf install -y \
        python${PYTHON_VERSION/./} \
        python${PYTHON_VERSION/./}-devel \
        python${PYTHON_VERSION/./}-pip || true

    # Fallback: build from source if package not available
    if ! command -v python${PYTHON_VERSION} &>/dev/null; then
        echo "Package not found, installing Python ${PYTHON_VERSION} from source..."
        dnf install -y gcc openssl-devel bzip2-devel libffi-devel zlib-devel wget make

        PYTHON_MAJOR_MINOR=${PYTHON_VERSION}
        wget -q "https://www.python.org/ftp/python/${PYTHON_MAJOR_MINOR}.0/Python-${PYTHON_MAJOR_MINOR}.0.tgz"
        tar xzf "Python-${PYTHON_MAJOR_MINOR}.0.tgz"
        cd "Python-${PYTHON_MAJOR_MINOR}.0"
        ./configure --enable-optimizations --with-ensurepip=install
        make altinstall -j"$(nproc)"
        cd ..
        rm -rf "Python-${PYTHON_MAJOR_MINOR}.0" "Python-${PYTHON_MAJOR_MINOR}.0.tgz"
    fi

    # Create symlinks
    alternatives --install /usr/bin/python3 python3 /usr/local/bin/python${PYTHON_VERSION} 1 || true
    alternatives --install /usr/bin/python python /usr/local/bin/python${PYTHON_VERSION} 1 || true
}

# Dispatch to OS-specific installer
case "$OS_ID" in
    ubuntu | debian)
        install_python_ubuntu
        ;;
    almalinux | rhel | centos | fedora)
        install_python_almalinux
        ;;
    *)
        echo "Unsupported OS: $OS_ID. Attempting Ubuntu-style install..."
        install_python_ubuntu
        ;;
esac

# Upgrade pip and install common build/test dependencies
pip${PYTHON_VERSION} install --upgrade pip setuptools wheel || \
    python${PYTHON_VERSION} -m pip install --upgrade pip setuptools wheel

# Install common Python packages needed for PyTorch CI
pip install \
    numpy \
    pyyaml \
    typing_extensions \
    requests \
    six \
    hypothesis \
    expecttest

echo "Python ${PYTHON_VERSION} installation complete."
python${PYTHON_VERSION} --version
pip --version
