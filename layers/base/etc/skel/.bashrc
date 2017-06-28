#MIT License
#Copyright (c) 2017 phR0ze
#
#Permission is hereby granted, free of charge, to any person obtaining a copy
#of this software and associated documentation files (the "Software"), to deal
#in the Software without restriction, including without limitation the rights
#to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#copies of the Software, and to permit persons to whom the Software is
#furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all
#copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#SOFTWARE.

# If not running interactively, don't do anything
#[ -z "$PS1" ] && return

# Set terminal type if not set
[ -z ${TERM+x} ] && export TERM=xterm

# Enable programmable completion features
[ -r /etc/bash_completion ] && . /etc/bash_completion

# Enable dircolors if supported
[ -x /usr/bin/dircolors ] && [ -r ~/.dircolors ] && eval "$(dircolors -b ~/.dircolors)"

# Various configs
#----------------------------------------------------------------------------------------
complete -cf sudo                   # Setup bash tab completion for sudo
set -o vi                           # Set vi command prompt editing
umask 022                           # Default permissions for the files you create

shopt -s dotglob                    # Have * include .files as well
shopt -s extglob                    # Include extended globbing support
shopt -s histappend                 # Append to the history file, don't overwrite it
shopt -s checkwinsize               # Update window LINES/COLUMNS after ea. command if necessary

export HISTSIZE=10000               # Set history length
export HISTFILESIZE=${HISTSIZE}     # Set history file size
export HISTCONTROL=ignoreboth       # Ignore duplicates and lines starting with space
export KUBE_EDITOR=vim              # Set the editor to use for Kubernetes edit commands
export GOPATH=~/Projects/go         # GOPATH for all Go projects

# Command Aliases
#----------------------------------------------------------------------------------------
alias gb='git branch -av'
alias gd='git diff-tree -r --name-only'
alias gl='git log -5 --graph --decorate --pretty=oneline'

alias ip='ip -c'
alias ls='ls -h --group-directories-first --color=auto'
alias ll='ls -lah --group-directories-first --color=auto'
alias diff='diff --color=auto'
alias grep='grep --color=auto'
alias free='free -m'                    # show sizes in MB
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Modify the Command Prompt
# \u User name, \h Host name, \w Current path, \W Current directory, \" Quote sign
# \s Name of the shell, \$ Dollar sign, \@ Time in AM/PM format
#----------------------------------------------------------------------------------------
# Note: \[ and \] enclosures are needed to keep prompt from wrapping too soon
# Output: "user@host:path$ "
none="\[\e[0m\]"
cyber="\[\e[1;38;5;67m\]"
export PS1="${cyber}[\u@\h:\w]\$${none} "
export PATH=$PATH:$HOME/bin
