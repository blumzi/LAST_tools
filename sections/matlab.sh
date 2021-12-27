#!/bin/bash

module_include lib/message
module_include lib/sections
module_include lib/macmap

declare matlab_mac

declare matlab_selected_release matlab_installed_release
declare -a matlab_available_releases
declare matlab_releases_dir="${LAST_TOOL_ROOT}/files/matlab/releases"

function mac_to_file_name() {
    declare mac="${1}"

    echo "${mac//:/-}"
}

function matlab_init() {
    sections_register_section "matlab" "Manages the MATLAB installation"

    matlab_mac=$(macmap_get_local_mac)
    readarray matlab_available_releases < <(
        cd "${matlab_releases_dir}" || return;
        find . -maxdepth 1 -name 'R*' -type d | sort | sed -e 's;^..;;'
    )

    if command -v matlab >/dev/null; then
        matlab_installed_release="$( matlab -r "matlabRelease.Release")"
    else
        matlab_installed_release="None"
    fi
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
    local -i errors ret
    local release

    #
    # First check if Matlab is installed and works.
    #

    (( ret = 0 ))
    if command -v matlab >/dev/null; then
        release="$( matlab -r "matlabRelease.Release" )"
        message_success "Matlab is installed (release: ${release})"
        return ${ret}
    fi

    message_info "Matlab is not installed, checking available releases"

    #
    # It doesn't seem to be installed, can we install it?
    #
    if [ ! "${matlab_mac}" ]; then
        message_failure "Cannot get this machine's MAC address"
        return 1    # no point in continuing
    fi

    local msg keys_file license_file images_dir release_dir
    for release in "${matlab_available_releases[@]}"; do

        release_dir="${matlab_releases_dir}/${release}"
        (( errors = 0 ))
        msg="${release}: "
        
        # check that we have the installation images for this release
        images_dir="${release_dir}/images"
        msg+=" images: TBD"

        keys_file="${release_dir}/file-installation-keys"
        msg+=", keys-file: "
        if [ -r "${keys_file}" ]; then
            msg+="OK"
        else
            msg+="MISSING"
            (( errors++ ))
        fi

        # check that we have a file installation key for this machine
        msg+=", key-for-${matlab_mac}: "
        if grep -wi "^${matlab_mac}" "${keys_file}" >/dev/null; then
            msg+="OK"
        else
            msg+="MISSING"
            (( errors++ ))
        fi

        # check that we have a license key for this machine
        license_file="${release_dir}/licenses/$(mac_to_file_name "${matlab_mac}")"

        msg+=", license-for-${matlab_mac}: "
        if [ -r "${license_file}" ]; then
            msg+="OK"
        else
            msg+="MISSING"
            (( errors++ ))
        fi

        if [ $(( errors )) -eq 0 ]; then
            message_success "${msg}"
        else
            (( ret++ ))
            message_failure "${msg}"
        fi
    done

    return $(( ret ))
}