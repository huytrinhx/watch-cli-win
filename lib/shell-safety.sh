#!/usr/bin/env bash
# Defensive checks for common shell footguns that silently truncate what
# the user meant to pass in — not correctness logic, just a heads-up.

[[ -n "${WATCH_CLI_SHELL_SAFETY_LOADED:-}" ]] && return 0
WATCH_CLI_SHELL_SAFETY_LOADED=1

# A URL copied straight from a browser often contains an unquoted `&`
# (YouTube's `&t=45s`, UTM/tracking params, playlist indices, …). Typed
# without quotes, bash treats `&` as "background this, then run the rest
# as a separate command" — so only the part before the `&` ever reaches
# argv, and the rest silently runs as a no-op statement. There is no way
# to recover the missing piece from inside the script: by the time we
# run, bash has already split the command line. The best we can do is
# notice we ended up backgrounded and say so.
#
# Detection: a backgrounded job is not in its terminal's foreground
# process group. GNU `ps -o stat=` reports a trailing "+" for a
# foreground-group process; its absence means we were backgrounded.
# Fails open (no warning) if `ps` is missing or its output doesn't look
# like the expected GNU format, rather than risk a false positive.
watch_cli_warn_if_backgrounded() {
  [[ -t 2 ]] || return 0
  command -v ps >/dev/null 2>&1 || return 0
  local stat
  stat="$(ps -o stat= -p $$ 2>/dev/null)" || return 0
  [[ -n "$stat" ]] || return 0
  [[ "$stat" == *+* ]] && return 0
  cat >&2 <<'EOF'
[watch-cli] note: this looks like it's running in the background. If you
pasted a URL containing an unquoted "&" (common in YouTube "&t=" links,
tracking/UTM params, playlist indices, …), your shell split the command
there and only part of the URL went through. Quote the URL and re-run:
    watch "https://example.com/watch?v=xyz&t=45s"
EOF
}
