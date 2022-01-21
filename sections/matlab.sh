#!/bin/bash

module_include lib/message
module_include lib/sections
module_include lib/macmap
module_include lib/container

export matlab_local_mac
export matlab_selected_release _matlab_installed_release
export -a _matlab_available_releases
export matlab_releases_dir
matlab_releases_dir="$(module_locate files/matlab-releases)"

matlab_selected_release="R2020b"

function mac_to_file_name() {
    declare mac="${1}"

    echo "${mac//:/-}"
}

function matlab_available_releases() {
    echo "${_matlab_available_releases}"
}

function matlab_init() {
    sections_register_section "matlab" "Manages the MATLAB installation" "user"

    matlab_local_mac=$(macmap_get_local_mac)
    
    read -r -a  _matlab_available_releases < <(
        cd "${matlab_releases_dir}" || return;
        find . -maxdepth 1 -name 'R*' -type d | sort | sed -e 's;^..;;'
    )
}

function matlab_enforce() {
    local installed_release
    installed_release=$(matlab_installed_release)

    if [ "${installed_release}" = "${matlab_selected_release}" ]; then
        message_success "Matlab ${matlab_selected_release} is already installed"
        return
    fi

    matlab_install
}

function matlab_license_file() {
    echo "${matlab_releases_dir}/${matlab_selected_release}/licenses/$(mac_to_file_name "${matlab_local_mac}")"
}

function matlab_installed_release() {
    if which matlab >/dev/null; then
        su "${user_last:?}" -c "LANG=en_US; matlab -batch 'fprintf(\"%s\",matlabRelease.Release)'" 2>/dev/null | tr -d '\n'
    fi
}

function matlab_check() {
    local -i errors ret
    local release container

    (( ret = 0 ))
    release=$(matlab_installed_release)
    if [ ! "${release}" ]; then
        message_failure "Matlab is not installed"
    else
        message_success "Matlab is installed (release: ${release})"
    fi

    #
    # It doesn't seem to be installed, can we install it?
    #
    if [ ! "${matlab_local_mac}" ]; then
        message_failure "Cannot get this machine's MAC address"
        return 1    # no point in continuing
    fi

    if [ "${selected_container}" ]; then
        message_info "Checking available Matlab installations (for mac=${matlab_local_mac})"
        local msg keys_file license_file
        container="${selected_container}"
        for deployable_release in $(cd "${container}/matlab" || exit; echo R*); do

            release_info_dir="${matlab_releases_dir}/${deployable_release}"
            (( errors = 0 ))
            if [ "${deployable_release}" = "${matlab_selected_release}" ]; then
                msg="Release $(ansi_bright_green "${deployable_release}"): "
            else
                msg="Release ${deployable_release}"
            fi
            
            # check that we have the installation images for this release
            msg+=", installer "
            if [ -x "${container}/matlab/${deployable_release}/install" ]; then
                msg+="$(ansi_bright_green EXISTS)"
            else
                msg+="$(ansi_bright_red MISSING)"
                (( errors++ ))
            fi

            keys_file="${release_info_dir}/file-installation-keys"
            msg+=", keys-file: "
            if [ -r "${keys_file}" ]; then
                msg+="$(ansi_bright_green EXISTS)"
            else
                msg+="$(ansi_bright_red MISSING)"
                (( errors++ ))
            fi

            # check that we have a file installation key for this machine
            msg+=", key-for-this-machine: "
            if grep -qwi "^${matlab_local_mac}" "${keys_file}" >/dev/null 2>&1; then
                msg+="$(ansi_bright_green EXISTS)"
            else
                msg+="$(ansi_bright_red MISSING)"
                (( errors++ ))
            fi

            # check that we have a license key for this machine
            license_file="${release_info_dir}/licenses/$(mac_to_file_name "${matlab_local_mac}")"

            msg+=", license-for-this-machine: "
            if [ -r "${license_file}" ]; then
                msg+="$(ansi_bright_green EXISTS)"
            else
                msg+="$(ansi_bright_red MISSING)"
                (( errors++ ))
            fi

            if (( errors == 0 )); then
                message_success "${msg} (==> installable)"
            else
                (( ret++ ))
                message_failure "${msg} (==> not installable)"
            fi
        done
    else
        message_info "No selected container, cannot check Matlab installation availability"
    fi

    return $(( ret ))
}

#
# At this point-in-time we assume there's only ONE installation image on LAST-CONTAINER
# TBD: how to choose between more than one
#
function matlab_install() {
    local installer_input activate_ini
    local keys_file local_mac container installer

    local matlab_top
    matlab_top="/usr/local/MATLAB/${matlab_selected_release}"
	export MATLABROOT=${matlab_top}

    if [ -d "${matlab_top}" ] && [ -x "${MATLABROOT}/bin/matlab" ]; then
        message_success "Matlab ${matlab_selected_release} seems to be already installed"
    else
        local_mac=$( macmap_get_local_mac )

        container=${selected_container}
        installer=${container}/matlab/${matlab_selected_release}/install
        if [ ! -x "${installer}" ]; then
            message_fatal "Missing installer for Matlab ${matlab_selected_release} in ${installer}, exiting"
        fi

        keys_file="${matlab_releases_dir}/${matlab_selected_release}/file-installation-keys"

        if [ ! -r "${keys_file}" ]; then
            message_fatal "Cannot read keys file \"${keys_file}\", exiting"
        fi

        local -a keys_info
        read -r -a keys_info <<< "$(grep -i "^${local_mac}" "${keys_file}")"
        if [ ${#keys_info[*]} -ne 2 ]; then
            message_fatal "Cannot get installation key for mac=${local_mac} from \"${keys_file}\", exiting"
        fi

        local installation_key
        installation_key="${keys_info[1]}"

        # Access the matlab installer

        mkdir -p "${matlab_top}"
        #
        # Prepare responses for the silent Matlab installation
        #
        installer_input=$( mktemp ) 
        cat <<- EOF > "${installer_input}"

        ## SPECIFY INSTALLATION FOLDER
        destinationFolder=${matlab_top}

        ## SPECIFY FILE INSTALLATION KEY
        fileInstallationKey=${installation_key}

        ## ACCEPT LICENSE AGREEMENT 
        agreeToLicense=yes

        ## SPECIFY OUTPUT LOG
        outputFile=/tmp/matlab${matlab_selected_release}-install.log

        ## SPECIFY INSTALLER MODE
        mode=silent
EOF
        pushd "$(dirname "${installer}")" >/dev/null || true
        message_info "Silently installing Matlab ${matlab_selected_release} from \"$(dirname "${installer}")\" (~10 minutes, get some coffee :)"
        ./install -inputFile "${installer_input}"
        local -i status=${?}
        if [ ${status} -eq 0 ]; then
            message_success "Installed Matlab ${matlab_selected_release}"
        else
            message_fatal "Failed to install Matlab ${matlab_selected_release} (status=${status})"
        fi

        # Then we will need to replce lmgrimpl module in the matlab installation directory for activation
        sudo cp -r ${matlab_top}/bin/* ${MATLABROOT}/bin 2>/dev/null
		/bin/rm -f "${installer_input}"
    fi

    #
    # Prepare activation responses for the Matlab installation
    #
    activate_ini=$( mktemp )
    cat <<- EOF > "${activate_ini}"
    # SPECIFY ACTIVATION MODE
    isSilent=true
    # SPECIFY ACTIVATION TYPE (Required)
    activateCommand=activateOffline
    # SPECIFY LICENSE FILE LOCATION (Required if activateCommand=activateOffline)
    licenseFile=$(matlab_license_file)
EOF
    message_info "Silently activating Matlab ${matlab_selected_release} (~1 minute) ..."
    # Activate the Matlab by running, it will says 'success'
    declare result
    result="$( ${matlab_top}/bin/activate_matlab.sh -propertiesFile ${activate_ini} )"
    status=${?}
    if [ ${status} -eq 0 ] && [ "${result}" = "Silent activation succeeded." ]; then
        message_success "Successfuly activated Matlab ${matlab_selected_release}"
    else
        message_fatal "Failed to activate Matlab ${matlab_selected_release} (status=${status})"
    fi

    # Finally, link the matlab to /usr/local/bin, 
    ln -sf ${matlab_top}/bin/matlab /usr/local/bin/matlab

    local tmp
    tmp=$( mktemp )
    # shellcheck disable=SC2154
    bashrc="${user_home}/.bashrc"
    {
        grep -v "MATLABROOT" "${bashrc}"
        echo "export MATLABROOT=${matlab_top}/bin"
        echo "export PATH=\${PATH}:MATLABROOT/bin"
    } > "${tmp}"
    mv "${tmp}" "${bashrc}"
    message_success "Added MATLABROOT=${matlab_top}/bin to ${bashrc}"

    /bin/rm "${activate_ini}"
}

function matlab_policy() {
    cat <<- EOF

    The LAST project currently uses Matlab ${matlab_selected_release}.

    - $(ansi_underline "${PROG} check matlab") - Checks that the relevant Matlab release is properly installed.
    - $(ansi_underline "${PROG} enforce matlab") - Installs the relevant MAtlab release from a LAST-CONTAINER.

EOF
}
