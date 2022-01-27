#!/bin/bash

export -A _sections_registered=()
export -A _sections_descriptions=()
export -A _sections_required=()
export -A _sections_flags=()

#
# Register a section, with description, requirements and flags
#
function sections_register_section() {
    local name="${1}"
    local description="${2}"
    local requires="${3}"
    local flags="${4}"

    if [ "${_sections_registered[${name}]}" ]; then # already registered
        return
    fi

      _sections_registered[${name}]="${name}"
    _sections_descriptions[${name}]="${description}"
        _sections_required[${name}]="${requires}"
           _sections_flags[${name}]="${flags}"
}

function sections_section_requires() {
    local section="${1}"

    echo "${_sections_required[${section}]}"
}

function sections_registered_sections() {
    echo "${!_sections_registered[@]}"
}

#
# Produce a topologically sorted list of the requested sections
#  including their dependencies
#
function sections_ordered_sections() {
    local -a requested_sections ordered_sections needed
    local section need

    read -r -a requested_sections <<< "${1}"

    # build a topologically sorted array of the needed section
    mapfile -t ordered_sections < <( 
        for section in "${requested_sections[@]}"; do
            if [ "${_sections_required[${section}]}" ]; then
                read -r -a needed <<< "${_sections_required["${section}"]}"
                for need in "${needed[@]}"; do
                    echo "${need} ${section}"
                done
            fi
            echo "top ${section}"
        done | tsort | grep -vw top
    )
    echo "${ordered_sections[@]}"
}

function sections_section_description() {
    local section="${1}"

    echo "${_sections_descriptions[${section}]}"
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

function sections_section_flags() {
    local section="${1}"

    echo "${_sections_flags[${section}]}"
}