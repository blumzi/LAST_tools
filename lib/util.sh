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
	case "${1,,}" in
		on|true|yes|aye|yep)
			return 0
			;;
		off|false|no|nope|nay)
			return 1
			;;
	esac
}

#
# Desktop shortcuts
#
function util_enforce_shortcut() {
    local override=false make_favorite=false

    if [ "${1}" = "-O" ] || [ "${1}" = "--override" ]; then
        override=true
        shift 1
    fi
    if [ "${1}" = "-f" ] || [ "${1}" = "--favorite" ]; then
        make_favorite=true
        shift 1
    fi

    local shortcut="${1}"
    if [ ! "${shortcut}" ]; then
        message_warning "${FUNCNAME[0]}: Missing shortcut name argument"
        return
    fi

    local global_shortcut="/usr/share/applications/${shortcut}.desktop"
    local our_shortcut
    our_shortcut="$(module_locate files/root/"${global_shortcut}")"

    if [ -e "${our_shortcut}" ]; then
        if [ ! -e "${global_shortcut}" ] || ${override}; then
            cp "${our_shortcut}" "${global_shortcut}"
            chmod +x "${global_shortcut}"
            message_success "shortcut: Copied \"${our_shortcut}\" to \"${global_shortcut}\"."
        fi
    fi

    if ${make_favorite}; then
        local favorites
		local user_last="ocs"	# Bogus, should be a global definition, TBD

        favorites="$( su - "${user_last}" -c "dconf read /org/gnome/shell/favorite-apps" )"
        if [[ "${favorites}" != *${shortcut}.desktop* ]]; then
            favorites="${favorites%]}, '${shortcut}.desktop']"
            su "${user_last}" -c "dconf write /org/gnome/shell/favorite-apps \"${favorites}\""
            message_success "shortcut: added ${shortcut} to favorites"
        else
            message_success "shortcut: ${shortcut} is already a favorite"
        fi
    fi
}

function util_check_shortcut() {
    local should_be_favorite=false
    if [ "${1}" = "--favorite" ] || [ "${1}" = "-f" ]; then
        should_be_favorite=true
        shift 1
    fi

    local shortcut="${1}"
    local global_shortcut="/usr/share/applications/${shortcut}.desktop"
    local ret=0

    if [ ! "${shortcut}" ]; then
        message_failure "${FUNCNAME[0]}: Missing shortcut name argument"
        return 1
    fi

    if [ ! -e "${global_shortcut}" ]; then
        message_failure "${FUNCNAME[0]}: Missing \"${global_shortcut}\""
        return 1
    fi

    if [ ! -x "${global_shortcut}" ]; then
        message_failure "${FUNCNAME[0]}: \"${global_shortcut}\" is NOT executable"
        return 1
    fi

    if ${should_be_favorite}; then
        local favorites
		local user_last="ocs"	# Bogus, should be a global definition, TBD
		
        favorites="$( su - "${user_last}" -c "dconf read /org/gnome/shell/favorite-apps" )"
        if [[ "${favorites}" == *${shortcut}.desktop* ]]; then
            message_success "${FUNCNAME[0]}: ${shortcut} is a favorite"
        else
            message_failure "${FUNCNAME[0]}: ${shortcut} is NOT a favorite"
            (( ret++ ))
        fi
    fi

    return $(( ret ))
}