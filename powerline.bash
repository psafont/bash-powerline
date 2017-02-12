#!/usr/bin/env bash
__powerline() {

  # User config variables,
  # it's recommended to override those variables through .bashrc or similar
  #
  # Use powerline mode
  # readonly POWERLINE_FONT=''
  #
  # Always show user in the prompt
  # readonly SHOW_USER=''
  #
  # Never show a default user
  # readonly DEFAULT_USER='user'

  # Default background and foreground ANSI colours
  readonly DEFAULT_BG=0
  readonly DEFAULT_FG=7

  # Max length of full path
  readonly MAX_PATH_LENGTH=30

  # Unicode symbols
  if [ -z "${POWERLINE_FONT+x}" ]; then
    readonly GIT_BRANCH_SYMBOL='⑂'
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
      if [ ! -z "$last_bg" ]; then
        bg=$last_bg
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
    if [[ ! -z "$last_bg" && "$bg" != "$last_bg" && ! -z "${POWERLINE_FONT+x}" ]]; then
      block+="$(__colour "$bg" 'bg')"
      block+="$(__colour "$last_bg" 'fg')"
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

    last_bg=$bg

    __block_text="$block"
  }

  function __end_block() {
    __block_text=''
    if [ ! -z "$last_bg" ]; then
      if [ ! -z "${POWERLINE_FONT+x}" ]; then
        __block_text+="$(__colour $DEFAULT_BG 'bg')"
        __block_text+="$(__colour "$last_bg" 'fg')"
        __block_text+="$BLOCK_START$RESET"
        __block_text+="$(__colour $DEFAULT_BG 'bg')"
        __block_text+="$(__colour "$DEFAULT_FG" 'fg')"
      else
        __block_text+="$(__colour $DEFAULT_BG 'bg')"
        __block_text+="$(__colour "$DEFAULT_FG" 'fg')"
      fi
    fi
    __block_text+=' '
  }

  ### Prompt components

  __git_block() {
    if [ ! hash git 2> /dev/null ]; then
      # git not found
      __block_text=''
      return
    fi
    # force git output in English to make our work easier
    local git_eng="env LANG=C git"

    # check if pwd is under git
    git rev-parse 2> /dev/null
    if [ $? != 0 ]; then
      # not in a git repo, bail out
      __block_text=''
      return
    fi

    # get current branch name or short SHA1 hash for detached head
    local branch; local ref_symbol
    branch="$($git_eng symbolic-ref --short HEAD 2>/dev/null)"
    if [ $? != 0 ]; then
      branch="$($git_eng describe --tags --always 2>/dev/null)"
      ref_symbol='➦'
    else
      ref_symbol=$GIT_BRANCH_SYMBOL
    fi

    ref="$ref_symbol $branch "

    local marks

    # check if HEAD is dirty
    if [ -n "$($git_eng status --porcelain 2>/dev/null)" ]; then
      dirty='y'
      marks+=" $GIT_BRANCH_CHANGED_SYMBOL"
    fi

    # how many commits local branch is ahead/behind of remote?
    local stat; local aheadN; local behindN
    stat="$($git_eng status --porcelain --branch 2>/dev/null | grep '^##' | grep -o '\[.\+\]$')"
    aheadN="$(echo "$stat" | grep -o 'ahead [[:digit:]]\+' | grep -o '[[:digit:]]\+')"
    behindN="$(echo "$stat" | grep -o 'behind [[:digit:]]\+' | grep -o '[[:digit:]]\+')"
    [ -n "$aheadN" ] && marks+=" $GIT_NEED_PUSH_SYMBOL$aheadN"
    [ -n "$behindN" ] && marks+=" $GIT_NEED_PULL_SYMBOL$behindN"

    local bg; local fg
    fg=$BLACK
    if [ -z "$dirty" ]; then
      bg=$GREEN
    else
      bg=$YELLOW
    fi

    __prompt_block $bg $fg "$ref$marks"
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
    else
      __block_text=''
    fi
  }

  __pwd_block() {
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
    __prompt_block $BLACK_BRIGHT $WHITE_BRIGHT "$pwd"
  }

  # superuser or not, here I go!
  __user_block() {
    # Colours to use
    local fg=$WHITE_BRIGHT
    local bg=$BLUE

    if [[  ! -z "$SSH_CLIENT" ]]; then
      local show_host="y"
      bg=$GREEN
    fi

    if [ -z "$(id -u "$USER")" ]; then
      bg=$RED
    fi

    if [[ ! -z "${SHOW_USER+x}" && "$DEFAULT_USER" != "$(whoami)" ]]; then
      local show_user="y"
    fi

    local text
    if [ ! -z ${show_user+x} ]; then
      text+="$BOLD$(whoami)"
    fi
    if [ ! -z ${show_host+x} ]; then
      if [ ! -z ${text+x} ]; then
        text+="@"
      fi
      text+="\h"
    fi

    if [ ! -z ${text+x} ]; then
      __prompt_block $bg $fg $text
    fi
  }

  __status_block() {
    local text
    if [ $exit_code != 0 ]; then
      __prompt_block $BLACK $RED '✘'
      text+=$__block_text
    fi

    if [ "$(id -u "$USER")" == 0 ]; then
      __prompt_block $BLACK $YELLOW '⚡'
      text+=$__block_text
    fi

    if [ "$(jobs -l | wc -l)" != 0 ]; then
      __prompt_block $BLACK $CYAN '⚙'
      text+=$__block_text
    fi

    if [ ! -z "$text" ]; then
      __block_text=$text
    else
      __block_text=''
    fi
  }

  # Build the prompt
  prompt() {
    # I don't like bash; execute first to capture correct status code
    local exit_code=$?
    $(history -a ; history -n)

    last_bg=''

    PS1=''

    __status_block
    PS1+=$__block_text

    __virtualenv_block
    PS1+=$__block_text

    __user_block
    PS1+=$__block_text

    __pwd_block
    PS1+=$__block_text

    __git_block
    PS1+=$__block_text

    __end_block
    PS1+=$__block_text
  }

  PROMPT_COMMAND=prompt
}

__powerline
unset __powerline
