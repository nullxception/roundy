#
# Standarized $0 handling
# https://github.com/zdharma/Zsh-100-Commits-Club/blob/master/Zsh-Plugin-Standard.adoc
#
0=${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}
0=${${(M)0:#/*}:-$PWD/$0}
typeset -gA Roundy
Roundy[root]="${0:A:h}"

#
# Options
#

# Color definition for Command's Exit Status
: ${ROUNDY_COLORS_FG_EXITSTATUS:=0}
: ${ROUNDY_COLORS_BG_EXITSTATUS:=4}
# Icon definition for Command's Exit Status
: ${ROUNDY_EXITSTATUS_GOOD:=$'\ufadf'}
: ${ROUNDY_EXITSTATUS_BAD:=$'\uf658'}
# Enable EXITSTATUS workaround glitch
: ${ROUNDY_EXITSTATUS_ICONFIX:=false}

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

# Color definition for Git info
: ${ROUNDY_COLORS_FG_GITINFO:=0}
: ${ROUNDY_COLORS_BG_GITINFO:=5}

#
# Get information from active git repo
#
roundy_get_gitinfo() {
  local ref=$(git symbolic-ref --quiet HEAD 2> /dev/null)

  case $? in
    128) return ;;  # not a git repo
    0) ;;
    *) ref=$(git rev-parse --short HEAD 2> /dev/null) || return ;; # HEAD is in detached state ?
  esac

  if [[ -n $ref ]]; then
    printf " ${ref#refs/heads/} "
  fi
}

#
# Time converter from pure
# https://github.com/sindresorhus/pure/blob/c031f6574af3f8afb43920e32ce02ee6d46ab0e9/pure.zsh#L31-L39
#
roundy_moment() {
  local moment d h m s

  d=$(( $1 / 60 / 60 / 24 ))
  h=$(( $1 / 60 / 60 % 24 ))
  m=$(( $1 / 60 % 60 ))
  s=$(( $1 % 60 ))
  (( d )) && moment+="${d}d "
  (( h )) && moment+="${h}h "
  (( m )) && moment+="${m}m "
  moment+="${s}s"

  printf '%s' "$moment"
}

#
# Manage time of command execution
#
roundy_get_texec() {
  if (( ROUNDY_TEXC_MIN_MS )) && (( ${Roundy[raw_texec]} )); then
    local duration=$(( EPOCHSECONDS - ${Roundy[raw_texec]} ))
    if (( duration >= ROUNDY_TEXC_MIN_MS )); then
      roundy_moment $duration
    fi
  fi
}

#
# THE PROMPT
#

roundy_draw_prompts() {
  local cl_open cl_close

  # Symbols
  local char_open=$'\ue0b6'
  local char_close=$'\ue0b4'

  # NEEDPROPERFIX: Workaround for exitstatus icon glitch
  if $ROUNDY_EXITSTATUS_ICONFIX; then
    local exitstatuswr1="%(?|| )"
    local exitstatuswr2="%(?| |)"
  fi

  # Left Prompt
  Roundy[lprompt]="%F{${ROUNDY_COLORS_BG_EXITSTATUS}}${char_open}%f%K{${ROUNDY_COLORS_BG_EXITSTATUS}}"
  Roundy[lprompt]+="%F{${ROUNDY_COLORS_FG_EXITSTATUS}}%(?|${ROUNDY_EXITSTATUS_GOOD}|${ROUNDY_EXITSTATUS_BAD})$exitstatuswr1%f%k"
  if [[ -n "${Roundy[data_texc]}" ]]; then
    Roundy[lprompt]+="%K{${ROUNDY_COLORS_BG_TEXC}}%F{${ROUNDY_COLORS_FG_TEXC}} ${Roundy[data_texc]} %f%k"
  fi
  Roundy[lprompt]+="%K{${ROUNDY_COLORS_BG_USER}}%F{${ROUNDY_COLORS_FG_USER}}%(#.${ROUNDY_USER_CONTENT_ROOT}.${ROUNDY_USER_CONTENT_NORMAL})%f%k"
  Roundy[lprompt]+="%F{${ROUNDY_COLORS_BG_USER}}${char_close}%f $exitstatuswr2"

  # Right Prompt
  Roundy[rprompt]="%F{${ROUNDY_COLORS_BG_DIR}}${char_open}%f%K{${ROUNDY_COLORS_BG_DIR}}"
  Roundy[rprompt]+="%F{${ROUNDY_COLORS_FG_DIR}} %1~ %f"
  cl_close=${ROUNDY_COLORS_BG_DIR}
  if [[ -n "${Roundy[data_git]}" ]]; then
    Roundy[rprompt]+="%K{${ROUNDY_COLORS_BG_GITINFO}}%F{${ROUNDY_COLORS_FG_GITINFO}}${Roundy[data_git]}%f"
    cl_close=${ROUNDY_COLORS_BG_GITINFO}
  fi
  Roundy[rprompt]+="%k%F{${cl_close}}${char_close}%f"

  typeset -g PROMPT=${Roundy[lprompt]}
  typeset -g RPROMPT=${Roundy[rprompt]}
}

roundy_preexec() {
  # Record Time of execution for roundy_get_texec
  Roundy[raw_texec]=$EPOCHSECONDS
}

roundy_precmd() {
  Roundy[data_git]=$(roundy_get_gitinfo)
  Roundy[data_texc]=$(roundy_get_texec)

  roundy_draw_prompts
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
    roundy_get_gitinfo \
    roundy_moment \
    roundy_precmd \
    roundy_preexec \
    roundy_draw_prompts

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
    ROUNDY_TEXC_MIN_MS \
    Roundy

  unfunction $0
}

#
# Main Setup
#

# Save stuff that will be overrided by the theme
Roundy[saved_lprompt]=$PROMPT
Roundy[saved_rprompt]=$RPROMPT
Roundy[saved_promptsubst]=${options[promptsubst]}
Roundy[saved_promptbang]=${options[promptbang]}

setopt prompt_subst
autoload -Uz add-zsh-hook
(( $+EPOCHSECONDS )) || zmodload zsh/datetime # Needed for showing command time execution
add-zsh-hook preexec roundy_preexec
add-zsh-hook precmd roundy_precmd
