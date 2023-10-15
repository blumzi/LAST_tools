#
# Stuff related to backups
#

module_include lib/message

#
# We currently use last@marvin/BIGDATA/last/data/temp as the default target
#
export backup_default_target="last@marvin.weizmann.ac.il:/BIGDATA/last/data/temp"
export backup_user=
export backup_host=
export backup_topdir=
export backup_target=

function backup_set_target() {
    local target="${1}"

    if [[ ${target} != *@*:* ]]; then
        message_fatal "A backup target must have the format <user-name>@<host-name>:<top-dir-path>"
        exit 1
    fi

    backup_target="${target}"
    backup_user=${backup_target%@*}
    backup_host=${backup_target#*@}
    backup_host=${backup_host%:*}
    backup_topdir=${backup_target#*:}
}

#
# Checks whether one local directory was backed-up
#
function backup_check_one() {
    local local_dir="${1}" backup_dir
    local status padded_backup_dir
    local local_nfiles remote_nfiles

    if [[ ${local_dir} == */archive/* ]]; then
        backup_dir=${local_dir#*/archive/}
    else
        message_fatal 'Expected */archive/* path'
        return
    fi
    padded_backup_dir=$(printf "%-56s" ${local_dir})

    # Check the backup directory exists
    sudo -u ocs ssh -o "StrictHostKeyChecking accept-new" ${backup_user}@${backup_host} "test -d ${backup_topdir}/${backup_dir} >/dev/null 2>/dev/null"
    status=${?}

    if (( status != 0 )); then
        message_failure "${padded_backup_dir} was not backed up (no ${backup_topdir}/${backup_dir} on ${backup_host})"
        return
    fi

    local tmp=$(mktemp -d)
    chmod 755 ${tmp}

    pushd ${local_dir} >/dev/null 2>&1 

    # Get local and remote file sizes
    du -b $(ls -1 | sort) > ${tmp}/local-sizes
    sudo -u ocs ssh -o "StrictHostKeyChecking accept-new" ${backup_user}@${backup_host} "cd ${backup_topdir}/${backup_dir} >/dev/null 2>/dev/null; du -b \$(ls -1 | sort)" > ${tmp}/remote-sizes
    local local_nfiles=$(wc -l < ${tmp}/local-sizes)
    local remote_nfiles=$(wc -l < ${tmp}/remote-sizes)

    if (( local_nfiles == remote_nfiles )); then
        #
        # We have the same number of local and backup files, a good start :)
        #
        ok_message="${padded_backup_dir} all files have been backed up"
        if diff -q ${tmp}/local-sizes ${tmp}/remote-sizes > ${tmp}/diff 2>/dev/null; then
            ok_message+=", file sizes match"
            message_success "${ok_message}"

            if ${remove}; then
                message_warning "At this point-in-time we don't actually remove the local directory"
            fi
        else
            message_warning "${ok_message}, file sizes don't match, list below"
            sed 's;^;    ;' < ${tmp}/diff
        fi
    elif (( remote_nfiles > local_nfiles )); then
        message_warning "${padded_backup_dir} too many remote files (${remote_nfiles} instead of ${local_nfiles})"
    else
        message_failure "${padded_backup_dir} ${remote_nfiles} files out of ${local_nfiles} were backed up"
    fi
}

#
# Checks all the pipeline directories on the local machine
#
backup_check_all() {
    for stat_file in $(find /$(hostname -s)/data[12] -name .status | grep -vE '(Trash)' | sort); do
        backup_check_one $(dirname ${stat_file})
    done
}