#!/bin/bash

module_include lib/user
module_include lib/macmap
module_include lib/messages

sections_register_section "crontab" "Handles crontabs" ""

function crontab_enforce() {
    
    {
        if macmap_this_is_last0; then
            echo "0  7 * * * /usr/local/share/last-tool/bin/last-pipeline-digest"
        fi
        echo "0  8 * * * /usr/local/share/last-tool/bin/last-backup --remove"
        echo "0 12 * * * /usr/local/share/last-tool/bin/last-compress-raw-images"
        echo "30 14 * * * /usr/local/share/last-tool/bin/last-prune-individual-images"
    } | crontab -u ${user_name} -
    message_success "crontab: Updated crontab for user \"${user_name}\""
}

function crontab_check() {
    local expected found pattern ret
    local -a entries with_commas

    pattern='last-(backup|compress-raw-images|pipeline-digest|prune-individual-images)'
    entries=( last-backup last-compress-raw-images last-prune-individual-images )
    if macmap_this_is_last0; then
        entries+=( last-pipeline-digest )
    fi
    pattern=$( echo "${entries[@]}" | tr ' ' '|' )
    expected=${#entries[@]}
    with_commas=$( echo "${entries[@]}" | tr ' ' ',' )

    ret=0
    found=$( crontab -l -u ${user_name} | egrep  --count "${pattern}" )
    if (( found == expected )); then
        message_success "crontab: found expected lines for ${with_commas}"
    else
        message_failure "crontab: only ${found} out of ${expected} lines for ${with_commas} were found"
        (( ret++ ))
    fi

    return ${ret}
}

function crontab_policy() {
    cat <<- EOF

    A few activities are performed periodically via cron(8).

    This section maintains the respective crontab(s)

EOF
}
