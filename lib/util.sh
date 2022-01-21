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
		-e '/^$/d' \
		-e 's;^[[:space:]]*;;' \
		-e 's;\n; ;' < "${file}"
}

#
# transform a string into a valid bash variable name
#
function util_bashify() {
	local string="${1}"

	echo "${string}" | tr '-' '_'
}