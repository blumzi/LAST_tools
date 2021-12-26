#!/bin/bash

module_include lib/message
module_include lib/sections

sections_register_section "filesystems" "Manages the exporting/mounting of filesystems"

#
# Cross mounting of filesystems between sibling machines (belonging to same LAST mount)
# Example: Mount last1 has two computers last01e and last01w
#   On: last01e
#       /last01e/data1  - local fs
#       /last01e/data2  - local fs
#       /last01w/data1  - nfs mount from last01w:/last01w/data1
#       /last01w/data2  - nfs mount from last01w:/last01w/data2
#

#
# The hostname for the current machine is passed in LAST_HOSTNAME by the main tool
#

function filesystems_start() {
    message_info "Mounting all the network filesystems"
    mount -a -t nfs
}

function filesystems_configure() {
    # TODO: export/mount filesystems
    :
}

function filesystems_check() {
    :
}