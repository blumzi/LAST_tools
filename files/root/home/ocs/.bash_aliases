#!/bin/bash

# get the current vim version
read -r _ _ _ _ vimver _ <<< "$(vim --version | grep '^VIM' | tr -d '.')"
#shellcheck disable=SC2139
alias ++="vim -u /usr/share/vim/vim${vimver}/macros/less.vim"
unset vimver

alias  p=pwd
alias  u=users
alias  d=dirs
alias  p=pwd
alias  '+'=less
alias  l='ls -FC --color=auto'
alias pu=pushd
alias po=popd
alias  j='jobs -l'
alias rm='/bin/rm -i'
alias di='/bin/ls -l --color=auto'
alias vi=vim
alias     grep="grep -E --color=auto"
alias pcregrep="pcregrep --color=auto -M"

export LESS="-ceFi"

if [ "$(id -un)" == root ]; then
    alias s=suspend
else
    alias s='%sudo'
fi

set -b

#
# Some convenience shortcuts
#
this_mount=$(hostname -s | sed -e 's;last;;' -e 's;[ew]$;;')
dirs=( /last"${this_mount}"{e,w}/data{1,2}/archive )
pattern="${dirs[*]// /:}"
if [[ ${CDPATH} != *${pattern}* ]]; then
    if [ ! "${CDPATH}" ]; then
        CDPATH=${pattern}
    else
        CDPATH=${CDPATH}:${pattern}
    fi
fi

eval "alias cdcam1=\"cd /last${this_mount}e/data1\""
eval "alias cdcam2=\"cd /last${this_mount}e/data2\""
eval "alias cdcam3=\"cd /last${this_mount}w/data1\""
eval "alias cdcam4=\"cd /last${this_mount}w/data2\""

unset dirs pattern this_mount

