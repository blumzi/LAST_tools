#!/bin/bash

module_include lib/message
module_include lib/sections
module_include lib/macmap

declare matlab_mac matlab_file_installation_keys matlab_dir

function mac_to_file_name() {
    declare mac="${1}"

    echo "${mac//:/-}"
}

function matlab_init() {
    sections_register_section "matlab" "Manages the MATLAB installation"

    matlab_mac=$(macmap_get_local_mac)
    matlab_dir="${LAST_TOOL_ROOT}/files/matlab"
    matlab_file_installation_keys="${matlab_dir}/file-installation-keys"
}

function matlab_start() {
    :
}

function matlab_configure() {
    :
}

function matlab_file_installation_keys() {
    echo "${matlab_file_installation_keys}"
}

function matlab_license_file() {
    echo "${matlab_dir}/licenses/$(mac_to_file_name "${matlab_mac}")"
}

function matlab_check() {

    if [ ! "${matlab_mac}" ]; then
        message_failure "Cannot get this machine's MAC address"
    fi

    if [ ! -d "${matlab_dir}" ]; then
        message_failure "Missing directory \"${matlab_dir}\"."
        return # no point in continuing
    fi

    if [ ! -r "${matlab_file_installation_keys}" ]; then
        message_failure "Missing file installation keys file \"${matlab_file_installation_keys}\"."
        return
    fi

    # check that we have a file installation key for this machine
    if grep -wi "^${matlab_mac}" "${matlab_file_installation_keys}" >/dev/null; then
        message_success "We have a file installation key for this machine (mac=${matlab_mac})."
    else
        message_failure "We don't have a file installation key for this machine (mac=${matlab_mac})."
    fi

    # check that we have a license key for this machine
    local license_file

    license_file="$(matlab_license_file)"
    if [ -r "${license_file}" ]; then
        message_success "We have a license key in ${license_file}."
    else
        message_failure "We don't have a license key for this machine (mac=${mac}))'"
    fi
}