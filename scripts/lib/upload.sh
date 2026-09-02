#!/usr/bin/env bash
# Upload the site tree to the two storage zone remotes.

# Upload split: originals and display to the pics remote, everything
# else to the site remote.
# Args: rclone_conf pics_remote site_remote site_dir collection.
# The conf path is passed to rclone, never read here.
# Exits non-zero naming the first failure.
upload_site() {
    local conf="$1" pics_remote="$2" site_remote="$3"
    local site="$4" collection="$5"
    local pics="${site}/pics/${collection}"
    if ! command -v rclone >/dev/null; then
        echo "rclone not found" >&2
        return 1
    fi
    if [[ ! -r "${conf}" ]]; then
        echo "rclone conf not readable: ${conf}" >&2
        return 1
    fi
    local kind
    for kind in original display; do
        rclone --config "${conf}" copy -v \
            --copy-links --ignore-existing \
            --exclude 'manifest.json' \
            "${pics}/${kind}" \
            "${pics_remote}/pics/${collection}/${kind}"
    done
    for kind in preview thumb; do
        rclone --config "${conf}" sync -v \
            "${pics}/${kind}" \
            "${site_remote}/pics/${collection}/${kind}"
    done
    rclone --config "${conf}" sync -v \
        "${site}/gallery/${collection}" \
        "${site_remote}/gallery/${collection}"
    rclone --config "${conf}" copyto -v \
        "${site}/index.html" "${site_remote}/index.html"
}
