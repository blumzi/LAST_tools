#!/bin/bash

module_include lib/message
module_include lib/sections
module_include lib/wget

export apt_config_file=/etc/apt/apt.conf
export apt_google_source_list="/etc/apt/sources.list.d/google.list"

sections_register_section "apt" "Configures Apt" "profile network"

function apt_enforce() {
    
    if [ ! -f "${apt_config_file}" ]; then
        mkdir -p "$(dirname "${apt_config_file}")"
        {
            echo 'Acquire::http::Proxy "http://bcproxy.weizmann.ac.il:8080";'
            echo 'Acquire::https::Proxy "http://bcproxy.weizmann.ac.il:8080";'
        } > ${apt_config_file}
        chmod 644 ${apt_config_file}
		message_success "Generated config file ${apt_config_file}"

		message_info "Updating apt ..."
		apt update
    elif [[ "$(grep -s '^Acquire::http::Proxy' "${apt_config_file}")" == *http://bcproxy.weizmann.ac.il:8080* ]] &&
			[[ "$(grep -s '^Acquire::https::Proxy' "${apt_config_file}")" == *http://bcproxy.weizmann.ac.il:8080* ]]; then
			message_success "Config file ${apt_config_file} contains the Weizmann Inst. proxies."
	else
        local tmp
        tmp=$(mktemp)
        {
            grep -Ev '(Acquire::http::Proxy|Acquire::https::Proxy)' "${apt_config_file}"
            echo 'Acquire::http::Proxy "http://bcproxy.weizmann.ac.il:8080";'
            echo 'Acquire::https::Proxy "http://bcproxy.weizmann.ac.il:8080";'
        } > "${tmp}"
        mv "${tmp}" "${apt_config_file}"
        chmod 644 "${apt_config_file}"

		message_success "Fixed config file ${apt_config_file}"

	fi

	local google_keys
	google_keys="$(apt-key list google 2>/dev/null)"

	if [ "${google_keys}" ]; then
		message_success "We have Google's \"Linux Package Signing Keys\" installed"
	else
		if [ "$(wget -o /dev/null -q -O - "https://dl.google.com/linux/linux_signing_key.pub" | apt-key add -)" = OK ]; then
			message_success "Installed Google's \"Linux Package Signing Keys\"."
		else
			message_failure "Failed to install Google's \"Linux Package Signing Keys\"."
		fi
	fi

	if [ -r "${apt_google_source_list}" ]; then
		message_success "We have Google's apt sources list (${apt_google_source_list})"
	else
		echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> "${apt_google_source_list}" 
		message_success "Added Google's apt sources list (${apt_google_source_list})"
	fi

    apt_enforce_vscode

	message_info "Updating apt ..."
	apt update

    local config delivered_config
    delivered_config="$(module_locate files/root/etc/apt/apt.conf.d/20auto-upgrades)"
    config="/etc/apt/apt.conf.d/20auto-upgrades"
    if ! diff "${delivered_config}" "${config}" >& /dev/null; then
        cp "${delivered_config}" "${config}"
        message_success "auto-update: Disabled (${config})"
    else
        message_success "auto-update: Already disabled (${config})"
    fi

    apt_enforce_unattended_upgrades
}

function apt_check() {
    local success=false
    
    if [[ "$(grep -s '^Acquire::http::Proxy' ${apt_config_file})" == *http://bcproxy.weizmann.ac.il:8080* ]] &&
        [[ "$(grep -s '^Acquire::https::Proxy' ${apt_config_file})" == *http://bcproxy.weizmann.ac.il:8080* ]]; then
        success=true
    fi

    if ${success}; then
        message_success "Apt proxy is well defined"
    else
        message_failure "Apt proxy is not well defined"
    fi

    local google_keys
    google_keys="$(apt-key list google 2>/dev/null)"

    if [ "${google_keys}" ]; then
        message_success "We have Google's \"Linux Package Signing Keys\" installed"
    else
        message_failure "Missing Google's \"Linux Package Signing Keys\""
    fi

    if [ -r "${apt_google_source_list}" ]; then
        message_success "We have Google's apt source list (${apt_google_source_list})"
    else
        message_failure "Missing Google's apt source list (${apt_google_source_list})"
    fi

    apt_check_vscode

    # check auto-update settings
    local config delivered_config
    delivered_config="$(module_locate files/root/etc/apt/apt.conf.d/20auto-upgrades)"
    config="/etc/apt/apt.conf.d/20auto-upgrades"
    if diff "${delivered_config}" "${config}" >& /dev/null; then
        message_success "auto-update: already disabled (${config}) "
    else
        message_failure "auto-update: NOT disabled (${config})"
    fi

    apt_check_unattended_upgrades
}

function dummy_apt_arg_parser() {
	case "${ARGV[0]}" in

	-h|--help)
		apt_helper
		shiftARGV 1
		;;
	esac
}

function dummy_apt_helper() {
    cat <<- EOF

    This is a dummy helper

    Arguments:
     -a|--aaa: The -a arg (with value)
     -b|--bbb: A boolean argument
     -c|--ccc: The -c arg with value

EOF
}

function apt_enforce_vscode() {
    local label=vscode
    local list_file="/etc/apt/sources.list.d/vscode.list"

    if apt-key list 2>/dev/null | grep -q Microsoft; then
        message_success "${label}: We already have the Microsoft key"
    else
        wget ${WGET_OPTIONS} https://packages.microsoft.com/keys/microsoft.asc -O- | apt-key add - >/dev/null 2>&1
        message_success "${label}: Fetched key"
    fi

    if [ -e ${list_file} ]; then
        message_success "${label}: We already have the source list"
    else
        echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" > "${list_file}"
        message_success "${label}: Added repository"
    fi
}

function apt_check_vscode() {
    local label=vscode
    local list_file="/etc/apt/sources.list.d/vscode.list"

    if apt-key list 2>/dev/null | grep -q Microsoft; then
        message_success "${label}: We have the Microsoft key"
    else
        message_failure "${label}: We DON'T have the Microsoft key"
    fi

    if [ -e ${list_file} ]; then
        message_success "${label}: We have the source list"
    else
        message_failure "${label}: We DON'T have the source list"
    fi
}


function apt_check_unattended_upgrades() {
    local service="unattended-upgrades"

    if [ "$(systemctl is-enabled ${service})" != "disabled" ]; then
        message_failure "The \"${service}\" is NOT disabled"
    else
        message_success "The \"${service}\" is disabled."
    fi
}

function apt_enforce_unattended_upgrades() {
    local service="unattended-upgrades"

    if systemctl stop ${service} && systemctl disable ${service}; then
        message_success "Stopped and disabled the \"${service}\" service."
        return 0
    else
        message_failure "Failed to stop and disable the \"${service}\" service."
        return 1
    fi
}

function apt_policy() {
    cat <<- EOF

    - We use the Weizmann Institute's apt proxies, both for http and https.  The apt 
       configuration file ${apt_config_file} should reflect this.
    - We need Google's "Linux Package Signing Keys" in order to 'apt install' google packages.
    - We need Google's apt sources list (${apt_google_source_list})
    - We disable the unattended-upgrades service

    Automatic updates are $(ansi_underline disabled)
EOF
}
