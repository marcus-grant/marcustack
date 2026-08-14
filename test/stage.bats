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

@test "run_stage writes 'failure' when the command exits non-zero" {
    run_stage failing -- false
    [[ "$(cat "${STAGE_RUN_DIR}/failing.status")" == "failure" ]]
}

@test "run_stage returns 0 on failure per failure isolation" {
    run run_stage failing -- false
    [[ "$status" -eq 0 ]]
}

@test "run_stage reports a failure on stderr naming the stage" {
    run run_stage failing -- false
    [[ "$output" == *"failing"* ]]
}

@test "run_stage failure output omits command arguments" {
    run run_stage failing -- false /secret/path
    [[ "$output" != *"/secret/path"* ]]
}

@test "run_stage fails naming STAGE_RUN_DIR when unset" {
    unset STAGE_RUN_DIR
    run run_stage anything -- true
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"STAGE_RUN_DIR"* ]]
}

@test "run_stage fails when STAGE_RUN_DIR does not exist" {
    STAGE_RUN_DIR="${STAGE_RUN_DIR}/absent"
    run run_stage anything -- true
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"STAGE_RUN_DIR"* ]]
}
