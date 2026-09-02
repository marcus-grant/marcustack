#!/usr/bin/env bats

setup() {
    TEST_TMP="$(mktemp -d)"
    export TEST_TMP
    source test/fixture.sh
    source scripts/lib/verify.sh
    fixture_site_tree "${TEST_TMP}/site" "test wedding" 3
}

teardown() {
    rm -rf "${TEST_TMP}"
}

@test "verify_site passes on a complete tree" {
    run verify_site "${TEST_TMP}/site" "test wedding" 3
    [[ "$status" -eq 0 ]]
}

@test "verify_site fails naming a missing rendition dir" {
    rm -rf "${TEST_TMP}/site/pics/test wedding/display"
    run verify_site "${TEST_TMP}/site" "test wedding" 3
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"display"* ]]
}

@test "verify_site fails on a per-photo page count mismatch" {
    rm "${TEST_TMP}/site/gallery/test wedding/pic/pic2.html"
    run verify_site "${TEST_TMP}/site" "test wedding" 3
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"2"* ]]
}

@test "verify_site fails when index differs from page1" {
    echo "<html>drift</html>" >"${TEST_TMP}/site/index.html"
    run verify_site "${TEST_TMP}/site" "test wedding" 3
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"index.html"* ]]
}

@test "verify_site fails on a broken symlink under pics" {
    rm "${TEST_TMP}/site/src/pic1.jpg"
    run verify_site "${TEST_TMP}/site" "test wedding" 3
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"broken"* ]]
}
