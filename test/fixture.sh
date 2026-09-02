#!/usr/bin/env bash
# Generates a minimal site tree for verify and upload tests.
# Usage: fixture_site_tree DIR COLLECTION COUNT
# Layout mirrors the real producers: normpic symlink trees with
# colocated manifests at pics/COLLECTION/original and display,
# galleria renditions at preview and thumb, pages under
# gallery/COLLECTION with index.html a copy of page1.html.

# Write one fake manifest with COUNT entries into DIR.
_fixture_manifest() {
    local dir="$1" collection="$2" count="$3" i entries=""
    for ((i = 1; i <= count; i++)); do
        [[ -n "${entries}" ]] && entries+=","
        entries+="{\"relative_path\": \"pic${i}.jpg\"}"
    done
    printf '{"collection_name": "%s", "pic": [%s]}\n' \
        "${collection}" "${entries}" >"${dir}/manifest.json"
}

# Build the full fixture tree rooted at DIR.
fixture_site_tree() {
    local dir="$1" collection="$2" count="$3" i
    local pics="${dir}/pics/${collection}"
    local pages="${dir}/gallery/${collection}"
    mkdir -p "${pics}/original" "${pics}/display" \
        "${pics}/preview" "${pics}/thumb" \
        "${pages}/pic" "${dir}/src"
    for ((i = 1; i <= count; i++)); do
        echo "src${i}" >"${dir}/src/pic${i}.jpg"
        ln -s "${dir}/src/pic${i}.jpg" "${pics}/original/pic${i}.jpg"
        ln -s "${dir}/src/pic${i}.jpg" "${pics}/display/pic${i}.jpg"
        echo "prev${i}" >"${pics}/preview/pic${i}.jpg"
        echo "thumb${i}" >"${pics}/thumb/pic${i}.jpg"
        echo "<html>pic${i}</html>" >"${pages}/pic/pic${i}.html"
    done
    _fixture_manifest "${pics}/original" "${collection}" "${count}"
    _fixture_manifest "${pics}/display" "${collection}" "${count}"
    echo "<html>page1</html>" >"${pages}/page1.html"
    cp "${pages}/page1.html" "${dir}/index.html"
}
