#!/usr/bin/env bats

setup() {
    TEST_TMP="$(mktemp -d)"
    export TEST_TMP
    mkdir -p "${TEST_TMP}/full" "${TEST_TMP}/web" "${TEST_TMP}/out"
    cat >"${TEST_TMP}/config.toml" <<'TOML'
[source]
full_dir = "FULL"
web_dir = "WEB"
expected_count = 3

[output]
manifest_dir = "OUT"
collection_name = "test-wedding"
TOML
    sed -i "s|FULL|${TEST_TMP}/full|; s|WEB|${TEST_TMP}/web|; \
s|OUT|${TEST_TMP}/out|" "${TEST_TMP}/config.toml"
}

teardown() {
    rm -rf "${TEST_TMP}"
}

@test "load_config exposes every configured value" {
    source scripts/lib/config.sh
    run load_config "${TEST_TMP}/config.toml"
    [[ "$status" -eq 0 ]]

    source scripts/lib/config.sh
    load_config "${TEST_TMP}/config.toml"
    [[ "$CFG_FULL_DIR" == "${TEST_TMP}/full" ]]
    [[ "$CFG_WEB_DIR" == "${TEST_TMP}/web" ]]
    [[ "$CFG_EXPECTED_COUNT" == "3" ]]
    [[ "$CFG_MANIFEST_DIR" == "${TEST_TMP}/out" ]]
    [[ "$CFG_COLLECTION_NAME" == "test-wedding" ]]
}

@test "load_config fails naming a missing config file" {
    source scripts/lib/config.sh
    run load_config "${TEST_TMP}/absent.toml"
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"${TEST_TMP}/absent.toml"* ]]
}

@test "load_config fails naming an empty config file" {
    : >"${TEST_TMP}/empty.toml"
    source scripts/lib/config.sh
    run load_config "${TEST_TMP}/empty.toml"
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"full_dir"* ]]
}

@test "load_config fails naming a nonexistent source dir" {
    sed -i "s|${TEST_TMP}/full|${TEST_TMP}/absent|" \
        "${TEST_TMP}/config.toml"
    source scripts/lib/config.sh
    run load_config "${TEST_TMP}/config.toml"
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"${TEST_TMP}/absent"* ]]
}

@test "load_config accepts a source dir containing a space" {
    mkdir -p "${TEST_TMP}/with space"
    sed -i "s|${TEST_TMP}/full|${TEST_TMP}/with space|" \
        "${TEST_TMP}/config.toml"
    source scripts/lib/config.sh
    run load_config "${TEST_TMP}/config.toml"
    [[ "$status" -eq 0 ]]
}

@test "load_config resolves a relative path against repo root" {
    sed -i "s|${TEST_TMP}/out|_build/test-out|" \
        "${TEST_TMP}/config.toml"
    source scripts/lib/config.sh
    load_config "${TEST_TMP}/config.toml"
    [[ "$CFG_MANIFEST_DIR" == "$(git rev-parse --show-toplevel)/_build/test-out" ]]
}

@test "load_config leaves an absolute path unchanged" {
    source scripts/lib/config.sh
    load_config "${TEST_TMP}/config.toml"
    [[ "$CFG_MANIFEST_DIR" == "${TEST_TMP}/out" ]]
}
