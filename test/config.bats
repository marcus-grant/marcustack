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
site_dir = "OUT"
collection_name = "test-wedding"
[normpic]
version = "v0.1.1"
[galleria]
version = "v0.0.1"
[deploy]
rclone_conf = "RCONF"
pics_remote = "test-pics"
site_remote = "test-site"
TOML
    sed -i "s|FULL|${TEST_TMP}/full|; s|WEB|${TEST_TMP}/web|; \
s|OUT|${TEST_TMP}/out|; s|RCONF|${TEST_TMP}/rclone.conf|" \
        "${TEST_TMP}/config.toml"
    touch "${TEST_TMP}/rclone.conf"
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
    [[ "$CFG_SITE_DIR" == "${TEST_TMP}/out" ]]
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
    [[ "$CFG_SITE_DIR" == "$(git rev-parse --show-toplevel)/_build/test-out" ]]
}

@test "load_config leaves an absolute path unchanged" {
    source scripts/lib/config.sh
    load_config "${TEST_TMP}/config.toml"
    [[ "$CFG_SITE_DIR" == "${TEST_TMP}/out" ]]
}

@test "load_config exposes site_dir and deploy values" {
    source scripts/lib/config.sh
    load_config "${TEST_TMP}/config.toml"
    [[ "$CFG_SITE_DIR" == "${TEST_TMP}/out" ]]
    [[ "$CFG_GALLERIA_VERSION" == "v0.0.1" ]]
    [[ "$CFG_RCLONE_CONF" == "${TEST_TMP}/rclone.conf" ]]
    [[ "$CFG_PICS_REMOTE" == "test-pics" ]]
    [[ "$CFG_SITE_REMOTE" == "test-site" ]]
}

@test "load_config fails naming a missing site_dir" {
    sed -i '/^site_dir/d' "${TEST_TMP}/config.toml"
    source scripts/lib/config.sh
    run load_config "${TEST_TMP}/config.toml"
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"site_dir"* ]]
}
