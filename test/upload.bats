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

run_upload_site_stubbed() {
    _upload_dir() { echo "$3 $4 $5 $6 $7" >>"${TEST_TMP}/calls"; }
    touch "${TEST_TMP}/p.hdr" "${TEST_TMP}/s.hdr"
    upload_site "${TEST_TMP}/p.hdr" "${TEST_TMP}/s.hdr" host \
        pz sz /site c
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

@test "upload_site mirrors gallery pages to galleries" {
    run_upload_site_stubbed
    run cat "${TEST_TMP}/calls"
    [[ "${output}" == *"sz /site/gallery/c gallery/c 0 0"* ]]
    [[ "${output}" == *"sz /site/gallery/c/pic gallery/c/pic 0 0"* ]]
    [[ "${output}" == *"sz /site/gallery/c galleries/c 0 0"* ]]
    [[ "${output}" == *"sz /site/gallery/c/pic galleries/c/pic 0 0"* ]]
}

@test "upload_site sends only gallery pages under galleries" {
    run_upload_site_stubbed
    run awk '$3 ~ /^galleries\// && $2 ~ /^\/site\/gallery\//' \
        "${TEST_TMP}/calls"
    [[ "$(wc -l <<<"${output}")" -eq 2 ]]
    run awk '$3 ~ /^galleries\// && $2 !~ /^\/site\/gallery\//' \
        "${TEST_TMP}/calls"
    [[ -z "${output}" ]]
}
