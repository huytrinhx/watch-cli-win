#!/usr/bin/env bash
# Minimal env-file loader, shared by lib/env.sh (audio backend config:
# KYMA_API_KEY, GROQ_API_KEY, GOOGLE_AI_KEY, ...) and any bin/* script
# that just needs a process-env-overridable setting from ./.env or
# ~/.config/watch-cli/env without pulling in lib/env.sh's audio-routing
# decision (bin/watch and bin/dl-video source this directly for
# WATCH_BROWSER, which has nothing to do with audio).
#
# Discovery order: process env (already exported) → ./.env → the config
# file. A value already set wins — a one-off `WATCH_BROWSER=x watch ...`
# always overrides whatever the config file says.

# Not exported — see lib/hash.sh for why an exported guard breaks a
# child process that sources this file again to get its own functions.
[[ -n "${WATCH_CLI_DOTENV_LOADED:-}" ]] && return 0
WATCH_CLI_DOTENV_LOADED=1

_load_dotenv() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  while IFS='=' read -r key value; do
    [[ -z "$key" || "$key" == \#* ]] && continue
    [[ "$key" =~ ^[A-Z_][A-Z0-9_]*$ ]] || continue
    # Don't override values already in the env.
    if [[ -z "${!key:-}" ]]; then
      # Strip surrounding quotes if any.
      value="${value%\"}"
      value="${value#\"}"
      value="${value%\'}"
      value="${value#\'}"
      export "$key=$value"
    fi
  done < "$file"
}

_load_dotenv "./.env"
_load_dotenv "$HOME/.config/watch-cli/env"
