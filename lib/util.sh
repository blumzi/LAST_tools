#!/bin/bash

#
# Utility functions
#

#
# remove comments and empty lines from a file
#
function util_uncomment() {
    local file="${1}"

    sed -e 's;[[:space:]]*#.*;;' \
		-e '/^$/d' \
		-e 's;^[[:space:]]*;;' \
		-e 's;\n; ;' < "${file}"
}
