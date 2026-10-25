# Termux / Android deployment runbook

Operational guide for running LearnHarness headless on Android/arm64 under
Termux, supervised by runit, and reachable from other devices on the LAN.

- Last verified: **2026-10-26**, patch base commit `0795ef1`.
- Current branch: `termux-mobile-setup` at `97a6f34` (code patches already
  committed; docs are added by `0004`).
- Companion history/decision log: [`termux-mobile-notes.md`](termux-mobile-notes.md).
- Patch install guide: [`../patches/README.md`](../patches/README.md).
- Quick path: [`../TERMUX.md`](../TERMUX.md) and `scripts/termux/install.sh`.
- Desktop/Electron releases are separate: [`desktop-release.md`](desktop-release.md).

The quickest setup on the current branch is the installer:

```sh
sh scripts/termux/install.sh
```

The manual patch/build/service sequence below is the reference path for a clean
`0795ef1` checkout and for understanding what the scripts do.

## What is running

| Piece | Value |
|---|---|
| Host | Android/arm64, Termux |
| Runtime | Node 26.3.1, npm 11.17.0 |
| Framework | Next.js 16.3.2, webpack production build |
| Server | `next start -H 0.0.0.0 -p 3000` from the repo-root `.next` |
| Supervisor | runit via `termux-services` |
| Service dir | `$PREFIX/var/service/learnharness` |
| Logs | `$PREFIX/var/log/sv/learnharness/current` |
| LAN address used here | `http://192.168.0.10:3000` |
| Auth | none; trusted-LAN use only |

The service serves the normal web app and the production-only PWA shell. It
does not use `next start`'s standalone server, even though
`next.config.ts` has `output: "standalone"`.

## Verified state

The production build completed successfully on 2026-10-26:

- webpack compile: ~94 s
- TypeScript: ~25 s
- static generation: ~1.3 s
- total build: ~7–8 minutes including tracing
- `.next`: ~850 MB; `.next/standalone`: ~118 MB

These returned 200 after the restart:

```text
/
/chat/new
/api/graph
/api/keys
/api/settings/prompts
/manifest.webmanifest
/sw.js
/icons/icon-192.png
/icons/icon-512.png
/icons/icon-maskable-512.png
```

`/settings` returned 307 to `/chat/new`, as expected. Both
`http://127.0.0.1:3000` and `http://192.168.0.10:3000` returned 200.

## Why the build is webpack-only

Turbopack has no native bindings for Android/arm64:

```text
Error: Turbopack is not supported on this platform (android/arm64)
because native bindings are not available.
```

Therefore:

- `next dev` and `next build` must be given `--webpack`.
- `npm run dev` does not work on this device.
- The production command is `npm run build -- --webpack`.
- The service serves a production build, not a dev server.

`next dev --webpack` is the only dev-server option on this platform, but it is
not used by the service and is not part of the verified deployment.

## Why runit execs Next directly

The unit runs:

```sh
exec node node_modules/next/dist/bin/next start -H 0.0.0.0 -p 3000
```

It does **not** run `npm start`. npm does not forward SIGTERM to its child
reliably, so an `sv restart` could leave the old `next-server` alive and holding
port 3000. Directly exec'ing the Next CLI keeps the supervised process and the
listening process the same.

The unit also takes a Termux wake lock and logs through `svlogd -tt`.

## The standalone warning is benign here

`next start` prints:

```text
"next start" does not work with "output: standalone" configuration.
Use "node .next/standalone/server.js" instead.
```

This deployment intentionally serves the repo-root `.next`. That keeps `ROOT`,
`data/`, `auth.json`, and the prompt assets resolving the way the app expects.
Do not switch to `.next/standalone/server.js` without re-checking every
path/config resolution.

## Prerequisites

Termux packages: `nodejs` (26.x), `npm`, `termux-services`, `termux-tools`.

```sh
command -v sv termux-wake-lock service-daemon
```

`runsvdir` must be running. A normal interactive Termux shell starts it through
`$PREFIX/etc/profile.d/start-services.sh`, which also exports `SVDIR` and
`LOGDIR`. For non-interactive shells:

```sh
export SVDIR="$PREFIX/var/service"
export LOGDIR="$PREFIX/var/log"
```

## Fresh install

### 1. Apply the patches

From a clean checkout at the patch base commit (`0795ef1`):

```sh
cd /data/data/com.termux/files/home/learning/learnharness

# Unzip the bundle at the repo root so patches/ sits next to package.json.
unzip -o /path/to/learnharness-termux-mobile-patches.zip -d .
sha256sum -c patches/SHA256SUMS

git apply --check patches/0001-core-barrel-browser-safe.patch
git apply --check --binary patches/0003-mobile-pwa-shell.patch
git apply --check patches/0004-termux-mobile-docs.patch

git apply patches/0001-core-barrel-browser-safe.patch
git apply --binary patches/0003-mobile-pwa-shell.patch
git apply patches/0004-termux-mobile-docs.patch
```

`0003` contains binary PNG icons; `--binary` is required. `0004` is the
documentation-only patch and goes after `0003`; it does not require a rebuild.

On the current `termux-mobile-setup` branch (`97a6f34`+), `0001` and `0003` are
already committed. Do not reapply them; apply only `0004`:

```sh
git apply --check patches/0004-termux-mobile-docs.patch
git apply patches/0004-termux-mobile-docs.patch
```

### 2. Install the runit units

```sh
export SVDIR="$PREFIX/var/service"
export LOGDIR="$PREFIX/var/log"

# The unit is a complete replacement. Keep custom edits elsewhere.
sv down learnharness 2>/dev/null || true
rm -rf "$SVDIR/learnharness"

patch -p1 -d "$SVDIR" < patches/0002-termux-runit-service.patch
chmod 755 "$SVDIR/learnharness/run" "$SVDIR/learnharness/log/run"
```

`run` hardcodes the checkout path:

```sh
cd /data/data/com.termux/files/home/learning/learnharness || exit 1
```

Edit that line if the repo lives elsewhere.

### 3. Install dependencies and build

Stop the service before building; `next build` rewrites `.next` underneath a
running server.

```sh
cd /data/data/com.termux/files/home/learning/learnharness
sv down learnharness 2>/dev/null || true

ELECTRON_SKIP_BINARY_DOWNLOAD=1 npm install --no-audit --no-fund

# Required on Android/arm64. Do not drop --webpack.
rm -rf .next
NEXT_TELEMETRY_DISABLED=1 NODE_OPTIONS=--max-old-space-size=3072 \
  npm run build -- --webpack
```

The first build is slow. The Next process prints `Compiled successfully`,
`Finished TypeScript`, and the route table before exiting 0.

### 4. Start the service

```sh
export SVDIR="$PREFIX/var/service"
sv up learnharness
sv status learnharness
```

`runsvdir` rescans the service directory every few seconds. If `sv` says the
service is not supervised yet, wait and run `sv up learnharness` again.

If the old process is stuck in `got TERM` and port 3000 stays closed:

```sh
SVDIR="$PREFIX/var/service" sv kill learnharness
sleep 3
SVDIR="$PREFIX/var/service" sv status learnharness
```

## Verify

```sh
for p in / /manifest.webmanifest /sw.js \
         /icons/icon-192.png /icons/icon-512.png /icons/icon-maskable-512.png; do
  curl -sS -o /dev/null -w "%{http_code} %{content_type}  $p\n" \
    "http://127.0.0.1:3000$p"
done

curl -sS -o /dev/null -w 'lan %{http_code}\n' http://192.168.0.10:3000/
```

Expected: all 200; the manifest is `application/manifest+json`; the icons are
valid 192×192, 512×512, and maskable 512×512 PNGs.

Check the rendered shell:

```sh
curl -sS http://127.0.0.1:3000/ | grep -oE \
  '<meta[^>]+(viewport|theme-color)[^>]*>|<link[^>]+manifest[^>]*>'
```

It should include `viewport-fit=cover`, `interactive-widget=resizes-content`,
`theme-color #141414`, and the manifest link.

Check the built CSS:

```sh
grep -R -- '--lh-ui-scale:.8' .next/static/css
grep -R -- 'lh-dock-fit' .next/static/css
grep -R -- 'pointer:coarse' .next/static/css
```

The compact media block is `@media (max-width: 927px)` and is gated by
`html:not(.lh-electron)`.

## Phone UI and PWA

### Compact layout

At browser widths ≤927 px (and not Electron):

- the UI scale is `0.8×`;
- the sidebar becomes a fixed overlay drawer, closed by default;
- navigation, Escape, or a backdrop tap closes the drawer;
- safe-area insets are paid by the app frame and by the fixed drawer;
- form controls stay at 16 px to prevent Chrome Android focus zoom;
- coarse-pointer targets shrink from 44 px to about 35 px with the scale.

The dock fit is active only while a question is pending or a practice problem
is active. The overlay is capped to the conversation column; the
question/options area scrolls, while confidence, answer, and stats rows stay
pinned. Desktop and Electron layouts are not given this fit chain.

### Install as a PWA

On the phone, open **`http://localhost:3000`** in Chrome and use “Install app” /
“Add to Home screen”.

A service worker requires a secure context:

- `http://localhost:3000` on the phone itself qualifies.
- `http://192.168.0.10:3000` does **not** qualify (plain HTTP on a LAN IP).
- HTTPS would make the LAN address installable.

The service worker is deliberately pass-through. It exists so Chrome can
upgrade the manifest into a WebAPK; it caches nothing. Do not add caching without
a versioned invalidation story, because the production build is replaced in
place.

The manifest uses `display: standalone`, `#141414` theme/background, and the
three generated icons. Registration is production-only.

## Rebuild / restart loop

```sh
SVDIR="$PREFIX/var/service" sv down learnharness

NEXT_TELEMETRY_DISABLED=1 NODE_OPTIONS=--max-old-space-size=3072 \
  npm run build -- --webpack

SVDIR="$PREFIX/var/service" sv up learnharness
SVDIR="$PREFIX/var/service" sv status learnharness
```

Use `sv kill learnharness` if an old next-server survives `sv down`.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Turbopack is not supported...` | Android/arm64 has no Turbopack bindings | Use `--webpack` |
| Webpack `UnhandledSchemeError` for `node:crypto` | `src/core/index.ts` re-exported `coverage.ts` into the client barrel | Apply `0001`; keep the re-export removed |
| Service is down, port 3000 closed | Old next-server stuck in `got TERM` | `sv kill learnharness`, then `sv status` |
| Service not supervised | `runsvdir` has not rescanned | Wait a few seconds, `sv up learnharness` |
| PWA install option missing | Not a secure context | Use `http://localhost:3000` or HTTPS |
| Input focus zooms the page | Control font below 16 px | Keep the `max(16px, 1em)` floor |
| LAN device cannot connect | Wi-Fi client isolation / guest network | Check network isolation; `0.0.0.0` is already bound |
| `next start` standalone warning | `output: "standalone"` with repo-root `.next` | Benign; do not switch server entrypoints blindly |
| Logs needed | — | `$PREFIX/var/log/sv/learnharness/current` |

## Security

**There is no login.** Anyone who can reach port 3000 can read chats, the graph,
and settings, add/remove provider keys, and spend against the configured provider
key. This is a trusted-home-LAN setup.

- Do not port-forward it.
- Do not put it on an untrusted network.
- For protection, put it behind an authenticated reverse proxy or bind back to
  `127.0.0.1`.
- In browser mode, API access is not gated when `LH_DESKTOP_API_SECRET` is
  unset; the LAN exposure matters.

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

The rollback does not touch `auth.json` or `data/`.

## Current-device paths

```text
repo        /data/data/com.termux/files/home/learning/learnharness
service     /data/data/com.termux/files/usr/var/service/learnharness
logs        /data/data/com.termux/files/usr/var/log/sv/learnharness/current
patch zip   /data/data/com.termux/files/home/learning/learnharness/dist/learnharness-termux-mobile-patches.zip
```

The `dist/` copy is gitignored.

## References

- [`patches/README.md`](../patches/README.md) — patch-by-patch install guide.
- [`termux-mobile-notes.md`](termux-mobile-notes.md) — why these choices were
  made, the full change inventory, and known limitations.
- [`development.md`](development.md) — general development commands.
- [`desktop-release.md`](desktop-release.md) — desktop packaging/release flow.
