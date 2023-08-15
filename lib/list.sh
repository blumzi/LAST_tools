#!/bin/bash

function list_sort() {
    local sort_args=""
    local -a ret

    if [[ ${1} == -* ]]; then
        sort_args="${1}"
        shift
    fi

    local list=("${@}")
    local i

    ret=( $(for i in "${list[@]}"; do echo "${i}"; done | sort ${sort_args}) )
    echo ${ret[@]}
}