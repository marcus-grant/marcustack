#!/usr/bin/env bats

setup() {
    TEST_TMP="$(mktemp -d)"
    export TEST_TMP
    source test/fixture.sh
    source scripts/lib/upload.sh
    fixture_site_tree "${TEST_TMP}/site" "test wedding" 3
    export RCLONE_CONF="${TEST_TMP}/rclone.conf"
    cat >"${RCLONE_CONF}" <<CONF
[testpics]
type = local
[testsite]
type = local
CONF
    PICS_DEST="${TEST_TMP}/remote-pics"
    SITE_DEST="${TEST_TMP}/remote-site"
    export PICS_DEST SITE_DEST
    mkdir -p "${PICS_DEST}" "${SITE_DEST}"
}

teardown() {
    rm -rf "${TEST_TMP}"
}

up() {
    upload_site "${RCLONE_CONF}" \
        "testpics:${PICS_DEST}" "testsite:${SITE_DEST}" \
        "${TEST_TMP}/site" "test wedding"
}

@test "upload fails naming the rclone conf when absent" {
    rm "${RCLONE_CONF}"
    run up
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"rclone.conf"* ]]
}

@test "upload sends original bytes not symlinks, omits manifest" {
    run up
    [[ "$status" -eq 0 ]]
    [[ -f "${PICS_DEST}/pics/test wedding/original/pic1.jpg" ]]
    [[ ! -L "${PICS_DEST}/pics/test wedding/original/pic1.jpg" ]]
    [[ ! -e "${PICS_DEST}/pics/test wedding/original/manifest.json" ]]
}

@test "upload keeps original and display out of the site remote" {
    run up
    [[ "$status" -eq 0 ]]
    [[ -d "${SITE_DEST}/pics/test wedding/preview" ]]
    [[ ! -e "${SITE_DEST}/pics/test wedding/original" ]]
    [[ ! -e "${SITE_DEST}/pics/test wedding/display" ]]
}

@test "upload puts pages and index on the site remote" {
    run up
    [[ "$status" -eq 0 ]]
    [[ -f "${SITE_DEST}/index.html" ]]
    [[ -f "${SITE_DEST}/gallery/test wedding/pic/pic2.html" ]]
}

@test "second upload transfers nothing" {
    run up
    run up
    [[ "$status" -eq 0 ]]
    [[ "$output" != *"Copied"* ]]
}

@test "site sync removes a page deleted locally" {
    run up
    rm "${TEST_TMP}/site/gallery/test wedding/pic/pic3.html"
    run up
    [[ ! -e "${SITE_DEST}/gallery/test wedding/pic/pic3.html" ]]
}

@test "pics copy never removes a remote file" {
    run up
    rm "${TEST_TMP}/site/pics/test wedding/original/pic3.jpg"
    run up
    [[ -f "${PICS_DEST}/pics/test wedding/original/pic3.jpg" ]]
}

@test "site sync leaves files outside its scope alone" {
    echo legacy >"${SITE_DEST}/about.html"
    run up
    [[ "$status" -eq 0 ]]
    [[ -f "${SITE_DEST}/about.html" ]]
}
