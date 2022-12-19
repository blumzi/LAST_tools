#!/bin/bash

module_include lib/message
module_include lib/sections
module_include lib/util

sections_register_section "profile" "Manages profile files"

_profile_last="/etc/profile.d/last.sh"
_env_config_file="/etc/environment"

function profile_enforce() {

    if [ ! -r "${_profile_last}" ]; then
        cat << EOF > ${_profile_last}
        #
        # Global environment for the LAST project
        #


        function append_to_module_include_path() {
            local subpath="\$1"
            local found=false p

            for p in \${LAST_MODULE_INCLUDE_PATH//:/ }; do
                if [ "\${p}" = "\${subpath}" ]; then
                    found=true
                    break
                fi
            done
            if ! \${found}; then
                export PATH=\${PATH}:\${subpath}
            fi
        }

        export LAST_TOOL_ROOT=/usr/local/share/last-tool
        append_to_module_include_path \${LAST_TOOL_ROOT}

        module_include lib/util

        util_test_and_set_http_proxy

        unset TMOUT
EOF
        message_success "Created \"${_profile_last}\"."
    else
        message_success "\"${_profile_last}\" already exists"
    fi

    etc_environment_enforce
}

function profile_check() {
    local errors=0

    if [ -r "${_profile_last}" ]; then
        message_success "The file \"${_profile_last}\" exists"
    else
        message_failure "The file \"${_profile_last}\" does not exist"
        (( errors++ ))
    fi

    etc_environment_check; (( errors += $? ))

    return $((errors))
}

function profile_policy() {
    cat <<- EOF

    We maintain the "${_profile_last}" file.  It is used by pam_env(7) to initialize
     a login process's environment.

    The "${_env_config_file}" file has settings for http_proxy, https_proxy and no_proxy.

EOF
}

function etc_environment_check() {
    local nlines=$(grep -Ec "^(http|https|no)_proxy=" "${_env_config_file}")

    if [ "${nlines}" = 3 ]; then
        message_success "The file \"${_env_config_file}\" has settings for http_proxy, https_proxy and no_proxy"
    else
        message_failure "The file \"${_env_config_file}\" misses settings for either http_proxy, https_proxy or no_proxy"
        return 1
    fi
}

function etc_environment_enforce() {
    local tmp
    tmp="$(mktemp)"
    local ips
    printf -v ips "%s," 10.23.{1..3}.{1..25} 10.23.0.{3..5} 10.23.0.{100..103}
    ips="${ips%,}"


    cat <<- EOF > "${tmp}"
#!/bin/sh

PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin"

http_proxy="http://bcproxy.weizmann.ac.il:8080"
https_proxy="http://bcproxy.weizmann.ac.il:8080"
no_proxy="127.0.0.1,${ips}"
EOF
    mv "${tmp}" "${_env_config_file}"
    message_success "Added settings for http_proxy and https_proxy to \"${_env_config_file}\"."
}
