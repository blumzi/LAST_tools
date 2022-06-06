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

# let status change of background jobs be displayed immediately
set -b

#
# Some convenience shortcuts
#
this_site="01"
this_mount=$(hostname -s | sed -e 's;last;;' -e 's;[ew]$;;')
cameras=(
    "/last${this_mount}e/data1/archive/LAST.${this_site}.${this_mount}.01"
    "/last${this_mount}e/data2/archive/LAST.${this_site}.${this_mount}.02"
    "/last${this_mount}w/data1/archive/LAST.${this_site}.${this_mount}.03"
    "/last${this_mount}w/data2/archive/LAST.${this_site}.${this_mount}.04"
)
for (( i = 0 ; i < ${#cameras[*]}; i++ )); do
    eval "alias cdcam$(( i + 1 ))=\"cd ${cameras[${i}]}\""
done

unset cameras this_mount this_site