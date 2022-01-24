#!/bin/bash

#
# PATH-like variables handling functions
#

export path_separator=':' 

function path_has_member() {
    local path="${1}"
    local member="${2}"
    local -a array
    
    read -r -a array < <(echo "${path//:/ }")
    for m in "${array[@]}"; do
        if [ "${m}" = "${member}" ]; then
            return 0
        fi
    done
    return 1
}

function path_append() {
    local path="${1}"
    local member="${2}"

    if ! path_has_member "${path}" "${member}"; then
        if [ "${path}" ]; then
            echo "${path}${path_separator}${member}"
        else
            echo "${member}"
        fi
    else
        echo "${path}"
    fi
}

function path_prepend() {
    local path="${1}"
    local member="${2}"

    if ! path_has_member "${path}" "${member}"; then
        if [ "${path}" ]; then
            echo "${member}${path_separator}${path}"
        else
            echo "${member}"
        fi
    else
        echo "${path}"
    fi
}

function path_to_list() {
    local path="${1}"

    echo "${path//${path_separator}/ }"
}