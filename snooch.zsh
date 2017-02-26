#!/usr/bin/env zsh

# Snooch
# by Bob Soppe
# https://github.com/bobsoppe/snooch
# MIT License

# Largely based on Pure by Sindre Sorhus <https://github.com/sindresorhus/pure>

prompt_snooch_git_branch() {
  # get the current git status
  local branch git_dir_local rtn

  branch=$(git status --short --branch -uno --ignore-submodules=all | head -1 | awk '{print $2}' 2>/dev/null)
  git_dir_local=$(git rev-parse --git-dir)

  # remove reference to any remote tracking branch
  branch=${branch%...*}

  # check if HEAD is detached
  if [[ -d "${git_dir_local}/rebase-merge" ]]; then
    branch=$(git status | head -5 | tail -1 | awk '{print $6}')
    rtn="rebasing interactively → ${branch//([[:space:]]|\')/}"

    elif [[ -d "${git_dir_local}/rebase-apply" ]]; then
    branch=$(git status | head -2 | tail -1 | awk '{print $6}')
    rtn="rebasing → ${branch//([[:space:]]|\')/}"

    elif [[ -f "${git_dir_local}/MERGE_HEAD" ]]; then
    branch=$(git status | head -1 | awk '{print $3}')
    rtn="merging → ${branch//([[:space:]]|\')/}"

    elif [[ "$branch" = "HEAD" ]]; then
    commit=$(git status HEAD -uno --ignore-submodules=all | head -1 | awk '{print $4}' 2>/dev/null)

    if [[ "$commit" = "on" ]]; then
      rtn="no branch"
    else
      rtn="detached@$commit"
    fi
  else
    rtn="$branch"
  fi

  print "$rtn"
}

prompt_snooch_git_repo_status() {
  # do a fetch asynchronously
  git fetch > /dev/null 2>&1 &!

  local clean
  local message_git
  local count
  local up
  local down

  touched="$(git status --porcelain 2>/dev/null)"
  staged="$(git diff --cached --no-ext-diff 2>/dev/null)"
  dirty="$(git diff --no-ext-diff 2>/dev/null)"

  if [[ $touched != "" ]]; then
    if [[ $staged != "" ]]; then
      if [[ $dirty != "" ]]; then
        message_git="[±]"
      else
        message_git="[+]"
      fi
    else
      message_git="[?]"
    fi
  fi

  # check if there is an upstream configured for this branch
  if command git rev-parse --abbrev-ref @'{u}' &>/dev/null; then
    # check git left and right arrow_status
    count="$(command git rev-list --left-right --count HEAD...@'{u}' 2>/dev/null)"

    # get the push and pull counts
    up="$count[(w)1]"
    down="$count[(w)2]"

    [[ $message_git != "" ]] && message_git+=" "
    [[ $up > 0 ]] && message_git+="⇡"
    [[ $down > 0 ]] && message_git+="⇣"
  fi

  print $message_git
}

prompt_snooch_precmd() {
  local prompt_snooch_preprompt git_root current_path branch repo_status

  # ensure prompt starts on a new line
  prompt_snooch_preprompt="\n"

  # username
  prompt_snooch_preprompt+="%{$fg[red]%}%n%{$reset_color%} "

  # hostname
  prompt_snooch_preprompt+="at "
  prompt_snooch_preprompt+="%{$fg[yellow]%}$HOST%{$reset_color%} "

  # directory
  prompt_snooch_preprompt+="in "
  prompt_snooch_preprompt+="%{$fg[green]%}%~%{$reset_color%} "

  # git status
  if command git rev-parse --is-inside-work-tree &>/dev/null; then
    branch=$(prompt_snooch_git_branch)
    repo_status=$(prompt_snooch_git_repo_status)

    prompt_snooch_preprompt+="on "
    prompt_snooch_preprompt+="%{$fg[blue]%}$branch $repo_status%{$reset_color%} "
  fi

  print -P $prompt_snooch_preprompt

  # reset value since `preexec` isn't always triggered
  unset cmd_timestamp
}

prompt_snooch_preexec() {
  # shows the current dir and executed command in the title when a process is active
  print -Pn "\e]0;"
  echo -nE "$PWD:t: $2"
  print -Pn "\a"
}

prompt_snooch_nice_exit_code() {
  local exit_status="${1:-$(print -P %?)}";

  # nothing to do here
  [[ ${SNOOCH_SHOW_EXIT_CODE:=0} != 1 || -z $exit_status || $exit_status == 0 ]] && return;

  local sig_name;

  # is this a signal name (error code = signal + 128) ?
  case $exit_status in
    129)  sig_name=HUP ;;
    130)  sig_name=INT ;;
    131)  sig_name=QUIT ;;
    132)  sig_name=ILL ;;
    134)  sig_name=ABRT ;;
    136)  sig_name=FPE ;;
    137)  sig_name=KILL ;;
    139)  sig_name=SEGV ;;
    141)  sig_name=PIPE ;;
    143)  sig_name=TERM ;;
  esac

  # usual exit codes
  case $exit_status in
    -1)   sig_name=FATAL ;;
    1)    sig_name=WARN ;;
    2)    sig_name=BUILTINMISUSE ;;
    126)  sig_name=CCANNOTINVOKE ;;
    127)  sig_name=CNOTFOUND ;;
  esac

  echo "$ZSH_PROMPT_EXIT_SIGNAL_PREFIX${exit_status}:${sig_name:-$exit_status}$ZSH_PROMPT_EXIT_SIGNAL_SUFFIX";
}

prompt_snooch_prompt() {
  # red if the previous command didn't exit with 0
  print "%(?.%{$fg[green]%}.%{$fg[red]%}$(prompt_snooch_nice_exit_code))❯%{$reset_color%}   "
}

prompt_snooch_setup() {
  # prevent percentage showing up if output doesn't end with a newline
  export PROMPT_EOL_MARK=""

  zmodload zsh/datetime
  autoload -Uz add-zsh-hook

  add-zsh-hook precmd prompt_snooch_precmd
  add-zsh-hook preexec prompt_snooch_preexec

  PROMPT="$(prompt_snooch_prompt)"
}

prompt_snooch_setup "$@"
