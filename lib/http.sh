#!/bin/bash

function http_get() {
    local url="${1}"
    local tmp
    local -i ret

    tmp=$(mktemp "/tmp/${PROG}.XXXXXX")
    http_proxy= timeout 2 wget --quiet -O - "${url}" > "${tmp}"
    ret=${?}
    if (( ret == 0 )) && [ -s "${tmp}" ]; then
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
    http_proxy= timeout 2 wget --quiet --method=PUT --body-data="${data}" -O - "${url}" > "${tmp}"
    ret=${?}
    if (( ret == 0 )) && [ -s "${tmp}" ]; then
	    cat "${tmp}"
    fi
    /bin/rm "${tmp}"
    return ${ret}
}
