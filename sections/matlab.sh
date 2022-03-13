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

eval user_last="ocs"
# shellcheck disable=SC2154
eval user_home=~"${user_last}"
# shellcheck disable=SC2154
eval user_matlab_dir="${user_home}"/matlab

# shellcheck disable=SC2154
export user_startup="${user_matlab_dir}/startup.m"
export last_startup="${user_matlab_dir}/AstroPack/matlab/startup/startup_LAST.m"


function mac_to_file_name() {
    declare mac="${1}"

    echo "${mac//:/-}"
}

function matlab_available_releases() {
    echo "${_matlab_available_releases}"
}

function matlab_init() {
    sections_register_section "matlab" "Manages the MATLAB installation" "user apt last-software"

    matlab_local_mac=$(macmap_get_local_mac)
    
    read -r -a  _matlab_available_releases < <(
        cd "${matlab_releases_dir}" || return;
        find . -maxdepth 1 -name 'R*' -type d | sort | sed -e 's;^..;;'
    )
}

function matlab_enforce() {
    matlab_installation_enforce
    astropack_startup_enforce
    matlab_support_enforce
	matlab_startup_enforce
    matlab_service_enforce
}

#
# The Matlab service is responsible for running the LAST pipeline at system startup
#
function matlab_service_enforce() {
    local system_file="/etc/systemd/system/last-pipeline.service"
    local our_file="/usr/local/share/last-tool/files/last-pipeline.service"

    if macmap_this_is_last0; then
        message_success "No Matlab service on last0"
        return
    fi

    if [ ! -r "${system_file}" ]; then
        ln -sf "${our_file}" "${system_file}"
        message_success "Linked \"${our_file}\" to \"${system_file}\"."
    fi
    
    if ! systemctl is-enabled last-pipeline >& /dev/null; then
        if systemctl enable last-pipeline >& /dev/null; then
            message_success "Enabled the \"last-pipeline\" service"
        else
            message_failure "Failed to enable the \"last-pipeline\" service"
        fi
    else
        message_success "The \"last-pipeline\" service is enabled"
    fi
}

function matlab_license_file() {
    echo "${matlab_releases_dir}/${matlab_selected_release}/licenses/$(mac_to_file_name "${matlab_local_mac}")"
}

function matlab_installed_release() {
    local status str

    which matlab >& /dev/null
    status=${?}
    if (( status == 0 )); then
        str="$( stat --format '%N' "$(which matlab)" | tr -d "'" | (read -r _ _ file; echo "${file}" ) )"
        str="${str%/bin/matlab}"
        str="${str/*\/R/R}"
        echo "${str}"
    fi
}

function matlab_check() {
    local -i ret=0

    matlab_installation_check;  (( ret += $? ))
    astropack_startup_check;    (( ret += $? ))
    matlab_support_check;       (( ret += $? ))
    matlab_startup_check;       (( ret += $? ))
    matlab_service_check;       (( ret += $? ))

    return $(( ret ))
}

function matlab_service_check() {
    local system_file="/etc/systemd/system/last-pipeline.service"
    local our_file="/usr/local/share/last-tool/files/last-pipeline.service"

    if macmap_this_is_last0; then
        message_success "No Matlab service on last0"
        return 0
    fi

    if [ ! -r "${system_file}" ]; then
        message_failure "Our file \"${our_file}\" is not linked to \"${system_file}\"."
        return 1
    fi
    
    if systemctl is-enabled last-pipeline >& /dev/null; then
        message_success "The \"last-pipeline\" service is enabled"
    else
        message_failure "Failed to enable the \"last-pipeline\" service"
        return 1
    fi
}

#
# At this point-in-time we assume there's only ONE installation image on LAST-CONTAINER
# TBD: how to choose between more than one
#
function matlab_installation_enforce() {
    local installed_release
    installed_release=$(matlab_installed_release)

    if [ "${installed_release}" = "${matlab_selected_release}" ]; then
        message_success "Matlab ${matlab_selected_release} is already installed"
        return
    fi

    local installer_input activate_ini
    local keys_file local_mac container installer config_file

    local matlab_top
    matlab_top="/usr/local/MATLAB/${matlab_selected_release}"
	export MATLABROOT=${matlab_top}

    if [ -d "${matlab_top}" ] && [ -x "${MATLABROOT}/bin/matlab" ]; then
        message_success "Matlab ${matlab_selected_release} is already installed"
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

    hash >&/dev/null # to hash teh newly installed Matlab

	local matlabroot license_file
	matlabroot="$( stat --format '%N' "$(which matlab)" | sed -e 's;^.*->.;;' -e "s;';;g" -e "s;/bin/matlab;;" )"
	matlab_release=$(basename "${matlabroot}")
	license_file="$( find "${matlabroot}"/licenses -name "license_$(hostname -s)_*_${matlab_release}.lic" )"

	if [ ! "${license_file}" ]; then

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
		result="$( ${matlab_top}/bin/activate_matlab.sh -propertiesFile "${activate_ini}" )"
		status=${?}
		if [ ${status} -eq 0 ] && [ "${result}" = "Silent activation succeeded." ]; then
			message_success "Successfuly activated Matlab ${matlab_selected_release}"
		else
			message_fatal "Failed to activate Matlab ${matlab_selected_release} (status=${status})"
		fi
	else
		message_success "Matlab ${matlab_release} has already been activated"
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
    chown "${user_last}"."${user_last}" "${bashrc}"
    message_success "Added MATLABROOT=${matlab_top}/bin to ${bashrc}"

    /bin/rm "${activate_ini}" >& /dev/null

    config_file="/etc/matlab/debconf"
    if [ ! -r "${config_file}" ]; then
        local our_config_file

        our_config_file=$(module_locate files/root/${config_file})
        if [ -r "${our_config_file}" ]; then
            install -D "${our_config_file}" "${config_file}"
            message_success "Installed \"${config_file}\"."
        else
            message_failure "Missing \".../files/root/${config_file}\"."
        fi
    else
        message_success "File \"${config_file}\" exists"
    fi

    export MATLABROOT=${matlab_top}/bin
    # if ! dpkg -l matlab-support >&/dev/null; then
    #     message_info "Installing matlab-support"
    #     apt -y install matlab-support
    # fi
}

function matlab_installation_check() {
    local release container
    local -i ret=0 errors=0

    release=$(matlab_installed_release)
    if [ ! "${release}" ]; then
        message_failure "Matlab is not installed"
        (( errors++ ))
    else
        message_success "Matlab is installed (release: ${release})"
    fi

    #
    # It doesn't seem to be installed, can we install it?
    #
    if [ ! "${matlab_local_mac}" ]; then
        message_failure "Cannot get this machine's MAC address"
        return $(( ++errors ))    # no point in continuing
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

function matlab_policy() {
    cat <<- EOF

    The LAST project currently uses Matlab ${matlab_selected_release}.

    - $(ansi_underline "${PROG} check matlab") - Checks that the relevant Matlab release is properly installed.
    - $(ansi_underline "${PROG} enforce matlab") - Installs the relevant Matlab release from a LAST-CONTAINER.

    If Matlab is installed, some of the libraries it fetches must be moved aside.

    The file ${last_startup} should be hard linked to ${user_startup}.

EOF
}

function matlab_is_installed() {
    command -v matlab >&/dev/null
}

function matlab_startup_check() {
    declare -i errors=0

    if macmap_this_is_last0; then
        message_success "No startups on last0"
        return 0
    fi

    if [ ! -r "${last_startup}" ]; then
        message_failure "Missing \"${last_startup}\""
        (( errors++ ))
	else
		message_success "LAST startup \"${last_startup}\" exists"
    fi

    if [ ! -r "${user_startup}" ]; then
        message_failure "Missing \"${user_startup}\""
        (( errors++ ))
	else
		message_success "User startup \"${user_startup}\" exists"
    fi

	if [ -r "${user_startup}" ] && [ -r "${last_startup}" ]; then
		local inode0 inode1
		inode0="$(stat --format "%i" "${user_startup}" 2>/dev/null)"
		inode1="$(stat --format "%i" "${last_startup}" 2>/dev/null)"
		if [ "${inode0}" != "${inode1}" ]; then
			message_failure "\"${user_startup}\" is not hard linked to \"${last_startup}\""
			(( errors++ ))
		else
			message_success "\"${user_startup}\" is hard linked to \"${last_startup}\""
		fi
	fi

    return $(( errors ))
}

function matlab_startup_enforce() {
    declare -i errors=0

    if macmap_this_is_last0; then
        message_success "No startup on last0"
        return 0
    fi

    if [ ! -r "${last_startup}" ]; then
        message_failure "Missing \"${last_startup}\""
        (( errors++ ))
    fi

    ln -f "${last_startup}" "${user_startup}"
    message_success "Linked \"${last_startup}\" to \"${user_startup}\"."

    return $(( errors ))
}

#
# The "matlab-support" package doesn't want to be installed non-ineractively.
# We emulate its behavior, without actually installing it.
#

#
# This function was plagiated from the matlab-support's postinst script
#
function matlab_support_enforce() {
    local matlab_alt matlab_path
    local op="matlab-support"

    for matlab_alt in $(update-alternatives --query matlab | grep 'Alternative:' | cut -d ' ' -f 2,2)
    do
        matlab_path=${matlab_alt%*/bin/matlab}
        # The SONAMEs listed here should be kept in sync with the
        # “Recommends” field of matlab-support binary package
        for f in $matlab_path/sys/os/glnx86/libgcc_s.so.1 \
                    $matlab_path/sys/os/glnx86/libstdc++.so.6 \
                    $matlab_path/sys/os/glnx86/libgfortran.so.5 \
                    $matlab_path/sys/os/glnx86/libquadmath.so.0 \
                    $matlab_path/sys/os/glnxa64/libgcc_s.so.1 \
                    $matlab_path/sys/os/glnxa64/libstdc++.so.6 \
                    $matlab_path/sys/os/glnxa64/libgfortran.so.5 \
                    $matlab_path/sys/os/glnxa64/libquadmath.so.0
        do
            if [ -e "${f}" ]; then
                if mv "${f}" "${f}.bak"; then
                    message_success "${op}: Moved ${f} to ${f}.bak"
                else
                    message_failure "${op}: Failed to move ${f} to ${f}.bak"
                fi
            fi
        done
    done
}

function matlab_support_check() {
    local matlab_alt matlab_path
    local op="matlab-support"
    local -i errors=0

    for matlab_alt in $(update-alternatives --query matlab | grep 'Alternative:' | cut -d ' ' -f 2,2)
    do
        matlab_path=${matlab_alt%*/bin/matlab}
        # The SONAMEs listed here should be kept in sync with the
        # “Recommends” field of matlab-support binary package
        for f in $matlab_path/sys/os/glnx86/libgcc_s.so.1 \
                    $matlab_path/sys/os/glnx86/libstdc++.so.6 \
                    $matlab_path/sys/os/glnx86/libgfortran.so.5 \
                    $matlab_path/sys/os/glnx86/libquadmath.so.0 \
                    $matlab_path/sys/os/glnxa64/libgcc_s.so.1 \
                    $matlab_path/sys/os/glnxa64/libstdc++.so.6 \
                    $matlab_path/sys/os/glnxa64/libgfortran.so.5 \
                    $matlab_path/sys/os/glnxa64/libquadmath.so.0
        do
            if [ -e "${f}" ]; then
                message_failure "${op}: ${f} still exists"
                (( errors++ ))
            elif [ -e "${f}.bak" ]; then
                message_success "${op}: ${f} was moved aside"
            fi
        done
    done
    return $(( errors ))
}


#
# AstroPack
#

function astropack_startup_check() {
    local msg
    local -i ret=0

    msg="The script startup_Installer in \"${user_matlab_dir}/AstroPack/matlab/startup\" was "
    if [ -d "${user_matlab_dir}/data" ]; then
        message_success "${msg} invoked"
    else
        message_failure "${msg} NOT invoked"
        (( ret++ ))
    fi
    return $(( ret ))
}

function astropack_startup_enforce() {
    local script
    script="startup_Installer"

    # shellcheck disable=SC2154
    if [ -d "${user_matlab_dir}/data" ]; then
        message_success "The script ${script} was invoked"
    else
        message_info "Invoking \"${script}\" in \"AstroPack/matlab/startup\" ..."
        su "${user_last}" -c "cd ~/matlab; LANG=en_US matlab -batch \"addpath('/home/ocs/matlab/AstroPack/matlab/startup'); ${script}\" "
        status=${?}
        if (( status == 0 )); then
            message_success "${script} has succeeded"
        else
            message_failure "${script} has failed with status: ${status}"
        fi
    fi
}
