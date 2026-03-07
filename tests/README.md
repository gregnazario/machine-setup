# Test Suite

Comprehensive test suite for the machine setup system.

## Structure

```
tests/
├── unit/              # Unit tests for individual components
│   ├── test-profile-loader.sh
│   ├── test-profile-inheritance.sh
│   ├── test-package-collection.sh
│   ├── test-dotfiles-linking.sh
│   ├── test-backup-config.sh
│   └── test-platform-packages.sh
├── integration/       # Integration tests for complete workflows
│   ├── test-setup-ubuntu.sh
│   └── test-setup-macos.sh
├── e2e/               # End-to-end tests simulating real usage
│   └── test-fresh-setup.sh
└── run-tests.sh       # Local test runner
```

## Running Tests

### Local Testing

Run all tests locally:
```bash
./tests/run-tests.sh
```

Run specific test:
```bash
bash tests/unit/test-profile-loader.sh
bash tests/integration/test-setup-ubuntu.sh
bash tests/e2e/test-fresh-setup.sh
```

### GitHub CI

Tests run automatically on:
- Push to `main` or `develop` branches
- Pull requests to `main`
- Manual workflow dispatch

View results in the Actions tab on GitHub.

## Test Categories

### Unit Tests

Test individual components in isolation:

- **test-profile-loader.sh**: Validates profile loading and YAML parsing
- **test-profile-inheritance.sh**: Tests profile extension/inheritance
- **test-package-collection.sh**: Tests package name mapping and collection
- **test-dotfiles-linking.sh**: Validates dotfiles structure and linking
- **test-backup-config.sh**: Tests backup configuration validity
- **test-platform-packages.sh**: Validates platform-specific package definitions

### Integration Tests

Test complete workflows on real systems:

- **test-setup-ubuntu.sh**: Full setup test on Ubuntu
- **test-setup-macos.sh**: Full setup test on macOS

### E2E Tests

Simulate real-world usage scenarios:

- **test-fresh-setup.sh**: Simulates setting up a fresh machine from scratch

## CI Workflow

The GitHub Actions workflow (`.github/workflows/test.yml`) runs:

1. **Lint & Validate**: YAML linting, shellcheck, JSON validation
2. **Platform Detection**: Tests on Ubuntu, macOS, and Windows
3. **Profile System**: Tests profile loading and inheritance
4. **Package Installation**: Tests package collection (dry-run)
5. **Dotfiles Linking**: Tests symlink creation (dry-run)
6. **Integration Tests**: Full setup tests on Ubuntu and macOS
7. **Backup Configuration**: Tests backup script generation
8. **E2E Simulation**: Complete fresh machine setup simulation
9. **Security Checks**: Validates no secrets in code, git-crypt config
10. **Documentation Check**: Validates required documentation
11. **Platform Matrix**: Tests all 8 platform package definitions

## Writing New Tests

### Unit Test Template

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "Testing: [your test description]"

# Source required scripts
source "${REPO_ROOT}/scripts/platform-detect.sh"

# Your test logic here
if [[ condition ]]; then
    echo "❌ FAIL: reason"
    exit 1
fi

echo "✅ PASS: test passed"
```

### Best Practices

1. **Isolation**: Each test should be independent
2. **Cleanup**: Remove test artifacts in finally block
3. **Dry-run**: Use `--dry-run` flags where possible
4. **Mocking**: Mock external dependencies (restic, syncthing)
5. **Clarity**: Clear pass/fail messages
6. **Speed**: Keep tests fast for quick feedback

## Debugging Failed Tests

1. **View logs**: Check `/tmp/test-*.log` files
2. **Run locally**: Reproduce with `bash tests/path/to/test.sh`
3. **Verbose mode**: Add `set -x` to test script for debugging
4. **CI logs**: Check GitHub Actions logs for detailed output

## Test Coverage

The test suite covers:

- ✅ All 8 platforms (Fedora, Ubuntu, Gentoo, Void, RaspberryPiOS, macOS, FreeBSD, Windows)
- ✅ All profiles (minimal, full, custom)
- ✅ Package installation logic
- ✅ Dotfile linking
- ✅ Profile inheritance
- ✅ git-crypt configuration
- ✅ Backup configuration
- ✅ Documentation validation
- ✅ Security checks

## Dependencies

- `bash` 4.0+
- `yq` (YAML processor)
- `shellcheck` (for linting)
- `yamllint` (for YAML linting)

Install on Ubuntu:
```bash
sudo apt-get install shellcheck yamllint
# Install yq manually
sudo wget https://github.com/mikefarah/yq/releases/download/v4.35.1/yq_linux_amd64 -O /usr/local/bin/yq
sudo chmod +x /usr/local/bin/yq
```

Install on macOS:
```bash
brew install shellcheck yamllint yq
```
