#!/usr/bin/env bash
# ============================================================================
# clash-for-linux — Bash completion
# ============================================================================

_clash_completions() {
  local cur prev words cword
  _init_completion || return

  local commands="start stop restart reload status update upgrade sub config switch doctor metrics logs secret timer backup help"

  if [[ $cword -eq 1 ]]; then
    COMPREPLY=($(compgen -W "$commands" -- "$cur"))
    return
  fi

  local cmd="${words[1]}"
  case "$cmd" in
    update)
      COMPREPLY=($(compgen -W "core geo" -- "$cur"))
      ;;
    sub|subscription)
      COMPREPLY=($(compgen -W "set get test" -- "$cur"))
      ;;
    config)
      COMPREPLY=($(compgen -W "show edit validate backup restore reload" -- "$cur"))
      ;;
    switch)
      COMPREPLY=($(compgen -W "tun fake-ip redirect" -- "$cur"))
      ;;
    timer)
      COMPREPLY=($(compgen -W "enable disable status" -- "$cur"))
      ;;
    logs)
      COMPREPLY=($(compgen -W "-f --follow" -- "$cur"))
      ;;
    doctor)
      COMPREPLY=($(compgen -W "--fix" -- "$cur"))
      ;;
    backup)
      COMPREPLY=($(compgen -W "restore" -- "$cur"))
      ;;
  esac
}

complete -F _clash_completions clash
