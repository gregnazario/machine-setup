FROM mcr.microsoft.com/devcontainers/base:ubuntu

# Install machine-setup dependencies
RUN apt-get update && apt-get install -y \
    bash \
    git \
    git-crypt \
    gnupg \
    shellcheck \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy the repo
COPY . /workspace/machine-setup
WORKDIR /workspace/machine-setup

# Initialize bats submodules
RUN git init && git submodule update --init --recursive tests/libs/ 2>/dev/null || true

# Run setup in dry-run mode to validate
RUN bash setup.sh --dry-run --profile minimal --no-syncthing --no-backup || true
