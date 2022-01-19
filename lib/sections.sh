#!/bin/bash

declare -a _registered_section_names
declare -a _registered_section_descriptions
export -A _required_sections=()

#
# Register a section, with optional requirements
#
function sections_register_section() {
    local name="${1}"
    local description="${2}"
    local requires="${3}"

    for s in "${_registered_section_names[@]}"; do
        if [ "${s}" = "${name}" ]; then
            return
        fi
    done

    _registered_section_names+=( "${name}" )
    _registered_section_descriptions+=( "${description}" )
    if [ "${requires}" ]; then
        _required_sections[${name}]="${requires}"
    fi
#	{
#		local str
#		str="register: section ${name} "
#		for key in ${!_required_sections[*]}; do
#			str+="_required_sections[${key}]=\"${_required_sections[${key}]}\" "
#		done
#		echo "${str}"
#	} >&2
}

function sections_section_requires() {
    local section="${1}"

    echo "${_required_sections[${section}]}"
}

function sections_registered_sections() {
    echo "${_registered_section_names[@]}"
}

#
# Produce a topologically sorted list of the requested sections
#  including their dependencies
#
function sections_ordered_sections() {
    local -a requested_sections=( "${1}" )
    local -a ordered_sections needed

    # build a topologically sorted array of the needed section
    ordered_sections=(
        $(
            for section in ${requested_sections[*]}; do
                if [ "${_required_sections[${section}]}" ]; then
                    needed=( ${_required_sections["${section}"]} )
                    for need in "${needed[@]}"; do
                        echo "${need} ${section}"
                    done
                fi
                echo "top ${section}"
            done | tsort | grep -vw top
        )
    )
    echo "${ordered_sections[@]}"
}

function sections_section_description() {
    local name="${1}"

    for (( i = 0; i < ${#_registered_section_names[@]}; i++)); do
        if [ "${_registered_section_names[i]}" = "${name}" ]; then
            echo "${_registered_section_descriptions[$i]}"
            return
        fi
    done
}

function sections_section_has_method() {
    local section="${1}"
    local method="${2}"

    if typeset -F "${section}_${method}" >/dev/null; then
        return 0
    else
        return 1
    fi
}
