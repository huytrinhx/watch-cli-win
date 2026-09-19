#!/usr/bin/env bash
# Portable hashing for watch-cli.
#
# `shasum` (Perl's App::shasum) is a macOS default but is not guaranteed to
# exist on a bare Linux box — including a fresh WSL2 Ubuntu install, which is
# the supported Windows path (see docs/platforms.md#windows). GNU coreutils'
# sha1sum/sha256sum are always present there instead, so prefer those and
# fall back to shasum, then to python3, so every supported OS has a path.

[[ -n "${WATCH_CLI_HASH_LOADED:-}" ]] && return 0
export WATCH_CLI_HASH_LOADED=1

# Reads stdin, prints its SHA-1 hex digest. Used only to derive short,
# stable cache/id keys (dl-video's mp4 name, extract-frames' /tmp dir,
# transcribe's temp audio name, the archive's record id) — not a security
# boundary, so any available SHA-1 implementation is fine.
watch_hash_sha1_stdin() {
  if command -v sha1sum >/dev/null 2>&1; then
    sha1sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum | awk '{print $1}'
  else
    python3 -c 'import sys, hashlib; print(hashlib.sha1(sys.stdin.buffer.read()).hexdigest())'
  fi
}

# Prints the SHA-256 hex digest of a file. Used by install.sh to verify a
# downloaded tarball/model against a pinned checksum, so correctness (not
# just availability) matters here.
watch_hash_sha256_file() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
  else
    python3 -c 'import sys, hashlib; print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())' "$file"
  fi
}
