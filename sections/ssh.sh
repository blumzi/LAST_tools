#!/bin/bash

module_include lib/message
module_include lib/sections
module_include lib/user

export ssh_config_file=/etc/ssh/ssh_config

sections_register_section "ssh" "Configures ssh client" "user hostname ubuntu-packages"

function ssh_enforce() {
    
    if [ "$(grep -scE '^[[:space:]]*ServerAlive' "${ssh_config_file}")" != 2 ]; then
        local tmp
        tmp=$(mktemp)

        {
            grep -Ev '^[[:space:]]*ServerAlive(CountMax|Interval)' "${ssh_config_file}"
            echo '    ServerAliveCountMax 4'
            echo '    ServerAliveInterval 15'
        } > "${tmp}"
        mv "${tmp}" ${ssh_config_file}
        chmod 644 ${ssh_config_file}
		message_success "Added ServerAlive settings to config file ${ssh_config_file}"
	fi

    ssh_enforce_keys
}

function ssh_check() {
    if [ "$(grep -scE '^[[:space:]]*ServerAlive' "${ssh_config_file}")" = 2 ]; then
        message_success "Ssh config file (${ssh_config_file}) has the ServerAlive settings"
    else
        message_failure "Ssh config file (${ssh_config_file}) does not have the ServerAlive settings"
    fi

    ssh_check_keys
}

function ssh_policy() {
    # shellcheck disable=SC2154
    cat <<- EOF

    - The ssh configuration file (${ssh_config_file}) should contain settings for:
      - ServerAliveCountMax  4
      - ServerAliveInterval 15

      This tells the ssh client to try every 15 seconds for at most 4 times (total of 1 minute)
       to get proof of life from the server, before closing the connection.

    - Ssh keys (private and public) for the user "${user_name}" are installed from the LAST-CONTAINER
    - The ${user_name} user must be able to ssh without a password

EOF
}

# shellcheck disable=SC2154
export _ssh_user_dir="${user_home}/.ssh"

#
# ssh keys
#
function ssh_enforce_keys() {
    if [ ! -d "${_ssh_user_dir}" ]; then
        mkdir -p "${_ssh_user_dir}"
        # shellcheck disable=SC2154
        chown "${user_name}.${user_group}" "${_ssh_user_dir}"
        chmod 700 "${_ssh_user_dir}"
        message_success "Created \"${_ssh_user_dir}\""
    fi

    local container_dir
    if [ "${selected_container}" ] && [ -d "${selected_container}/files/ssh" ]; then
        # shellcheck disable=SC2034
        container_dir="${selected_container}/files/ssh"
    fi

	if [ ! -d "${container_dir}" ]; then
		message_failure "No LAST-CONTAINER ssh directory"
		return
	fi

    # install the private and public keys in ~ocs/.ssh
    local type file
    for file in id_rsa id_rsa.pem id_rsa.pub; do
		if [ ! -r ${container_dir}/${file} ]; then
			message_failure "Missing ${container_dir}/${file}"
			continue
		fi

        if [[ "${file}" == *.pub ]]; then
            type=public
        else
            type=private
        fi

        if [ ! -r "${_ssh_user_dir}/${file}" ] || 
				! cmp --silent ${container_dir}/${file} ${_ssh_user_dir}/${file}; then
			install -m 600 -o "${user_name}" -g "${user_group}" "${container_dir}/${file}" "${_ssh_user_dir}/${file}"
			message_success "Installed user's ${type} key (${file})"
        fi
    done

    local key
    read -r _ key _ < "${_ssh_user_dir}/id_rsa.pub"
    if ! grep -qsw "${key}" "${_ssh_user_dir}/authorized_keys"; then
        cat "${_ssh_user_dir}/id_rsa.pub" >> "${_ssh_user_dir}/authorized_keys"
        chown "${user_name}.${user_group}" "${_ssh_user_dir}/authorized_keys"
        chmod 644 "${_ssh_user_dir}/authorized_keys"
        message_success "Added public key to authorized_keys"
    else
        message_success "The public key is already authorized"
    fi

    # scan for ssh host keys from all last machines
    local hosts=$(last-hosts --deployed)
    2>/dev/null ssh-keyscan -H -T 2 -f <(grep -wE "(${hosts// /|})" /etc/hosts | while read -r _ host _; do echo "${host}"; done; echo localhost) > "${_ssh_user_dir}/known_hosts"
    chown "${user_name}.${user_group}" "${_ssh_user_dir}/known_hosts"
    chmod 644 "${_ssh_user_dir}/known_hosts"
    message_success "Scanned for known_hosts keys"
}

function ssh_check_keys() {
    local errors=0

    local container_dir
    if [ "${selected_container}" ] && [ -d "${selected_container}/files/ssh" ]; then
        # shellcheck disable=SC2034
        container_dir="${selected_container}/files/ssh"
    fi

	if [ ! -d "${container_dir}" ]; then
		message_failure "No LAST-CONTAINER ssh directory"
		return
	fi

    if [ ! -d "${_ssh_user_dir}" ]; then
        message_failure "Missing ${_ssh_user_dir} directory"
        return 1
    fi

    local perms
    perms="$(stat --format %a "${_ssh_user_dir}")"
    if [ "${perms}" = 700 ]; then
        message_success "Permissions for ${_ssh_user_dir} are 700"
    else
        message_failure "Permissions for ${_ssh_user_dir} are ${perms} instead of 700"
        (( errors++ ))
    fi
    
    local file
    for file in id_rsa id_rsa.pem id_rsa.pub; do
        if [[ ${file} == *.pub ]]; then
            type="public"
        else
            type="private"
        fi

        if [ -r "${_ssh_user_dir}/${file}" ]; then
            message_success "User's ${type} key (${file}) exists"
            if cmp --silent ${_ssh_user_dir}/${file} ${container_dir}/${file}; then
                message_success "User's ${type} key (${file}) matches"
            else
                message_failure "User's ${type} key (${file}) does not match"
            fi
        else
            message_failure "User's ${type} key (${file}) does not exist"
            (( errors++ ))
        fi
    done

    su - ocs -c '2>/dev/null ssh-keyscan -H localhost >> ~/.ssh/known_hosts'

    local answer status
    answer=$(timeout 2s su "${user_name}" -c 'ssh localhost id -u')
    status=${?}
    if [ "${status}" != 0 ] || [ "${answer}" != "$(su "${user_name}" -c 'id -u')" ]; then
        message_failure "Passwordless ${user_name} ssh to localhost failed"
    else
        message_success "Passwordless ${user_name} ssh to localhost works"
    fi
      
}
