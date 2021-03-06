#
# Standarized $0 handling
# https://github.com/zdharma/Zsh-100-Commits-Club/blob/master/Zsh-Plugin-Standard.adoc
#
0=${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}
0=${${(M)0:#/*}:-$PWD/$0}
typeset -gA Roundy
Roundy[root]=${0:A:h}

#
# Options
#

# Color definition for Command's Exit Status
: ${ROUNDY_COLORS_FG_EXITSTATUS:=0}
: ${ROUNDY_COLORS_BG_EXITSTATUS:=4}
# Icon definition for Command's Exit Status
: ${ROUNDY_EXITSTATUS_GOOD:=$'\ufadf'}
: ${ROUNDY_EXITSTATUS_BAD:=$'\uf658 '}

# Options and Color definition for Time Execution Command
: ${ROUNDY_COLORS_FG_TEXC:=0}
: ${ROUNDY_COLORS_BG_TEXC:=2}
# Minimal time (in ms) for the Time Execution of Command is displayed in prompt
: ${ROUNDY_TEXC_MIN_MS:=5}

# Color definition for Active user name
: ${ROUNDY_COLORS_FG_USER:=7}
: ${ROUNDY_COLORS_BG_USER:=8}
# Options to override username info
: ${ROUNDY_USER_CONTENT_NORMAL:=" %n "}
: ${ROUNDY_USER_CONTENT_ROOT:=" %n "}

# Color definition for Active directory name
: ${ROUNDY_COLORS_FG_DIR:=4}
: ${ROUNDY_COLORS_BG_DIR:=8}
# Working Directory Info Mode
# Valid choice are : "full", "short", or "dir-only"
: ${ROUNDY_DIR_MODE:="dir-only"}

# Color definition for Git info
: ${ROUNDY_COLORS_FG_GITINFO:=0}
: ${ROUNDY_COLORS_BG_GITINFO:=5}

# Option whether drawing a gap between a prompt
: ${ROUNDY_PROMPT_HAS_GAP:=true}

#
# Get information from active git repo
#
roundy_get_gitinfo() {
  type git &>/dev/null || return

  cd -q "$1"
  local ref=$(git symbolic-ref --quiet HEAD 2>/dev/null) ret=$?

  case $ret in
    128) return ;;  # not a git repo
    0) ;;
    *) ref=$(git rev-parse --short HEAD 2>/dev/null) || return ;; # HEAD is in detached state ?
  esac

  if [[ -n $ref ]]; then
    printf -- '%s' " ${ref#refs/heads/} "
  fi
}

#
# Manage time of command execution
#
roundy_get_texc() {
  (( ROUNDY_TEXC_MIN_MS )) && (( ${Roundy[raw_texc]} )) || return
  local duration=$(( EPOCHSECONDS - ${Roundy[raw_texc]} ))
  if (( duration >= ROUNDY_TEXC_MIN_MS )); then
    # Time converter from pure
    # https://github.com/sindresorhus/pure/blob/c031f6574af3f8afb43920e32ce02ee6d46ab0e9/pure.zsh#L31-L39
    local moment d h m s

    d=$(( duration / 60 / 60 / 24 ))
    h=$(( duration / 60 / 60 % 24 ))
    m=$(( duration / 60 % 60 ))
    s=$(( duration % 60 ))
    (( d )) && moment+="${d}d"
    (( h )) && moment+="${h}h"
    (( m )) && moment+="${m}m"
    moment+="${s}s"

    printf -- '%s' " $moment "
  fi
}

#
# Working Directory Info
#
roundy_get_dir() {
  local dir

  case "$ROUNDY_DIR_MODE" in
    full)
      dir='%~'
      ;;
    short)
      if type sed &>/dev/null; then
        dir=$(print -P '%~' | sed "s#\([^a-z]*[a-z]\)[^/]*/#\1/#g")
      else
        # fallback to full mode when there's no sed
        #
        dir='%~'
      fi
      ;;
    dir-only|*)
      dir='%1~'
      ;;
  esac

  printf -- '%s' " $dir "
}

#
# THE PROMPT
#

roundy_draw_prompts() {
  local cl_open cl_close

  # Symbols
  local char_open=$'\ue0b6'
  local char_close=$'\ue0b4'

  # Left Prompt
  Roundy[lprompt]="%F{${ROUNDY_COLORS_BG_EXITSTATUS}}${char_open}%f%K{${ROUNDY_COLORS_BG_EXITSTATUS}}"
  Roundy[lprompt]+="%F{${ROUNDY_COLORS_FG_EXITSTATUS}}%{%(?|${ROUNDY_EXITSTATUS_GOOD}|${ROUNDY_EXITSTATUS_BAD})%2G%}%f%k"
  if [[ -n "${Roundy[data_texc]}" ]]; then
    Roundy[lprompt]+="%K{${ROUNDY_COLORS_BG_TEXC}}%F{${ROUNDY_COLORS_FG_TEXC}}${Roundy[data_texc]}%f%k"
  fi
  Roundy[lprompt]+="%K{${ROUNDY_COLORS_BG_USER}}%F{${ROUNDY_COLORS_FG_USER}}%(#.${ROUNDY_USER_CONTENT_ROOT}.${ROUNDY_USER_CONTENT_NORMAL})%f%k"
  Roundy[lprompt]+="%F{${ROUNDY_COLORS_BG_USER}}${char_close}%f "

  # Right Prompt
  Roundy[rprompt]="%F{${ROUNDY_COLORS_BG_DIR}}${char_open}%f%K{${ROUNDY_COLORS_BG_DIR}}"
  Roundy[rprompt]+="%F{${ROUNDY_COLORS_FG_DIR}}${Roundy[data_dir]}%f"
  cl_close=${ROUNDY_COLORS_BG_DIR}
  if [[ -n "${Roundy[data_gitinfo]}" ]]; then
    Roundy[rprompt]+="%K{${ROUNDY_COLORS_BG_GITINFO}}%F{${ROUNDY_COLORS_FG_GITINFO}}${Roundy[data_gitinfo]}%f"
    cl_close=${ROUNDY_COLORS_BG_GITINFO}
  fi
  Roundy[rprompt]+="%k%F{${cl_close}}${char_close}%f"

  typeset -g PROMPT=${Roundy[lprompt]}
  typeset -g RPROMPT=${Roundy[rprompt]}
}

roundy_draw_gap() {
  [[ -n ${Roundy[draw_gap]} ]] && print
  [[ $ROUNDY_PROMPT_HAS_GAP == true ]] && Roundy[draw_gap]=1
}

#
# Initialize async
#
roundy_async_init() {
  # Load async library
  async_init 2>/dev/null || {
    source "${Roundy[root]}/lib/async.zsh"
    async_init
  }

  # Setup worker and callback
  async_start_worker roundyworker -n
  async_register_callback roundyworker roundy_async_callback
}

#
# Callback functions for async worker
#
roundy_async_callback() {
  # Set output ($3) callback based on method name ($1)
  Roundy[data_${1/roundy_get_/}]=$3

  # we needs to redraw the whole prompts :(
  roundy_draw_prompts
  zle && zle reset-prompt
}

roundy_preexec() {
  # disable gap when clearing term
  [[ "$1" == (clear|reset) ]] && Roundy[draw_gap]=

  # Record Time of execution for roundy_get_texc
  Roundy[raw_texc]=$EPOCHSECONDS
}

roundy_precmd() {
  Roundy[data_dir]=$(roundy_get_dir)
  Roundy[data_texc]=$(roundy_get_texc)
  # Check for async worker availability, otherwise fallback to primitive-way
  if zpty -t roundyworker &>/dev/null; then
    async_job roundyworker roundy_get_gitinfo "$PWD"
  else
    Roundy[data_gitinfo]=$(roundy_get_gitinfo "$PWD")
  fi

  roundy_draw_gap
  roundy_draw_prompts

  # Force-reset raw time execution command
  Roundy[raw_texc]=0
}

#
# Main Setup
#
roundy_main() {
  # Save stuff that will be overrided by the theme
  Roundy[saved_lprompt]=$PROMPT
  Roundy[saved_rprompt]=$RPROMPT
  Roundy[saved_promptsubst]=${options[promptsubst]}
  Roundy[saved_promptbang]=${options[promptbang]}

  # Enable required options and fpath's functions
  setopt prompt_subst
  autoload -Uz add-zsh-hook

  # Needed for showing command time execution
  (( $+EPOCHSECONDS )) || zmodload zsh/datetime

  # Setup Async
  roundy_async_init

  # Setup hooks
  add-zsh-hook preexec roundy_preexec
  add-zsh-hook precmd roundy_precmd
}

#
# Unload function
# https://github.com/zdharma/Zsh-100-Commits-Club/blob/master/Zsh-Plugin-Standard.adoc#unload-fun
#
roundy_plugin_unload() {
  [[ ${Roundy[saved_promptsubst]} == 'off' ]] && unsetopt prompt_subst
  [[ ${Roundy[saved_promptbang]} == 'on' ]] && setopt prompt_bang

  PROMPT=${Roundy[saved_lprompt]}
  RPROMPT=${Roundy[saved_rprompt]}

  add-zsh-hook -D preexec roundy_preexec
  add-zsh-hook -D precmd roundy_precmd

  unfunction \
    roundy_async_init \
    roundy_async_callback \
    roundy_draw_gap \
    roundy_draw_prompts \
    roundy_get_dir \
    roundy_get_gitinfo \
    roundy_get_txec \
    roundy_precmd \
    roundy_preexec \
    roundy_main

  unset \
    ROUNDY_COLORS_BG_DIR \
    ROUNDY_COLORS_BG_EXITSTATUS \
    ROUNDY_COLORS_BG_GITINFO \
    ROUNDY_COLORS_BG_TEXC \
    ROUNDY_COLORS_BG_USER \
    ROUNDY_COLORS_FG_DIR \
    ROUNDY_COLORS_FG_EXITSTATUS \
    ROUNDY_COLORS_FG_GITINFO \
    ROUNDY_COLORS_FG_TEXC \
    ROUNDY_COLORS_FG_USER \
    ROUNDY_EXITSTATUS_BAD \
    ROUNDY_EXITSTATUS_GOOD \
    ROUNDY_EXITSTATUS_ICONFIX \
    ROUNDY_PROMPT_HAS_GAP \
    ROUNDY_TEXC_MIN_MS \
    ROUNDY_USER_CONTENT_NORMAL \
    ROUNDY_USER_CONTENT_ROOT \
    Roundy

  unfunction $0
}

roundy_main "$@"
