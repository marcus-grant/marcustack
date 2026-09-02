#!/usr/bin/env bash
# Upload the site tree to the two Bunny storage zones over HTTP.
# Zone listing gives per-file SHA256; unchanged files are skipped.

# List one remote directory as "sha256  name" lines, files only.
# Args: hdr_file host zone path. Missing dirs list as empty.
_bunny_ls() {
    local hdr="$1" host="$2" zone="$3" path="$4"
    curl -sf --header @"${hdr}" \
        "https://${host}/${zone}/${path}/" |
        jq -r '.[] | select(.IsDirectory | not)
                 | "\(.Checksum // "-")  \(.ObjectName)"' ||
        true
}

# PUT one local file to the remote path.
# Args: hdr_file host zone remote_path local_file.
_bunny_put() {
    local hdr="$1" host="$2" zone="$3" rpath="$4" lfile="$5" code
    code="$(curl -s -o /dev/null -w '%{http_code}' -X PUT \
        --header @"${hdr}" --upload-file "${lfile}" \
        "https://${host}/${zone}/${rpath}")"
    if [[ "${code}" != "201" ]]; then
        echo "upload failed (${code}): ${rpath}" >&2
        return 1
    fi
}

# DELETE one remote file.
# Args: hdr_file host zone remote_path.
_bunny_rm() {
    local hdr="$1" host="$2" zone="$3" rpath="$4" code
    code="$(curl -s -o /dev/null -w '%{http_code}' -X DELETE \
        --header @"${hdr}" \
        "https://${host}/${zone}/${rpath}")"
    if [[ "${code}" != "200" ]]; then
        echo "delete failed (${code}): ${rpath}" >&2
        return 1
    fi
}

# Plan one directory against its remote listing.
# Args: local_dir remote_listing_file skip_existing manifest_excluded.
# Emits "put NAME", "del NAME", or "skip NAME" per file decision.
# Pure: reads the filesystem and the listing, touches no network.
upload_plan_dir() {
    local ldir="$1" listing="$2" skip_existing="$3" exclude="$4"
    local name lsum rsum
    declare -A remote local_names
    while read -r rsum name; do
        [[ -n "${name}" ]] && remote["${name}"]="${rsum}"
    done <"${listing}"
    for f in "${ldir}"/*; do
        [[ -f "${f}" || -L "${f}" ]] || continue
        name="$(basename "${f}")"
        local_names["${name}"]=1
        if [[ "${exclude}" == "1" && "${name}" == "manifest.json" ]]; then
            continue
        fi
        if [[ -z "${remote[${name}]:-}" ]]; then
            echo "put ${name}"
        elif [[ "${skip_existing}" == "1" ]]; then
            echo "skip ${name}"
        else
            lsum="$(sha256sum <"${f}" | cut -d' ' -f1)"
            rsum="$(tr '[:upper:]' '[:lower:]' \
                <<<"${remote[${name}]}")"
            if [[ "${lsum}" == "${rsum}" ]]; then
                echo "skip ${name}"
            else
                echo "put ${name}"
            fi
        fi
    done
    if [[ "${skip_existing}" != "1" ]]; then
        for name in "${!remote[@]}"; do
            [[ -z "${local_names[${name}]:-}" ]] &&
                echo "del ${name}"
        done
    fi
}

# Execute a plan for one directory pair.
# Args: hdr host zone ldir rdir skip_existing exclude.
_upload_dir() {
    local hdr="$1" host="$2" zone="$3" ldir="$4" rdir="$5"
    local skip="$6" exclude="$7" listing action name
    listing="$(mktemp)"
    _bunny_ls "${hdr}" "${host}" "${zone}" "${rdir}" >"${listing}"
    while read -r action name; do
        case "${action}" in
        put) _bunny_put "${hdr}" "${host}" "${zone}" \
            "${rdir}/${name}" "${ldir}/${name}" ;;
        del) _bunny_rm "${hdr}" "${host}" "${zone}" \
            "${rdir}/${name}" ;;
        esac
    done < <(upload_plan_dir "${ldir}" "${listing}" \
        "${skip}" "${exclude}")
    rm -f "${listing}"
}

# Upload split: originals and display to the pics zone, site-owned
# dirs to the site zone.
# Args: pics_hdr site_hdr host pics_zone site_zone site_dir
# collection.
# Header files are passed to curl by path, never read here.
upload_site() {
    local pics_hdr="$1" site_hdr="$2" host="$3"
    local pics_zone="$4" site_zone="$5" site="$6" collection="$7"
    local pics="${site}/pics/${collection}"
    local hdr
    for hdr in "${pics_hdr}" "${site_hdr}"; do
        if [[ ! -r "${hdr}" ]]; then
            echo "header file not readable: ${hdr}" >&2
            return 1
        fi
    done
    local kind
    for kind in original display; do
        _upload_dir "${pics_hdr}" "${host}" "${pics_zone}" \
            "${pics}/${kind}" "pics/${collection}/${kind}" 1 1
    done
    for kind in preview thumb; do
        _upload_dir "${site_hdr}" "${host}" "${site_zone}" \
            "${pics}/${kind}" "pics/${collection}/${kind}" 0 0
    done
    _upload_dir "${site_hdr}" "${host}" "${site_zone}" \
        "${site}/gallery/${collection}" "gallery/${collection}" 0 0
    _upload_dir "${site_hdr}" "${host}" "${site_zone}" \
        "${site}/gallery/${collection}/pic" \
        "gallery/${collection}/pic" 0 0
}
