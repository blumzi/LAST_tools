#!/bin/bash

#
# Global environment for the LAST project
#

export PS4='+ [$SHLVL,$BASH_SUBSHELL] [${BASH_SOURCE}:${LINENO}:${FUNCNAME[0]}] '

export http_proxy=http://bcproxy.weizmann.ac.il:8080
export https_proxy=http://bcproxy.weizmann.ac.il:8080

function append_to_bash_include_path() {
    local subpath="${1}"
    local found=false p

    for p in ${LAST_BASH_INCLUDE_PATH//:/ }; do
        if [ "${p}" = "${subpath}" ]; then
            found=true
            break
        fi
    done
    if ! ${found}; then
        export LAST_BASH_INCLUDE_PATH=${LAST_BASH_INCLUDE_PATH}:${subpath}
    fi
}

export LAST_TOOL_ROOT=/usr/local/share/last-tool

append_to_bash_include_path ${LAST_TOOL_ROOT}

for dir in ${LAST_BASH_INCLUDE_PATH//:/ }; do
    file="${dir}/lib/module.sh"
    if [ -r  "${file}" ]; then
        source "${file}" || echo "$(basename "${0}"): Failed to source \"${file}\""
        break
    fi
done
unset dir file

export TMOUT=0