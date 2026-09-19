# Platform support

`watch-cli` works on any platform `yt-dlp` understands. The table below
covers the ones we have explicitly tested and the cookie tier they need.
"Auto browser" means `WATCH_BROWSER=auto` (opt-in; never read by default).

| Platform | No cookie | Auto browser | Manual `--cookies` |
|---|---|---|---|
| **YouTube** (public) | ✅ | — | — |
| **YouTube** (members-only) | ❌ | ✅ | ✅ |
| **TikTok** (public) | ✅ | — | — |
| **Reddit** (public posts) | ✅ | — | — |
| **Vimeo** (public) | ✅ | — | — |
| **X / Twitter** (public posts) | ✅ | — | — |
| **X / Twitter** (sensitive / blocked accounts) | ❌ | ✅ | ✅ |
| **LinkedIn** (most posts) | ❌ | ✅ | ✅ |
| **Facebook** (public pages) | ✅ | — | — |
| **Facebook** (groups, private posts) | ❌ | ✅ | ✅ |
| **Instagram** (public reels) | ⚠️ inconsistent | ✅ | ✅ |
| **Patreon** (paid) | ❌ | ✅ | ✅ |

Legend: ✅ works · ❌ blocked · ⚠️ partial · — not needed

## Windows

watch-cli is a Bash CLI and runs on Windows only inside **WSL2** — there is
no native PowerShell/cmd.exe support. Install WSL2 (`wsl --install` from an
elevated PowerShell, reboot if prompted, then open the **Ubuntu** app from
the Start menu), then follow the Linux install instructions in the
[README](../README.md#install) from that Ubuntu terminal.

Two things that trip people up:

- Run `watch` from the Ubuntu/WSL terminal, not from PowerShell or
  cmd.exe — those shells cannot execute Bash scripts directly.
- Install and run watch-cli from inside the WSL filesystem (`~/.watch-cli`,
  the default), not from a Windows drive mounted at `/mnt/c/...`. Files
  under `/mnt/*` go through a Windows/Linux translation layer (DrvFs) that
  is slower and can silently drop the executable bit `chmod +x` sets,
  which breaks the installer's symlink step.
- `WATCH_BROWSER=auto`/`chrome`/`edge` (login-walled videos) does not see
  your Windows browser session — WSL2 runs watch-cli as a Linux process.
  `WATCH_BROWSER=firefox` is the exception: sign in to the platform in
  Firefox on Windows first, and watch-cli auto-detects that profile under
  `/mnt/c/Users/...` with no manual export step. See
  [docs/cookies.md#windows-wsl2](cookies.md#windows-wsl2) for why Firefox
  works this way and Chrome/Edge/Brave don't.

`install.sh` detects a bare Git Bash/MSYS/Cygwin shell (i.e. Windows
without WSL) and refuses to run, printing the WSL2 setup steps instead of
limping through a half-working install.

### Slow or stalled uploads (transcribe / listen / audio-q)

`transcribe`, `listen`, and `audio-q` upload audio to Kyma (or
Groq/Google directly in BYOK mode). On some WSL2 setups that specific
kind of traffic — a large, sustained POST body — is pathologically slow
(10–40 KB/s) or collapses to near-zero mid-transfer, even though
everything else about the machine is fine. The diagnostic signature,
confirmed on one Windows 11 / WSL 2.7 machine:

- PowerShell (native Windows) upload speed to the same test endpoint:
  normal (roughly matching the connection's real bandwidth).
- The same upload from inside WSL2: 10–40 KB/s, often starting fast
  and then stalling repeatedly.
- `/tmp` read/write speed inside WSL2: hundreds of MB/s (rules out
  disk/filesystem — and note `/tmp` is WSL2's own native ext4, not a
  `/mnt/c/...` Windows-mounted path, so DrvFs isn't a factor either).
- A raw TCP test (`iperf3`, no HTTP/TLS/file involved at all) showed
  the same collapse — near-zero throughput, a congestion window stuck
  at a few KB, and a high retransmit count. That rules out curl, HTTP,
  and multipart uploads specifically: it's below the application layer.

**Windows fast, WSL slow, on a large upload specifically** is the
pattern to recognize — it points at WSL2's virtual networking path,
not the Wi-Fi adapter, not the ISP, not Kyma. Confirm with a throwaway
upload test and compare the same test run from PowerShell:

```bash
dd if=/dev/urandom of=/tmp/diag.bin bs=1M count=10
curl -w '\nupload: %{speed_upload} bytes/sec\n' \
  -o /dev/null -F "file=@/tmp/diag.bin" https://httpbin.org/post
```

What was tried, in order, on the machine where this was root-caused:

| Fix attempted | Result |
|---|---|
| `networkingMode=mirrored` in `.wslconfig` | No improvement |
| Lowering the WSL interface MTU (`ip link set dev eth0 mtu 1400`) | Temporary improvement, not a fix |
| Disabling TCP timestamps | ~10 KB/s → ~40 KB/s — better, still bad |
| Disabling checksum offload / RSC (guest and host adapter) | No meaningful improvement |
| `networkingMode=virtioproxy` in `.wslconfig` | **Fixed it outright** |

`%USERPROFILE%\.wslconfig`:

```ini
[wsl2]
networkingMode=virtioproxy
```

Then from PowerShell: `wsl --shutdown`, reopen Ubuntu, and re-run the
`curl` test above to confirm. Try `networkingMode=mirrored` first if
you haven't already — it's the more common fix for WSL2 networking
oddities generally and a smaller change, even though it didn't resolve
this particular case. `virtioproxy` requires a WSL version that
supports it (`wsl --version`).

The general lesson, independent of the specific fix: when native
Windows networking is healthy but sustained WSL TCP traffic collapses,
changing WSL's networking backend is often more effective than tuning
Linux-side TCP settings, MTU, or NIC offload flags one at a time.

## Tested versions

This matrix was last verified against:

- `yt-dlp` 2024.12.x (any recent build is fine)
- Linux Debian 12, Windows 11 (WSL2, Ubuntu 22.04/24.04)

If a platform fails on your machine, first run:

```bash
yt-dlp -U   # update yt-dlp to latest
```

Most platform breakages are fixed by a `yt-dlp` update — the project
ships fast (often weekly) for new platform changes.

## Adding a new platform

There's nothing to add. Any URL `yt-dlp` supports works in `watch-cli`
out of the box. The full list of 1,800+ supported sites lives at
[yt-dlp/supportedsites.md](https://github.com/yt-dlp/yt-dlp/blob/master/supportedsites.md).

## Breakage and recovery

`watch-cli` is a thin wrapper around `yt-dlp`. If a platform stops
working — a YouTube URL that downloaded yesterday returns 403 today,
or a TikTok URL hangs forever — the breakage is almost always a
`yt-dlp` extractor that the upstream platform has changed under.

Recovery is two steps:

1. **`yt-dlp -U`** — pulls the latest extractor patch. The project
   ships fast (often weekly) for platform changes. Most reported
   breakages are fixed within 24–72 hours of someone filing the issue.
2. **Check the issue tracker.** If `-U` didn't help, the breakage may
   be in flight: search
   [github.com/yt-dlp/yt-dlp/issues](https://github.com/yt-dlp/yt-dlp/issues)
   for the platform tag (`[youtube]`, `[tiktok]`, `[linkedin]`, …).
   An existing open issue means the fix is being worked; subscribe and
   wait. No issue means file one.

`watch-cli` runs a lightweight upstream probe before each download (a
`yt-dlp --simulate` against a known-stable canary URL per platform,
result cached 24h). On probe failure it emits a stderr warning
`tag=platform-probe-fail` and proceeds anyway — a stale canary URL is
also a possible cause, and the actual target URL may still work.
