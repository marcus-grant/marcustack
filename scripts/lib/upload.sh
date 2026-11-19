#!/usr/bin/env bash
# Upload the site tree to the two Bunny storage zones over HTTP.
# Zone listing gives per-file SHA256; unchanged files are skipped.

# List one remote directory as "sha256  name" lines, files only.
# Args: hdr_file host zone path stall_seconds.
# Missing dirs list as 200 and empty.
# Exits 1 naming the path and status unless the API answers 200.
_bunny_ls() {
    local hdr="$1" host="$2" zone="$3" path="$4" stall="$5"
    local body code rc=0
    body="$(mktemp)"
    code="$(curl -s -o "${body}" -w '%{http_code}' \
        --speed-limit 1 --speed-time "${stall}" \
        --connect-timeout "${stall}" \
        --header @"${hdr}" \
        "https://${host}/${zone}/${path}/")" || rc=$?
    if [[ "${rc}" -ne 0 || "${code}" != "200" ]]; then
        echo "listing failed (${code:-curl ${rc}}): ${path}" >&2
        rm -f "${body}"
        return 1
    fi
    jq -r '.[] | select(.IsDirectory | not)
             | "\(.Checksum // "-")  \(.ObjectName)"' <"${body}" || rc=$?
    rm -f "${body}"
    if [[ "${rc}" -ne 0 ]]; then
        echo "listing unreadable: ${path}" >&2
        return 1
    fi
}

# PUT one local file to the remote path.
# Args: hdr_file host zone remote_path local_file stall_seconds.
_bunny_put() {
    local hdr="$1" host="$2" zone="$3" rpath="$4" lfile="$5"
    local stall="$6" code
    code="$(curl -s -o /dev/null -w '%{http_code}' -X PUT \
        --speed-limit 1 --speed-time "${stall}" \
        --connect-timeout "${stall}" \
        --header @"${hdr}" --upload-file "${lfile}" \
        "https://${host}/${zone}/${rpath}")"
    if [[ "${code}" != "201" ]]; then
        echo "upload failed (${code}): ${rpath}" >&2
        return 1
    fi
}

# DELETE one remote file.
# Args: hdr_file host zone remote_path stall_seconds.
_bunny_rm() {
    local hdr="$1" host="$2" zone="$3" rpath="$4" stall="$5" code
    code="$(curl -s -o /dev/null -w '%{http_code}' -X DELETE \
        --speed-limit 1 --speed-time "${stall}" \
        --connect-timeout "${stall}" \
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
# Args: hdr host zone ldir rdir skip_existing exclude stall_seconds.
# Exits 1 at the first failed listing, put, or delete.
_upload_dir() {
    local hdr="$1" host="$2" zone="$3" ldir="$4" rdir="$5"
    local skip="$6" exclude="$7" stall="$8"
    local listing action name rc=0
    listing="$(mktemp)"
    if _bunny_ls "${hdr}" "${host}" "${zone}" "${rdir}" \
        "${stall}" >"${listing}"; then
        while read -r action name; do
            case "${action}" in
            put) _bunny_put "${hdr}" "${host}" "${zone}" \
                "${rdir}/${name}" "${ldir}/${name}" "${stall}" ||
                { rc=1; break; } ;;
            del) _bunny_rm "${hdr}" "${host}" "${zone}" \
                "${rdir}/${name}" "${stall}" || { rc=1; break; } ;;
            esac
        done < <(upload_plan_dir "${ldir}" "${listing}" \
            "${skip}" "${exclude}")
    else
        rc=1
    fi
    rm -f "${listing}"
    return "${rc}"
}

# Upload split: originals and display to the pics zone, site-owned
# dirs to the site zone.
# Args: pics_hdr site_hdr host pics_zone site_zone site_dir
# collection stall_seconds.
# Header files are passed to curl by path, never read here.
# Exits 1 at the first failing directory; later ones are not attempted.
upload_site() {
    local pics_hdr="$1" site_hdr="$2" host="$3"
    local pics_zone="$4" site_zone="$5" site="$6" collection="$7"
    local stall="$8"
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
            "${pics}/${kind}" "pics/${collection}/${kind}" 1 1 "${stall}" ||
            return 1
    done
    for kind in preview thumb; do
        _upload_dir "${site_hdr}" "${host}" "${site_zone}" \
            "${pics}/${kind}" "pics/${collection}/${kind}" 0 0 "${stall}" ||
            return 1
    done
    local prefix
    for prefix in gallery galleries; do
        _upload_dir "${site_hdr}" "${host}" "${site_zone}" \
            "${site}/gallery/${collection}" "${prefix}/${collection}" \
            0 0 "${stall}" ||
            return 1
        _upload_dir "${site_hdr}" "${host}" "${site_zone}" \
            "${site}/gallery/${collection}/pic" \
            "${prefix}/${collection}/pic" 0 0 "${stall}" ||
            return 1
    done
}
