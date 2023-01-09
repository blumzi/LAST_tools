#!/bin/bash

module_include lib/wget

function http_get() {
    local url="${1}"
    local tmp
    local -i ret

    tmp=$(mktemp "/tmp/${PROG}.XXXXXX")
    http_proxy= wget ${WGET_OPTIONS} -O - "${url}" > "${tmp}"
    ret=${?}
    if (( ret != 0 )); then
        echo "${FUNCNAME}: \"${url}\" wget failed with rc=${ret}" >&2
    elif (( ret == 0 )) && [ -s "${tmp}" ]; then
	    cat "${tmp}"
    fi
    /bin/rm "${tmp}"
    return ${ret}
}

#
# TBD: better args parsing to support --body-data, --body-file, etc.
#
function http_put() {
    local url="${1}"
    local data="${2}"
    local tmp
    local -i ret

    tmp=$(mktemp "/tmp/${PROG}.XXXXXX")
    http_proxy= wget ${WGET_OPTIONS} --method=PUT --body-data="${data}" -O - "${url}" > "${tmp}"
    ret=${?}
    if (( ret != 0 )); then
        echo "${FUNCNAME}: \"${url}\" wget failed with rc=${ret}" >&2
    elif (( ret == 0 )) && [ -s "${tmp}" ]; then
	    cat "${tmp}"
    fi
    /bin/rm "${tmp}"
    return ${ret}
}
