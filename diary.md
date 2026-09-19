# Diary — 2026-09-19

What changed today, from the fork's state at commit `5aced67` (v1.0.1)
through v1.4.0. None of this breaks the v1 output schema — everything
here is a bug fix or an additive change per `docs/releases.md`'s semver
policy — but it's a lot of ground covered in one session, so: a record
of what and why, two or three lines each, in the order it happened.

## Docs: Windows/WSL2 install walkthrough

Added a full step-by-step WSL2 install + Kyma key setup flow to the
README for zero-prior-experience users, plus more `watch`/`transcribe`/
`audio-q` "try it" examples. Not a code change.

## Fixed `watch_hash_sha1_stdin: command not found` on every real `watch` run

`lib/*.sh` guarded double-sourcing with an *exported* flag. `watch`
sources these in its own process, then shells out to
`dl-video`/`extract-frames`/`transcribe` as children — which inherited
the exported flag and skipped re-defining their own copy of the
function, since functions don't survive exec the way exported
variables do. Dropped `export` on all six guards; this had been
silently corrupting the cache-key hash on every non-cached `watch` run.

## Unquoted-`&` detection; automatic WSL2 Firefox cookies

A pasted URL with `&t=45s` etc., typed unquoted, gets truncated by the
shell before `watch` ever sees it. Added a background-job detector that
notices and explains this. Separately, `dl-video` now auto-locates a
signed-in Windows Firefox profile under WSL2
(`/mnt/c/Users/*/.../Firefox/Profiles/`) instead of requiring a manual
cookie export — `WATCH_BROWSER=firefox` just works.

## `WATCH_BROWSER` now honors the config file; yt-dlp errors surfaced

`watch`/`dl-video` never sourced `lib/env.sh`, so `WATCH_BROWSER` in
`~/.config/watch-cli/env` was silently ignored — inconsistent with
`KYMA_API_KEY`. Extracted the dotenv loader into `lib/dotenv.sh`, wired
into both. Also: `dl-video`'s final error message claimed yt-dlp's
output was "above" when it was actually only ever captured to a temp
log and never shown — now it's printed for real.

## Download format selector: prefer merging video+audio

The selector was progressive-only (`best[height<=720]/best`), which
made sense when YouTube commonly served single-file streams at that
resolution. It doesn't any more — most non-360p content is split
video+audio now, so the old selector increasingly resolved to nothing
("Requested format is not available"). `ffmpeg` was already a hard
dependency; there was no reason to avoid the merge.

## New `listen` command; `dl-video --audio-only`

Audio-only counterpart to `watch` — for a transcript-only workflow,
skips the video stream entirely instead of downloading and decoding it
just to throw it away. Shares `watch`'s archive, so `watch-archive`
reads records from either command the same way.

## Fixed `listen`'s missing executable bit

A local git config (`core.fileMode=false`) meant `chmod +x` on the
brand-new `bin/listen` file never got committed — every pre-existing
`bin/*` script kept its mode from before, so only the one genuinely new
file was affected. `git update-index --chmod=+x` fixed it; this had
shipped in v1.3.0 as literally unusable ("Permission denied").

## Platform-probe warning: wrong label, sticky false positives

The pre-flight yt-dlp health-check warning always said `[watch]` even
when `listen` triggered it — hardcoded string, now derived from the
actual caller. More importantly, its 5s timeout was too tight for
YouTube's current multi-step extraction, and a single slow-not-broken
probe got cached as "fail" for 24h, repeating a false alarm on every
run for a day. Raised the timeout, cut the fail-cache TTL to 15m.

## curl error surfacing; stall-tolerant upload timeout

All four API call sites (`transcribe`, `audio-q` × kyma/byok) redirected
curl's own `-sS` error text to `/dev/null`, so a connection-level
failure showed a completely contentless error. Fixed via a live repro:
the same repro revealed a flat 5-minute `--max-time` was killing a
slow-but-working upload at 33% progress with the server just waiting.
Replaced with a stall-based abort (`--speed-limit`/`--speed-time`) plus
a 30-minute outer ceiling.

## WSL2 slow-upload networking lesson, documented

Root-caused live with the user: native Windows uploads were fast, WSL2
uploads to two unrelated hosts both crawled at ~15 KB/s, and a raw
`iperf3` test (no HTTP/curl/file involved) showed the same collapse —
ruling out everything above the network layer. `mirrored` networking,
lower MTU, and disabling checksum offload/RSC each helped little or not
at all; switching WSL's `networkingMode` to `virtioproxy` fixed it
outright. Documented as a diagnostic runbook in `docs/platforms.md`.

## Persistent downloads; partial archive records

`dl-video` cached under `/tmp`, which WSL2 wipes on every restart — a
slow download that then failed at a later step lost the already-fetched
file and had to be re-downloaded from scratch on retry. Moved the cache
to `~/.watch-cli/downloads/` (persistent). Also: `watch`/`listen` now
write a partial archive record right after the download succeeds
(before transcribe even starts) instead of only on full success, so a
failure leaves a resumable, visible trace (`watch-archive ls` tags it
`[partial]`) instead of nothing.

---

Eight releases today: v1.1.0 → v1.4.0. `docs/releases.md`'s own
guardrail (CI checks `lib/version.sh` against the latest tag on every
push to `main`) showed red exactly once, transiently, for the expected
reason — a version-bump commit lands on `main` slightly before its tag
does, and there's no further push to re-trigger the check once the tag
lands. Cosmetic; every actual release published clean.
