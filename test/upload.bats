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
    _upload_dir() { echo "$3 $4 $5 $6 $7 $8" >>"${TEST_TMP}/calls"; }
    touch "${TEST_TMP}/p.hdr" "${TEST_TMP}/s.hdr"
    upload_site "${TEST_TMP}/p.hdr" "${TEST_TMP}/s.hdr" host \
        pz sz /site c 7
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

make_curl_stub() {
    mkdir -p "${TEST_TMP}/bin"
    cat >"${TEST_TMP}/bin/curl" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${TEST_TMP}/curl.log"
out=""
while [[ $# -gt 0 ]]; do
    [[ "$1" == "-o" ]] && out="$2"
    shift
done
[[ -n "${out}" ]] && printf '%s' "${STUB_BODY:-}" >"${out}"
printf '%s' "${STUB_CODE:-200}"
exit "${STUB_RC:-0}"
STUB
    chmod +x "${TEST_TMP}/bin/curl"
    PATH="${TEST_TMP}/bin:${PATH}"
}

@test "_bunny_ls lists files only on 200" {
    make_curl_stub
    export STUB_CODE=200
    export STUB_BODY='[{"IsDirectory":false,"ObjectName":"a.jpg","Checksum":"ABC"},{"IsDirectory":true,"ObjectName":"d"}]'
    run _bunny_ls hdr host secretzone some/path
    [[ "$status" -eq 0 ]]
    [[ "$output" == "ABC  a.jpg" ]]
}

@test "_bunny_ls fails naming the path and status on 401" {
    make_curl_stub
    export STUB_CODE=401
    export STUB_BODY='{"Message":"Unauthorized"}'
    run _bunny_ls hdr host secretzone some/path
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"some/path"* ]]
    [[ "$output" == *"401"* ]]
    [[ "$output" != *"secretzone"* ]]
    [[ "$output" != *"host"* ]]
}

@test "_bunny_ls fails naming the path when curl exits nonzero" {
    make_curl_stub
    export STUB_CODE=200
    export STUB_BODY='[]'
    export STUB_RC=7
    run _bunny_ls hdr host secretzone some/path
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"some/path"* ]]
}

@test "_upload_dir executes no plan when the listing fails" {
    _bunny_ls() { return 1; }
    _bunny_put() { echo "$4" >>"${TEST_TMP}/puts"; }
    run _upload_dir hdr host zone "${TEST_TMP}/local" rdir 0 0
    [[ "$status" -ne 0 ]]
    [[ ! -s "${TEST_TMP}/puts" ]]
}

@test "_upload_dir stops at the first failed put" {
    _bunny_ls() { :; }
    _bunny_put() { echo "$4" >>"${TEST_TMP}/puts"; return 1; }
    run _upload_dir hdr host zone "${TEST_TMP}/local" rdir 0 0
    [[ "$status" -ne 0 ]]
    [[ "$(wc -l <"${TEST_TMP}/puts")" -eq 1 ]]
}

@test "_upload_dir fails when a delete fails" {
    _bunny_ls() { echo "abc  gone.jpg"; }
    _bunny_put() { return 0; }
    _bunny_rm() { return 1; }
    run _upload_dir hdr host zone "${TEST_TMP}/local" rdir 0 0
    [[ "$status" -ne 0 ]]
}

@test "upload_site stops at the first failing directory" {
    _upload_dir() { echo "$5" >>"${TEST_TMP}/calls"; return 1; }
    touch "${TEST_TMP}/p.hdr" "${TEST_TMP}/s.hdr"
    run upload_site "${TEST_TMP}/p.hdr" "${TEST_TMP}/s.hdr" host \
        pz sz /site c
    [[ "$status" -ne 0 ]]
    [[ "$(wc -l <"${TEST_TMP}/calls")" -eq 1 ]]
}

stage_upload_with_put() {
    source scripts/lib/stage.sh
    STAGE_RUN_DIR="${TEST_TMP}/run"
    mkdir -p "${STAGE_RUN_DIR}" "${TEST_TMP}/site/pics/c/original"
    echo x >"${TEST_TMP}/site/pics/c/original/x.jpg"
    touch "${TEST_TMP}/p.hdr" "${TEST_TMP}/s.hdr"
    _bunny_ls() { :; }
    _bunny_rm() { return 0; }
}

@test "run_stage records failure when an upload put fails" {
    stage_upload_with_put
    _bunny_put() { return 1; }
    run_stage upload -- upload_site "${TEST_TMP}/p.hdr" \
        "${TEST_TMP}/s.hdr" host pz sz "${TEST_TMP}/site" c 2>/dev/null
    [[ "$(cat "${STAGE_RUN_DIR}/upload.status")" == "failure" ]]
}

@test "run_stage records success when every upload put succeeds" {
    stage_upload_with_put
    _bunny_put() { return 0; }
    run_stage upload -- upload_site "${TEST_TMP}/p.hdr" \
        "${TEST_TMP}/s.hdr" host pz sz "${TEST_TMP}/site" c 2>/dev/null
    [[ "$(cat "${STAGE_RUN_DIR}/upload.status")" == "success" ]]
}

@test "_bunny_ls passes the stall and connect limits" {
    make_curl_stub
    run _bunny_ls hdr host zone p 7
    [[ "$(cat "${TEST_TMP}/curl.log")" == *"--speed-limit 1 --speed-time 7"* ]]
    [[ "$(cat "${TEST_TMP}/curl.log")" == *"--connect-timeout 7"* ]]
}

@test "_bunny_put passes the stall and connect limits" {
    make_curl_stub
    export STUB_CODE=201
    run _bunny_put hdr host zone rp "${TEST_TMP}/local/a.jpg" 7
    [[ "$status" -eq 0 ]]
    [[ "$(cat "${TEST_TMP}/curl.log")" == *"--speed-limit 1 --speed-time 7"* ]]
    [[ "$(cat "${TEST_TMP}/curl.log")" == *"--connect-timeout 7"* ]]
}

@test "_bunny_rm passes the stall and connect limits" {
    make_curl_stub
    run _bunny_rm hdr host zone rp 7
    [[ "$status" -eq 0 ]]
    [[ "$(cat "${TEST_TMP}/curl.log")" == *"--speed-limit 1 --speed-time 7"* ]]
    [[ "$(cat "${TEST_TMP}/curl.log")" == *"--connect-timeout 7"* ]]
}

@test "_upload_dir forwards the stall to ls, put and rm" {
    _bunny_ls() { echo "ls $5" >>"${TEST_TMP}/fwd"; echo "abc  gone.jpg"; }
    _bunny_put() { echo "put $6" >>"${TEST_TMP}/fwd"; }
    _bunny_rm() { echo "rm $5" >>"${TEST_TMP}/fwd"; }
    run _upload_dir hdr host zone "${TEST_TMP}/local" rdir 0 0 7
    [[ "$status" -eq 0 ]]
    [[ "$(sort -u "${TEST_TMP}/fwd")" == $'ls 7\nput 7\nrm 7' ]]
}

@test "upload_site forwards the stall to every directory" {
    run_upload_site_stubbed
    [[ "$(wc -l <"${TEST_TMP}/calls")" -eq 8 ]]
    [[ "$(grep -vc ' 7$' "${TEST_TMP}/calls")" -eq 0 ]]
}

@test "upload_plan_dir returns 0 for an all-skip directory" {
    mkdir -p "${TEST_TMP}/one"
    echo alpha >"${TEST_TMP}/one/a.jpg"
    printf '%s  a.jpg\n' "$(sum_of "${TEST_TMP}/one/a.jpg")" >"${LISTING}"
    run upload_plan_dir "${TEST_TMP}/one" "${LISTING}" 0 0
    [[ "$status" -eq 0 ]]
    [[ "$output" == "skip a.jpg" ]]
}

progress_scenario() {
    printf '%s  a.jpg\n' "$(sum_of "${TEST_TMP}/local/a.jpg")" >"${LISTING}"
    echo "abc  gone.jpg" >>"${LISTING}"
    _bunny_ls() { cat "${LISTING}"; }
    _bunny_put() { echo "did put ${4##*/}"; }
    _bunny_rm() { echo "did del ${4##*/}"; }
}

@test "_upload_dir prints the plan line before any transfer line" {
    progress_scenario
    run _upload_dir hdr host zone "${TEST_TMP}/local" rdir 0 0 7
    [[ "$status" -eq 0 ]]
    [[ "${lines[0]}" == "upload rdir: put 1, del 1, skip 1" ]]
}

@test "_upload_dir numbers transfers in plan order" {
    progress_scenario
    run _upload_dir hdr host zone "${TEST_TMP}/local" rdir 0 0 7
    [[ "${#lines[@]}" -eq 5 ]]
    [[ "${lines[1]}" == "upload rdir: put 1/2 b.jpg" ]]
    [[ "${lines[2]}" == "did put b.jpg" ]]
    [[ "${lines[3]}" == "upload rdir: del 2/2 gone.jpg" ]]
    [[ "${lines[4]}" == "did del gone.jpg" ]]
}

@test "_upload_dir prints only the plan line when all files skip" {
    progress_scenario
    {
        printf '%s  a.jpg\n' "$(sum_of "${TEST_TMP}/local/a.jpg")"
        printf '%s  b.jpg\n' "$(sum_of "${TEST_TMP}/local/b.jpg")"
    } >"${LISTING}"
    run _upload_dir hdr host zone "${TEST_TMP}/local" rdir 0 0 7
    [[ "$status" -eq 0 ]]
    [[ "$output" == "upload rdir: put 0, del 0, skip 2" ]]
}

@test "_upload_dir prints a filename containing a space whole" {
    mkdir -p "${TEST_TMP}/sp"
    echo x >"${TEST_TMP}/sp/my pic.jpg"
    _bunny_ls() { :; }
    _bunny_put() { :; }
    run _upload_dir hdr host zone "${TEST_TMP}/sp" rdir 0 0 7
    [[ "${lines[1]}" == "upload rdir: put 1/1 my pic.jpg" ]]
}

@test "_upload_dir prints no transfer line after a failed put" {
    _bunny_ls() { :; }
    _bunny_put() { return 1; }
    run _upload_dir hdr host zone "${TEST_TMP}/local" rdir 0 0 7
    [[ "$status" -ne 0 ]]
    [[ "${lines[-1]}" == "upload rdir: put 1/2 a.jpg" ]]
    [[ "$output" != *"2/2"* ]]
}

@test "_upload_dir output never contains the host or zone" {
    progress_scenario
    run _upload_dir hdr secrethost secretzone "${TEST_TMP}/local" rdir 0 0 7
    [[ "$output" == *"upload rdir:"* ]]
    [[ "$output" != *"secrethost"* ]]
    [[ "$output" != *"secretzone"* ]]
}

@test "_upload_dir fails the directory when planning fails" {
    _bunny_ls() { :; }
    upload_plan_dir() { return 1; }
    _bunny_put() { echo called >>"${TEST_TMP}/called"; }
    _bunny_rm() { echo called >>"${TEST_TMP}/called"; }
    run _upload_dir hdr host zone "${TEST_TMP}/local" rdir 0 0 7
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"upload rdir: planning failed"* ]]
    [[ ! -e "${TEST_TMP}/called" ]]
}

@test "_upload_dir removes its temp files on success and failure" {
    mkdir "${TEST_TMP}/tmp"
    progress_scenario
    TMPDIR="${TEST_TMP}/tmp" run _upload_dir hdr host zone \
        "${TEST_TMP}/local" rdir 0 0 7
    [[ "$status" -eq 0 ]]
    [[ -z "$(ls -A "${TEST_TMP}/tmp")" ]]
    _bunny_put() { return 1; }
    TMPDIR="${TEST_TMP}/tmp" run _upload_dir hdr host zone \
        "${TEST_TMP}/local" rdir 0 0 7
    [[ "$status" -ne 0 ]]
    [[ -z "$(ls -A "${TEST_TMP}/tmp")" ]]
}
