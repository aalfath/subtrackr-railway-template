# Changelog

## 0.7.1 (2026-11-24)

First release of the Railway template.

- SubTrackr 0.7.1, official image pinned by digest (`sha256:dc1092d8…153c`).
- Start script: login is always on with the generated admin password, set before the port opens; refuses to start without a password of 12+ characters.
- Base URL set to the Railway domain on first boot (Secure cookies, correct iCal and reset links).
- Go runtime capped to the service's CPU and memory limits (`GOMAXPROCS`, `GOMEMLIMIT`).
- SQLite database on a Railway volume at `/app/data`; health check on `/healthz`.
