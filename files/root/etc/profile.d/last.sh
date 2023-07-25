#!/bin/bash

#
# Global environment for the LAST project
#

# set the debug-mode prompt (set -x)
export PS4='+ $(d=$(date --rfc-3339=ns); d=${d/ /@}; echo ${d:0:23}) [$SHLVL,$BASH_SUBSHELL] [${BASH_SOURCE}:${LINENO}:${FUNCNAME[0]:-main}] '

function append_to_module_include_path() {
    local subpath="${1}"
    local p

    for p in ${LAST_MODULE_INCLUDE_PATH//:/ }; do
        if [ "${p}" = "${subpath}" ]; then
            return
        fi
    done
    
    LAST_MODULE_INCLUDE_PATH+=":${subpath}"
    LAST_MODULE_INCLUDE_PATH="${LAST_MODULE_INCLUDE_PATH##:}"
    export LAST_MODULE_INCLUDE_PATH
}

export LAST_TOOL_ROOT=/usr/local/share/last-tool

append_to_module_include_path ${LAST_TOOL_ROOT}

for dir in ${LAST_MODULE_INCLUDE_PATH//:/ }; do
    file="${dir}/lib/module.sh"
    if [ -r  "${file}" ]; then
        # shellcheck source=/dev/null
        source "${file}" || echo "$(basename "${0}"): Failed to source \"${file}\""
        break
    fi
done
unset dir file

module_include lib/util
util_test_and_set_http_proxy

export TMOUT=0