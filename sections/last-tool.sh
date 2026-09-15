#!/bin/bash

module_include lib/message

sections_register_section "last-tool" "Checks the installation of the last-tool package itself" ""

last_tool_package="last-tool"
last_tool_top="/usr/local/share/${last_tool_package}"
last_tool_bindir="/usr/local/bin"

#
# Links whose name differs from the name of the script they point to
#
declare -A last_tool_link_targets=(
    [last-matlab-R2022a]=last-matlab
)

#
# The /usr/local/bin/last-* entries that belong to the package.
# The package installs them as symlinks into ${last_tool_top}/bin.  A regular file
#  with the same name (e.g. a hand-copied script) shadows the packaged one, and
#  the two then diverge: PATH gets the copy, crontab entries (which use the full
#  ${last_tool_top}/bin path) get the packaged one.
#
function last_tool_packaged_links() {
    dpkg -L "${last_tool_package}" 2>/dev/null | grep "^${last_tool_bindir}/last-"
}

function last_tool_link_target() {
    local name="${1}"

    echo "${last_tool_top}/bin/${last_tool_link_targets[${name}]:-${name}}"
}

#
# Succeeds if the link is a symlink resolving to an existing file under ${last_tool_top}
#
function last_tool_link_is_ok() {
    local link="${1}"
    local target

    [ -L "${link}" ] || return 1
    target="$(readlink -f "${link}")"
    [[ "${target}" == ${last_tool_top}/* ]] && [ -e "${target}" ]
}

function last_tool_check() {
    local -i ret=0 nlinks=0 nok=0
    local link name
    local -a modified

    for link in $(last_tool_packaged_links); do
        (( nlinks++ ))
        name="$(basename "${link}")"

        if last_tool_link_is_ok "${link}"; then
            (( nok++ ))
        elif [ -L "${link}" ]; then
            message_failure "last-tool: ${link} -> $(readlink "${link}") does not resolve to a file under ${last_tool_top}"
            (( ret++ ))
        elif [ -e "${link}" ]; then
            message_failure "last-tool: ${link} is a regular file, not a symlink to $(last_tool_link_target "${name}")"
            (( ret++ ))
        else
            message_failure "last-tool: ${link} is missing"
            (( ret++ ))
        fi
    done

    if (( nok == nlinks )); then
        message_success "last-tool: all ${nlinks} packaged ${last_tool_bindir}/last-* entries are symlinks into ${last_tool_top}"
    fi

    modified=( $(dpkg -V "${last_tool_package}" 2>/dev/null | awk '{print $NF}') )
    if [ ${#modified[*]} -ne 0 ]; then
        message_warning "last-tool: ${#modified[*]} packaged file(s) differ from the installed .deb (hand-updated?): ${modified[*]}"
    fi

    return $(( ret ))
}

function last_tool_enforce() {
    local -i ret=0
    local link name target

    for link in $(last_tool_packaged_links); do
        if last_tool_link_is_ok "${link}"; then
            continue
        fi
        name="$(basename "${link}")"
        target="$(last_tool_link_target "${name}")"

        if [ -f "${link}" ] && [ ! -L "${link}" ]; then
            #
            # A regular file shadows the packaged script.  Keep the newer of the two
            #  (a hand-copied script is usually newer than the packaged one).
            #
            if [ ! -e "${target}" ]; then
                mv -f "${link}" "${target}"
                message_success "last-tool: ${link} moved to ${target} (packaged script was missing)"
            elif cmp -s "${link}" "${target}"; then
                /bin/rm -f "${link}"
                message_success "last-tool: ${link} was an identical copy of ${target}, removed"
            elif [ "${link}" -nt "${target}" ]; then
                mv -f "${link}" "${target}"
                message_success "last-tool: ${link} was newer than ${target}, moved over it"
            else
                /bin/rm -f "${link}"
                message_success "last-tool: ${link} was older than ${target}, discarded"
            fi
        fi

        if [ ! -e "${target}" ]; then
            message_failure "last-tool: cannot link ${link}, ${target} does not exist"
            (( ret++ ))
            continue
        fi

        ln -sfn "${target}" "${link}"
        message_success "last-tool: ${link} -> ${target}"
    done

    return $(( ret ))
}

function last_tool_policy() {
    cat <<- EOF

    The last-tool package installs its scripts under ${last_tool_top}/bin and
     exposes them in ${last_tool_bindir} as symlinks.

    Every packaged ${last_tool_bindir}/last-* entry must be such a symlink.  A regular
     file there (e.g. a script copied by hand) shadows the packaged one, and from
     then on PATH and the crontab entries (which use the full ${last_tool_top}/bin
     path) run different versions of the same script.

    Enforcing restores the symlinks.  When a shadowing copy differs from the packaged
     script, the newer of the two is kept in ${last_tool_top}/bin.

    Packaged files that differ from the installed .deb are reported as a warning.

EOF
}
