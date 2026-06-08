#!/usr/bin/env bats
# tests/stage.bats
# Stage contract specs. See doc/v01.md.

setup() {
    source "${BATS_TEST_DIRNAME}/../scripts/lib/stage.sh"
    STAGE_RUN_DIR="$(mktemp -d)"
    export STAGE_RUN_DIR
}

teardown() {
    rm -rf "$STAGE_RUN_DIR"
}

@test "run_stage writes 'success' when the command exits 0" {
    run_stage noop -- true
    [ "$(cat "$STAGE_RUN_DIR/noop.status")" = "success" ]
}