#!/usr/bin/env bats

setup() {
    TEST_TMP="$(mktemp -d)"
    export TEST_TMP
    source scripts/lib/upload.sh
    mkdir -p "${TEST_TMP}/local"
    echo alpha >"${TEST_TMP}/local/a.jpg"
    echo beta >"${TEST_TMP}/local/b.jpg"
    LISTING="${TEST_TMP}/listing"
    export LISTING
}

teardown() {
    rm -rf "${TEST_TMP}"
}

sum_of() {
    sha256sum <"$1" | cut -d' ' -f1
}

@test "plan puts every file against an empty listing" {
    : >"${LISTING}"
    run upload_plan_dir "${TEST_TMP}/local" "${LISTING}" 0 0
    [[ "$output" == *"put a.jpg"* ]]
    [[ "$output" == *"put b.jpg"* ]]
}

@test "plan skips a file whose checksum matches" {
    printf '%s  a.jpg\n' "$(sum_of "${TEST_TMP}/local/a.jpg")" \
        >"${LISTING}"
    run upload_plan_dir "${TEST_TMP}/local" "${LISTING}" 0 0
    [[ "$output" == *"skip a.jpg"* ]]
    [[ "$output" == *"put b.jpg"* ]]
}

@test "plan puts a file whose checksum differs" {
    printf '%s  a.jpg\n' "$(sum_of "${TEST_TMP}/local/b.jpg")" \
        >"${LISTING}"
    run upload_plan_dir "${TEST_TMP}/local" "${LISTING}" 0 0
    [[ "$output" == *"put a.jpg"* ]]
}

@test "plan matches uppercase remote checksums" {
    sum_of "${TEST_TMP}/local/a.jpg" | tr '[:lower:]' '[:upper:]' |
        xargs -I{} printf '%s  a.jpg\n' {} >"${LISTING}"
    run upload_plan_dir "${TEST_TMP}/local" "${LISTING}" 0 0
    [[ "$output" == *"skip a.jpg"* ]]
}

@test "plan deletes a remote file absent locally" {
    printf -- '-  gone.jpg\n' >"${LISTING}"
    run upload_plan_dir "${TEST_TMP}/local" "${LISTING}" 0 0
    [[ "$output" == *"del gone.jpg"* ]]
}

@test "skip-existing mode never deletes and never re-puts" {
    printf -- '-  a.jpg\n-  gone.jpg\n' >"${LISTING}"
    run upload_plan_dir "${TEST_TMP}/local" "${LISTING}" 1 0
    [[ "$output" == *"skip a.jpg"* ]]
    [[ "$output" != *"del"* ]]
    [[ "$output" != *"put a.jpg"* ]]
}

@test "exclude mode leaves manifest.json unmentioned" {
    echo m >"${TEST_TMP}/local/manifest.json"
    : >"${LISTING}"
    run upload_plan_dir "${TEST_TMP}/local" "${LISTING}" 1 1
    [[ "$output" != *"manifest.json"* ]]
}

@test "plan handles a filename containing a space" {
    echo s >"${TEST_TMP}/local/my pic.jpg"
    : >"${LISTING}"
    run upload_plan_dir "${TEST_TMP}/local" "${LISTING}" 0 0
    [[ "$output" == *"put my pic.jpg"* ]]
}
