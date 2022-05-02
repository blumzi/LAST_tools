#!/bin/bash

#
# Utility functions
#

#
# remove comments and empty (or containing only spaces) lines from a file
#
function util_uncomment() {
    local file="${1}"

    sed -e 's;[[:space:]]*#.*;;' \
		-e 's;^[[:space:]]*;;' \
		-e 's;\r;;' \
		-e '/^$/d' \
		-e 's;\n; ;' < "${file}"
}

#
# transform a string into a valid bash variable name
#
function util_bashify() {
	local string="${1}"

	echo "${string}" | tr '-' '_'
}

#
# Sets the environment variables http_proxy and https_proxy, iff
#  the proxy server bcproxy.weizmann.ac.il replies to ping.
function util_test_and_set_http_proxy() {
	if http_proxy=http://bcproxy.weizmann.ac.il:8080 timeout 2 wget --quiet -O - http://euler1.weizmann.ac.il/catsHTM 2>/dev/null | grep --quiet 'The HDF5/HTM large catalog format'; then
		export  http_proxy="http://bcproxy.weizmann.ac.il:8080"
		export https_proxy="http://bcproxy.weizmann.ac.il:8080"
	fi
}

#
# Converts boolean keywords into status codes
#
function util_convert_to_boolean() {
	case "${1}" in
		[Oo]n|[Tt]rue|[Yy]es)
			return 0
			;;
		[Oo]ff|[Ff]alse|[Nn]o)
			return 1
			;;
	esac
}
