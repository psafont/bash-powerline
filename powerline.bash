#!/usr/bin/env bash
__powerline() {
  # Max length of full path
  readonly MAX_PATH_LENGTH=30

  # Use powerline mode by default
  readonly POWERLINE_FONT=''

  # Default background and foreground ANSI colours
  readonly DEFAULT_BG=0
  readonly DEFAULT_FG=7

  # Unicode symbols
  if [ -z "${POWERLINE_FONT+x}" ]; then
    readonly GIT_BRANCH_SYMBOL='∓'
  else
    readonly GIT_BRANCH_SYMBOL=''
  fi
  readonly GIT_BRANCH_CHANGED_SYMBOL='Δ'
  readonly GIT_NEED_PUSH_SYMBOL='↑'
  readonly GIT_NEED_PULL_SYMBOL='↓'

  # Powerline symbols
  readonly BLOCK_START=''

  # ANSI Colours
  readonly BLACK=0
  readonly RED=1
  readonly GREEN=2
  readonly YELLOW=3
  readonly BLUE=4
  readonly MAGENTA=5
  readonly CYAN=6
  readonly WHITE=7

  readonly BLACK_BRIGHT=8
  readonly RED_BRIGHT=9
  readonly GREEN_BRIGHT=10
  readonly YELLOW_BRIGHT=11
  readonly BLUE_BRIGHT=12
  readonly MAGENTA_BRIGHT=13
  readonly CYAN_BRIGHT=14
  readonly WHITE_BRIGHT=15

  # Font effects
  readonly DIM="\[$(tput dim)\]"
  readonly REVERSE="\[$(tput rev)\]"
  readonly RESET="\[$(tput sgr0)\]"
  readonly BOLD="\[$(tput bold)\]"

  # Generate terminal colour codes
  # $1 is an int (a colour) and $2 must be 'fg' or 'bg'
  __colour() {
    case "$2" in
      'fg'*)
        echo "\[$(tput setaf "$1")\]"
        ;;
      'bg'*)
        echo "\[$(tput setab "$1")\]"
        ;;
      *)
        echo "\[$(tput setab "$1")\]"
        ;;
    esac
  }

  # Generate a single-coloured block for the prompt
  __prompt_block() {
    local bg; local fg
    if [ ! -z "${1+x}" ]; then
      bg=$1
    else
      if [ ! -z "$BG" ]; then
        bg=$BG
      else
        bg=$DEFAULT_BG
      fi
    fi
    if [ ! -z "${2+x}" ]; then
      fg=$2
    else
      fg=$DEFAULT_FG
    fi

    local block

    # Need to generate a separator if the background changes
    if [[ ! -z "$BG" && "$bg" != "$BG" && ! -z "${POWERLINE_FONT+x}" ]]; then
      block+="$(__colour "$bg" 'bg')"
      block+="$(__colour "$BG" 'fg')"
      block+="$BLOCK_START $RESET"
      block+="$(__colour "$bg" 'bg')"
      block+="$(__colour "$fg" 'fg')"
    else
      block+="$(__colour "$bg" 'bg')"
      block+="$(__colour "$fg" 'fg')"
      block+=" "
    fi

    if [ ! -z "${3+x}" ]; then
      block+="$3 $RESET"
    fi

    BG=$bg
    echo "$block"
  }

  ### Prompt components

  __git_info() {
    if [ "x$(which git)" == "x" ]; then
      # git not found
      return
    fi
    # force git output in English to make our work easier
    local git_eng="env LANG=C git"
    # get current branch name or short SHA1 hash for detached head
    local branch; branch="$($git_eng symbolic-ref --short HEAD 2>/dev/null || $git_eng describe --tags --always 2>/dev/null)"

    if [ "x$branch" == "x" ]; then
      # git branch not found
      return
    fi

    local marks

    # branch is modified?
    [ -n "$($git_eng status --porcelain 2>/dev/null)" ] && marks+=" $GIT_BRANCH_CHANGED_SYMBOL"

    # how many commits local branch is ahead/behind of remote?
    local stat; local aheadN; local behindN
    stat="$($git_eng status --porcelain --branch 2>/dev/null | grep '^##' | grep -o '\[.\+\]$')"
    aheadN="$(echo "$stat" | grep -o 'ahead [[:digit:]]\+' | grep -o '[[:digit:]]\+')"
    behindN="$(echo "$stat" | grep -o 'behind [[:digit:]]\+' | grep -o '[[:digit:]]\+')"
    [ -n "$aheadN" ] && marks+=" $GIT_NEED_PUSH_SYMBOL$aheadN"
    [ -n "$behindN" ] && marks+=" $GIT_NEED_PULL_SYMBOL$behindN"

    local bg; local fg
    fg=$(__colour $BLACK 'fg')
    if [ -z "$marks" ]; then
      bg=$(__colour $GREEN 'bg')
    else
      bg=$(__colour $YELLOW 'bg')
    fi

    # print the git branch segment without a trailing newline
    echo "$bg$fg $GIT_BRANCH_SYMBOL $branch$marks "
  }

  __virtualenv_block() {
    # Copied from Python virtualenv's activate.sh script.
    # https://github.com/pypa/virtualenv/blob/a9b4e673559a5beb24bac1a8fb81446dd84ec6ed/virtualenv_embedded/activate.sh#L62
    # License: MIT
    if [ -n "$VIRTUAL_ENV" ]; then
      local text
      if [ "$(basename \""$VIRTUAL_ENV"\")" == "__" ]; then
        # special case for Aspen magic directories
        # see http://www.zetadev.com/software/aspen/
        text="[$(basename \$\(dirname \""$VIRTUAL_ENV"\"\))]"
      else
        text="($(basename \""$VIRTUAL_ENV"\"))"
      fi
      __prompt_block $WHITE $BLACK "$text"
    fi
  }

  __pwd() {
    # Use ~ to represent $HOME prefix
    local pwd; pwd=$(pwd | sed -e "s|^$HOME|~|")
    if [[ ( $pwd = ~\/*\/* || $pwd = \/*\/*/* ) && ${#pwd} -gt $MAX_PATH_LENGTH ]]; then
      local IFS='/'
      read -ra split <<< "$pwd"
      if [[ $pwd = ~* ]]; then
        pwd="~/${split[1]}/.../${split[*]:(-2):1}/${split[*]:(-1)}"
      else
        pwd="/${split[1]}/.../${split[*]:(-2):1}/${split[*]:(-1)}"
      fi
    fi
    echo "$pwd"
  }

  # superuser or not, here I go!
  # $1 if present contains fg or bg and forces the function to return the
  # colour (int) for the fg or bg
  __user_block() {
    # Decide colours to use
    local fg=$WHITE_BRIGHT
    local bg=$BLUE
    if [ "$(whoami)" == "root" ]; then
      local bg=$RED
    fi

    if [ "$(whoami)" == "root" ]; then
      local show_user="y"
      local show_host="y"
    fi

    if [[ ! -z "$SSH_CLIENT" || ! -z "$SSH_TTY" ]]; then
      local show_user="y"
      local show_host="y"
    fi

    local text

    if [ ! -z ${show_user+x} ]; then
      text+="$BOLD$(whoami)"
    fi
    if [ ! -z ${show_host+x} ]; then
      text+="@\h"
    fi

    __prompt_block $bg $fg $text
  }

  __status_block() {
    local exit_code=$?
    $(history -a ; history -n)

    if [ $exit_code -ne 0 ]; then
      __prompt_block $BLACK $RED '✘'
    fi

    local uid; uid=$(id -u "$USER")
    if [ "$uid" -eq 0 ]; then
      __prompt_block $BLACK $YELLOW '⚡'
    fi

    local jobs; jobs=$(jobs -l | wc -l)
    if [ "$jobs" -gt 0 ]; then
      __prompt_block $BLACK $CYAN '⚙'
    fi
  }

  # Build the prompt
  prompt() {
    # I don't like bash; execute first to capture correct status code
    local status_block; status_block="$(__status_block)"

    PS1="\n"
    PS1+=$status_block
    PS1+=$(__virtualenv_block)
    PS1+=$(__user_block)
    PS1+="$(__colour $BLACK_BRIGHT 'bg')$(__colour $WHITE_BRIGHT 'fg') $(__pwd) $RESET"
    PS1+=$(__git_info)
    PS1+="$RESET "
  }

  PROMPT_COMMAND=prompt
}

__powerline
unset __powerline
