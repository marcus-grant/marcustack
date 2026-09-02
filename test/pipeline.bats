#!/usr/bin/env bats

setup() {
    TEST_TMP="$(mktemp -d)"
    export TEST_TMP
    REPO_ROOT="$(git rev-parse --show-toplevel)"
    mkdir -p "${TEST_TMP}/bin" "${TEST_TMP}/full" "${TEST_TMP}/web"
    cat >"${TEST_TMP}/bin/normpic" <<'STUB'
#!/usr/bin/env bash
echo "normpic $*" >>"${STUB_LOG}"
STUB
    cat >"${TEST_TMP}/bin/uv" <<'STUB'
#!/usr/bin/env bash
echo "uv $*" >>"${STUB_LOG}"
STUB
    cat >"${TEST_TMP}/bin/rclone" <<'STUB'
#!/usr/bin/env bash
echo "rclone $*" >>"${STUB_LOG}"
STUB
    chmod +x "${TEST_TMP}/bin/"*
    export STUB_LOG="${TEST_TMP}/stub.log"
    touch "${STUB_LOG}" "${TEST_TMP}/rclone.conf"
    cat >"${TEST_TMP}/config.toml" <<TOML
[source]
full_dir = "${TEST_TMP}/full"
web_dir = "${TEST_TMP}/web"
expected_count = 3
[output]
site_dir = "${TEST_TMP}/site"
collection_name = "test-wedding"
[normpic]
version = "v0.1.1"
[galleria]
version = "v0.0.2"
[deploy]
rclone_conf = "${TEST_TMP}/rclone.conf"
pics_remote = "test-pics"
site_remote = "test-site"
TOML
    export MARCUSTACK_CONFIG="${TEST_TMP}/config.toml"
    export PATH="${TEST_TMP}/bin:${PATH}"
    hash -r
}

teardown() {
    rm -rf "${TEST_TMP}"
}

@test "pipeline invokes normpic with per-kind dest dirs" {
    run bash "${REPO_ROOT}/scripts/pipeline.sh"
    grep -q -- "--dest-dir ${TEST_TMP}/site/pics/test-wedding/original" \
        "${STUB_LOG}"
    grep -q -- "--dest-dir ${TEST_TMP}/site/pics/test-wedding/display" \
        "${STUB_LOG}"
}

@test "pipeline galleria stage uses the configured pin" {
    grep -q 'galleria@${CFG_GALLERIA_VERSION}' \
        "${REPO_ROOT}/scripts/pipeline.sh"
    grep -q -- '--output-dir "${CFG_SITE_DIR}"' \
        "${REPO_ROOT}/scripts/pipeline.sh"
}

@test "pipeline does not upload when verification fails" {
    run bash "${REPO_ROOT}/scripts/pipeline.sh"
    [[ "$status" -ne 0 ]] || ! grep -q rclone "${STUB_LOG}"
}
