#!/usr/bin/env bats

setup() {
    load '../test_helper'
    source "$REPO_ROOT/scripts/lib/common.sh"
}

@test "log_info outputs [INFO] tag" {
    run log_info "test message"
    assert_output --partial "[INFO]"
    assert_output --partial "test message"
}

@test "log_warn outputs [WARN] tag" {
    run log_warn "warn message"
    assert_output --partial "[WARN]"
}

@test "log_error outputs [ERROR] tag" {
    run log_error "error message"
    assert_output --partial "[ERROR]"
}

@test "log_success outputs [SUCCESS] tag" {
    run log_success "success message"
    assert_output --partial "[SUCCESS]"
}
