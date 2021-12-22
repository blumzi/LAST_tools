#!/bin/bash

# Control characters
CBRK=$'\x1b[0;01m'  # Line break?
ansi_normal=$'\x1b[0;0m'   # Clear color
ansi_underline=$'\x1B[4m'     # Underline
ansi_flash=$'\x1B[5m'     # Flash
ansi_reverse=$'\x1B[7m'     # Reverse video

# Normal color
ansi_fg_black=$'\x1B[0;30m'
ansi_fg_red=$'\x1b[0;31m'
ansi_fg_green=$'\x1b[0;32m'
ansi_fg_yellow=$'\x1b[0;33m'
ansi_fg_blue=$'\x1b[0;34m'
ansi_fg_magenta=$'\x1b[0;35m'
ansi_fg_cyan=$'\x1b[0;36m'
ansi_fg_white=$'\x1B[0;37m'

# Bright color
ansi_bright_black=$'\x1B[1;30m'
ansi_bright_red=$'\x1b[1;31m'
ansi_bright_green=$'\x1b[1;32m'
ansi_bright_yellow=$'\x1b[1;33m'
ansi_bright_blue=$'\x1b[1;34m'
ansi_bright_magenta=$'\x1b[1;35m'
ansi_bright_cyan=$'\x1b[1;36m'
ansi_bright_white=$'\x1B[1;37m'

# Background colors
ansi_bg_black=$'\x1B[40m'
ansi_bg_red=$'\x1b[41m'
ansi_bg_green=$'\x1b[42m'
ansi_bg_yellow=$'\x1b[43m'
ansi_bg_blue=$'\x1b[44m'
ansi_bg_magenta=$'\x1b[45m'
ansi_bg_cyan=$'\x1b[46m'
ansi_bg_white=$'\x1B[47m'

function ansi_reset() {
    echo "${ansi_fg_white}${BKBLK}"
}

function ansi_red() {
    echo -n "${ansi_bright_red}${*}${ansi_bright_white}"
}