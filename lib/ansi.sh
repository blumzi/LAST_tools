#!/bin/bash

export ANSI_BREAK ANSI_NORMAL ANSI_UNDERLINE ANSI_FLASH ANSI_REVERSE
# Control characters
ANSI_BREAK=$'\x1b[0;01m'   # line break?
ANSI_NORMAL=$'\x1b[0;0m'   # clear color(s)
ANSI_UNDERLINE=$'\x1b[4m'  # underline
ANSI_FLASH=$'\x1b[5m'      # flash
ANSI_REVERSE=$'\x1b[7m'    # reverse video

# Normal color
export ANSI_NORMAL_BLACK ANSI_NORMAL_RED ANSI_NORMAL_GREEN ANSI_NORMAL_YELLOW
export ANSI_NORMAL_MAGENTA ANSI_NORMAL_CYAN ANSI_NORMAL_WHITE ANSI_NORMAL_BLUE
ANSI_NORMAL_BLACK=$'\x1b[0;30m'
ANSI_NORMAL_RED=$'\x1b[0;31m'
ANSI_NORMAL_GREEN=$'\x1b[0;32m'
ANSI_NORMAL_YELLOW=$'\x1b[0;33m'
ANSI_NORMAL_BLUE=$'\x1b[0;34m'
ANSI_NORMAL_MAGENTA=$'\x1b[0;35m'
ANSI_NORMAL_CYAN=$'\x1b[0;36m'
ANSI_NORMAL_WHITE=$'\x1b[0;37m'

# Bright color
export ANSI_BRIGHT_BLACK ANSI_BRIGHT_RED ANSI_BRIGHT_GREEN ANSI_BRIGHT_YELLOW
export ANSI_BRIGHT_BLUE ANSI_BRIGHT_MAGENTA ANSI_BRIGHT_CYAN ANSI_BRIGHT_WHITE
ANSI_BRIGHT_BLACK=$'\x1b[1;30m'
ANSI_BRIGHT_RED=$'\x1b[1;31m'
ANSI_BRIGHT_GREEN=$'\x1b[1;32m'
ANSI_BRIGHT_YELLOW=$'\x1b[1;33m'
ANSI_BRIGHT_BLUE=$'\x1b[1;34m'
ANSI_BRIGHT_MAGENTA=$'\x1b[1;35m'
ANSI_BRIGHT_CYAN=$'\x1b[1;36m'
ANSI_BRIGHT_WHITE=$'\x1b[1;37m'

# Background colors
export ANSI_BG_BLACK ANSI_BG_RED ANSI_BG_GREEN ANSI_BG_YELLOW
export ANSI_BG_BLUE ANSI_BG_MAGENTA ANSI_BG_CYAN ANSI_BG_WHITE
ANSI_BG_BLACK=$'\x1b[40m'
ANSI_BG_RED=$'\x1b[41m'
ANSI_BG_GREEN=$'\x1b[42m'
ANSI_BG_YELLOW=$'\x1b[43m'
ANSI_BG_BLUE=$'\x1b[44m'
ANSI_BG_MAGENTA=$'\x1b[45m'
ANSI_BG_CYAN=$'\x1b[46m'
ANSI_BG_WHITE=$'\x1b[47m'

function ansi_reset() {
    echo -ne "${ANSI_NORMAL}"
}

function ansi_bright_yellow() {
    echo -ne "${ANSI_BRIGHT_YELLOW}${*}${ANSI_NORMAL}"
}

function ansi_bright_red() {
    echo -ne "${ANSI_BRIGHT_RED}${*}${ANSI_NORMAL}"
}

function ansi_bright_green() {
    echo -ne "${ANSI_BRIGHT_GREEN}${*}${ANSI_NORMAL}"
}

function ansi_bright_white() {
    echo -ne "${ANSI_BRIGHT_WHITE}${*}${ANSI_NORMAL}"
}

function ansi_underline() {
    echo -ne "${ANSI_UNDERLINE}${*}${ANSI_NORMAL}"
}