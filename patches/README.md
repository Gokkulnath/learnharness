# LearnHarness on Termux: service + phone/PWA patches

This bundle reproduces the current Termux setup:

- a production Next.js server supervised by runit, bound to `0.0.0.0:3000`;
- the webpack build fix required on Android/arm64;
- the compact phone UI (`0.8×` at ≤927 px), safe-area-aware drawer, and
  questionnaire fit;
- the production-only PWA shell (manifest, icons, pass-through service worker);
- a dated deployment runbook and learnings/change log under `docs/`.

The patches are based on commit `0795ef1`. Apply them to a clean checkout at
that commit (or a tree that matches it). Use `--check` first on any other tree.

> **Source branch / fork artifact:** `termux-mobile-setup` already contains the
> code and docs patches. Do **not** reapply `0001`–`0004` there. The fork
> artifact is `termux-mobile-setup-squashed`, one commit on `main`; do not apply
> the per-file patches to it. If `0001`/`0003` are already applied but the docs
> are not, apply only `0004`.

Verified on: Android/arm64, Termux, Node 26.3.1, npm 11.17.0, Next 16.3.2.
The production build succeeds and both `http://127.0.0.1:3000` and
`http://192.168.0.10:3000` return 200. The manifest, service worker, icons, and
built CSS were checked over HTTP. Visual browser checks were **not** run on the
build device because it has no Chrome/Chromium; see “Phone/PWA verification”.

## Patch contents

| Patch | Apply with | What it does |
|---|---|---|
| `0001-core-barrel-browser-safe.patch` | `git apply` | Removes the browser-unsafe `coverage.ts` re-export from `src/core/index.ts` (it imports `node:crypto`). |
| `0002-termux-runit-service.patch` | `patch -p1` in `$PREFIX/var/service` | Adds `learnharness/run` and `learnharness/log/run`; the run script execs Next directly on `0.0.0.0:3000`. |
| `0003-mobile-pwa-shell.patch` | `git apply --binary` | Adds the compact mobile UI, `0.8×` phone density, dock fit, PWA manifest/icons/service worker, and related touch/safe-area changes. |
| `0004-termux-mobile-docs.patch` | `git apply` | Adds `docs/termux-mobile-deployment.md` and `docs/termux-mobile-notes.md`. Apply after `0003`. |

`0003` contains binary PNG icons; `--binary` is required. `0004` is
documentation-only: it has no effect on the build or service, so no rebuild is
needed for it.

The patches were verified to apply cleanly to a pristine `HEAD` worktree and
reproduce the current files byte-for-byte. `0004` was additionally verified
after `0003`, and reversing `0004` restores the pre-doc tree. `0002` was verified
against an empty directory and against the installed units.

## Fork artifact

`termux-mobile-setup-squashed` is a single commit on `main` containing the full
branch work. Use it when you want one push-ready commit rather than the
per-file patch sequence. The equivalent single diff is generated alongside the
working tree as `dist/termux-mobile-setup-squashed.patch` (gitignored), applied
with `git apply --binary` to a clean `main`. Do not combine it with
`0001`–`0004`.

## Prerequisites

Termux packages: `nodejs` (26.x), `npm`, `termux-services`, `termux-tools`.
`command -v sv termux-wake-lock service-daemon` should all resolve.

`runsvdir` must be running. In a normal Termux shell it is started by
`$PREFIX/etc/profile.d/start-services.sh`; that script also exports `SVDIR` and
`LOGDIR`. For non-interactive shells, export them explicitly:

```sh
export SVDIR="$PREFIX/var/service"
export LOGDIR="$PREFIX/var/log"
```

## Apply the patches

Extract the zip at the repository root so the `patches/` directory sits next to
`package.json`, then work from that root.

On a clean `0795ef1` tree, check and apply the full sequence:

```sh
cd /data/data/com.termux/files/home/learning/learnharness

# If you extracted elsewhere, copy/move the patches/ directory here first.
sha256sum -c patches/SHA256SUMS

git apply --check patches/0001-core-barrel-browser-safe.patch
git apply --check --binary patches/0003-mobile-pwa-shell.patch
git apply --check patches/0004-termux-mobile-docs.patch

git apply patches/0001-core-barrel-browser-safe.patch
git apply --binary patches/0003-mobile-pwa-shell.patch
git apply patches/0004-termux-mobile-docs.patch
```

If `0001`/`0003` are already applied but the docs are not, apply only `0004`:

```sh
git apply --check patches/0004-termux-mobile-docs.patch
git apply patches/0004-termux-mobile-docs.patch
```

`0004` is docs-only and belongs after `0003`. It adds the two reference
documents; it does not change application code, the build, or the service. On
`termux-mobile-setup`, all three patches are already committed. On
`termux-mobile-setup-squashed`, everything is one commit; do not apply any
patch there.

Now install the runit units. This assumes a fresh service directory; remove an
existing unit first if you are replacing one:

```sh
export SVDIR="$PREFIX/var/service"
export LOGDIR="$PREFIX/var/log"

sv down learnharness 2>/dev/null || true
rm -rf "$SVDIR/learnharness"

patch -p1 -d "$SVDIR" < patches/0002-termux-runit-service.patch
chmod 755 "$SVDIR/learnharness/run" "$SVDIR/learnharness/log/run"
```

`run` hardcodes the checkout path in its `cd`:

```sh
cd /data/data/com.termux/files/home/learning/learnharness || exit 1
```

Edit that line if your checkout lives somewhere else.

`runsvdir` rescans the service directory every ~5 s. If `sv` reports the service
is not supervised yet, wait a few seconds and run `sv up learnharness` again.

If `patch` reports “Reversed (or previously applied) patch detected”, stop:
the target already has that patch. Do not force it.

## Install and build

Stop the service before building. `next build` rewrites `.next` under a running
server.

```sh
cd /data/data/com.termux/files/home/learning/learnharness

sv down learnharness 2>/dev/null || true

# Electron is a devDependency whose binary is useless here; skip its download.
ELECTRON_SKIP_BINARY_DOWNLOAD=1 npm install --no-audit --no-fund

# Turbopack cannot run on this platform. Webpack is required.
rm -rf .next
NEXT_TELEMETRY_DISABLED=1 NODE_OPTIONS=--max-old-space-size=3072 \
  npm run build -- --webpack
```

`npm run build` without `-- --webpack` will fail on Android/arm64 with
“Turbopack is not supported on this platform”. The build takes roughly 7–8
minutes on this device and produces `.next` plus `.next/standalone`.

## Start and verify

```sh
export SVDIR="$PREFIX/var/service"
sv up learnharness
sv status learnharness

curl -sS -o /dev/null -w 'local  %{http_code}\n' http://127.0.0.1:3000/
curl -sS -o /dev/null -w 'lan    %{http_code}\n' http://192.168.0.10:3000/
```

If `sv status` shows the old process as `got TERM` and port 3000 is closed,
force the old next-server out once:

```sh
SVDIR="$PREFIX/var/service" sv kill learnharness
sleep 3
SVDIR="$PREFIX/var/service" sv status learnharness
```

Then verify the app and PWA endpoints:

```sh
for p in / /manifest.webmanifest /sw.js \
         /icons/icon-192.png /icons/icon-512.png /icons/icon-maskable-512.png; do
  curl -sS -o /dev/null -w "%{http_code} %{content_type}  $p\n" \
    "http://127.0.0.1:3000$p"
done

# The built CSS should contain the compact scale and dock-fit rules.
grep -R -- '--lh-ui-scale:.8' .next/static/css
grep -R -- 'lh-dock-fit' .next/static/css
```

Expected: all endpoints 200; the manifest is `application/manifest+json`; the
icons are valid PNGs at 192, 512, and maskable-512; the rendered page includes
`viewport-fit=cover`, `interactive-widget=resizes-content`, `theme-color
#141414`, and the manifest link.

The service log is `$PREFIX/var/log/sv/learnharness/current`.

## Phone/PWA verification

Open `http://localhost:3000` **on the phone itself** in Chrome and use
“Install app” / “Add to Home screen”. A service worker requires a secure
context: `http://localhost:3000` qualifies, but `http://192.168.0.10:3000` does
not. The LAN URL still works for normal browsing; it is just not installable
without HTTPS. The worker is deliberately pass-through and caches nothing, so a
rebuilt `.next` is never hidden by a stale shell.

At browser widths ≤927 px (and not Electron), the compact UI uses a `0.8×`
type/spacing/control scale. The drawer starts closed, closes on navigation,
Escape, or backdrop tap, and leaves the stored desktop preference alone. The
questionnaire/practice dock is capped to the conversation column while pending
or practicing; the question/options area scrolls and the confidence/answer/stats
rows stay pinned. Desktop and Electron layouts are unchanged.

Form controls stay at 16px even under the compact scale so Chrome Android does
not zoom the viewport when they are focused. Coarse-pointer targets intentionally
shrink from 44px to about 35px as part of the `0.8×` scale.

This device had no Chrome/Chromium, so the visual drawer, density, long
questionnaire fit, and PWA install still need a real-device browser check.

## Rebuild loop

```sh
SVDIR="$PREFIX/var/service" sv down learnharness
NEXT_TELEMETRY_DISABLED=1 NODE_OPTIONS=--max-old-space-size=3072 \
  npm run build -- --webpack
SVDIR="$PREFIX/var/service" sv up learnharness
```

Use `sv kill learnharness` if an old next-server survives `sv down`.

## Network access

The unit binds `0.0.0.0`, so every interface is served:

- Phone: `http://localhost:3000`
- Other devices on the same Wi-Fi: `http://<phone-ip>:3000`

Find the current address with:

```sh
node -e "console.log(Object.values(require('os').networkInterfaces()).flat().filter(i => i.family === 'IPv4' && !i.internal).map(i => i.address).join('\n'))"
```

Android restricts `/proc/net/dev`, so `ifconfig` can print a permission warning
and omit the address; `os.networkInterfaces()` still sees it. The address changes
with DHCP; `0.0.0.0` follows it automatically. If another device cannot connect,
check for Wi-Fi client isolation (common on guest networks) before suspecting
Android.

## Security warning

**There is no login.** Anyone who can reach port 3000 can read chats, the graph,
and settings, add or remove provider keys, and spend against the configured
provider key. Treat this as a trusted-home-LAN setup: do not port-forward it or
put it on an untrusted network. If you need protection, put it behind a reverse
proxy with authentication, or change `-H 0.0.0.0` back to `-H 127.0.0.1` in the
unit.

## First run

- Open the app and use the sidebar gear (or Ctrl/Cmd+`,`) to add provider keys
  and pick the strong/cheap/vision model slots.
- Keys are written to `auth.json` in the repo root (gitignored, mode 0600).
  API access is **not** gated in browser mode (`desktop-access.ts` allows it when
  `LH_DESKTOP_API_SECRET` is unset) — that is why the LAN exposure matters.

## Caveats

- **`npm run dev` cannot work here** — it is Turbopack. The service serves a
  production build. `next dev --webpack` is the only dev option, untested here.
- **`next start` warns about `output: "standalone"`.** Benign for this setup: it
  serves from the repo-root `.next`, which keeps `ROOT`, `data/`, `auth.json`,
  and the prompt assets correct. Do not switch to
  `node .next/standalone/server.js` without re-checking those paths.
- **After a reboot**, services start when you open a Termux shell
  (`start-services.sh`). Termux:Boot is not installed, so nothing starts before
  that. The unit holds a wake lock; disable Android battery optimization for
  Termux if it still gets killed.
- **No system Chrome on this device**, so the `demo` sub-agent's browser
  verification will fail. PDF/SVG rendering works — the Android arm64
  `@napi-rs/canvas` and `@resvg/resvg-js` binaries load correctly.
- **`next-env.d.ts` is generated.** `next build` rewrites its type imports from
  `.next/dev/types/*` to `.next/types/*`; `next dev` flips them back. It is not
  part of these patches; the build regenerates it.
- **The zip contains patches and reference docs only.** It does not include
  `node_modules`, `.next`, `auth.json`, `data/`, prompts, or logs.

## Rollback

```sh
export SVDIR="$PREFIX/var/service"

sv down learnharness
rm -rf "$SVDIR/learnharness" "$PREFIX/var/log/sv/learnharness"

git apply -R patches/0004-termux-mobile-docs.patch
git apply -R --binary patches/0003-mobile-pwa-shell.patch
git apply -R patches/0001-core-barrel-browser-safe.patch

NEXT_TELEMETRY_DISABLED=1 NODE_OPTIONS=--max-old-space-size=3072 \
  npm run build -- --webpack
```

If `0001`/`0003` are already applied and you only want to remove the docs,
reverse only `0004`; do not reverse committed code patches. On
`termux-mobile-setup-squashed`, reset or revert the one commit instead of
reversing individual patches.

Your data (`auth.json`, `data/`) is not touched by the rollback.
