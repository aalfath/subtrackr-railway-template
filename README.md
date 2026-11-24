[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/subtrackr?utm_medium=integration&utm_source=button&utm_campaign=subtrackr)

# SubTrackr on Railway

One-click Railway template for [SubTrackr](https://github.com/bscott/subtrackr), the self-hosted subscription tracker: see what you pay each month and year, get renewal reminders, and track spend by category.

## What it deploys

| Service | What it does |
|---|---|
| **SubTrackr** | The web app and its REST API (Go, SQLite), built from this repo. Public HTTPS domain, health check on `/healthz`, a volume at `/app/data` for the SQLite database. |

- **Version:** SubTrackr `0.7.1`, official image `ghcr.io/bscott/subtrackr:0.7.1@sha256:dc1092d8f9f229cd7980063e3a989402d18f86cb546e45b5b0606e1d32ed153c`.
- **Memory:** about 25 MB in use; fits Railway's Free plan (0.5 GB) with lots of room.

## Login is on from the first boot

Upstream SubTrackr starts with login switched **off**, and its Settings page only lets you switch it on after e-mail (SMTP) is set up. Left like that, anyone who finds the URL could read and change your data. This template's start script (`start.sh`) therefore, on every boot and before the web server opens its port:

1. creates or updates the admin account from `SUBTRACKR_ADMIN_USERNAME` / `SUBTRACKR_ADMIN_PASSWORD`,
2. switches login on (if you switch it off in Settings, it comes back on at the next restart),
3. refuses to start if the password is missing or shorter than 12 characters,
4. sets **Settings → Base URL** to `https://<your Railway domain>` on first boot, so session cookies are `Secure` and iCal and reset links are right.

The password is only re-applied when you change the variable, so a reset done through the app's e-mail link is kept.

## Variables

| Variable | Default | What it is |
|---|---|---|
| `SUBTRACKR_ADMIN_USERNAME` | `admin` | Login name of the admin account. |
| `SUBTRACKR_ADMIN_PASSWORD` | `${{secret(24)}}` | Generated admin password. Read it in the service's **Variables** tab. Change it there to rotate it (min. 12 characters). |
| `PORT` | `8080` | Port the app listens on (Railway routes the public domain to it). |

Optional, add them yourself if you want them:

- `FIXER_API_KEY` (free key from [fixer.io](https://fixer.io/)) or `FIXER_API_URL`: automatic currency conversion.
- E-mail (SMTP), Pushover, Telegram, ntfy, Gotify and webhook reminders, and OpenID Connect login, are set up in the app under **Settings**.

## After deploying

1. Open the public URL and sign in as `admin` with the password from the **Variables** tab.
2. Under **Settings**, pick your currency, add categories, and set up e-mail or push reminders if you want them.
3. For the REST API, create an API key under **Settings → API Keys** and call `https://YOUR-DOMAIN/api/v1/...` with `Authorization: Bearer sk_...`.

## Updates

This template builds from this repository. When we bump the SubTrackr version, Railway shows an "update available" notice on your project, and you choose when to apply it. Read [CHANGELOG.md](CHANGELOG.md) first: breaking changes are listed at the top of each entry. Your data stays on the volume across updates.

## Licence

SubTrackr is AGPL-3.0, by [bscott](https://github.com/bscott/subtrackr). This wrapper only adds a Dockerfile and a start script.
