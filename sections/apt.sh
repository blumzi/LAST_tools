#!/bin/bash

module_include lib/message
module_include lib/sections

export apt_config_file=/etc/apt/apt.conf
export apt_google_source_list="/etc/apt/sources.list.d/google.list"

sections_register_section "apt" "Configures Apt" "network"

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
		if [ "$(wget -q -O - "https://dl.google.com/linux/linux_signing_key.pub" | apt-key add -)" = OK ]; then
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

	message_info "Updating apt ..."
	apt update
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
}

function dummy_apt_arg_parser() {
    declare OPTS
    OPTS=$( getopt -o "a:bc:" --long "aaa:,bbb,ccc:" -n "${PROG}" -- "$@")
    eval set -- "${OPTS}"

    while true; do
        case "${1}" in

        -a|--aaa)
            message_debug "${FUNCNAME[0]}: -a ${2}"
            shift 2
            ;;

        -b|--bbb)
            message_debug "${FUNCNAME[0]}: -b"
            shift 1
            ;;

        -c|--ccc)
            message_debug "${FUNCNAME[0]}: -c ${2}"
            shift 2
            ;;

        --)
            shift 1
            break
            ;;
        esac
    done
    echo "${@}"
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

function apt_policy() {
    cat <<- EOF

    - We use the Weizmann Institute's apt proxies, both for http and https.  The apt 
       configuration file ${apt_config_file} should reflect this.
    - We need Google's "Linux Package Signing Keys" in order to 'apt install' google packages.
    - We need Google's apt sources list (${apt_google_source_list})

EOF
}
