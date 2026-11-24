#!/bin/sh
# Railway start script for SubTrackr.
# 1. Caps Go's CPU and memory use to the service's cgroup limits.
# 2. On every boot, before the web server starts (so before the public port
#    opens), makes sure login is switched on with the admin account from
#    SUBTRACKR_ADMIN_USERNAME / SUBTRACKR_ADMIN_PASSWORD. Upstream ships with
#    login off, which would leave the data open to anyone with the URL.
# 3. Execs the app as PID 1, so a crash exits non-zero and Railway restarts it.
set -eu

DATA_DIR=$(dirname "${DATABASE_PATH:-/app/data/subtrackr.db}")
DB="${DATABASE_PATH:-/app/data/subtrackr.db}"
mkdir -p "$DATA_DIR"

# --- Resource caps (Railway shows the host's CPUs inside a 1 vCPU service) ---
if [ -z "${GOMAXPROCS:-}" ]; then
  cpus=2
  if [ -r /sys/fs/cgroup/cpu.max ]; then
    read -r quota period < /sys/fs/cgroup/cpu.max || true
    if [ "${quota:-max}" != "max" ] && [ -n "${period:-}" ]; then
      cpus=$(( (quota + period - 1) / period ))
    fi
  fi
  [ "$cpus" -lt 1 ] && cpus=1
  [ "$cpus" -gt 4 ] && cpus=4
  export GOMAXPROCS="$cpus"
fi
if [ -z "${GOMEMLIMIT:-}" ] && [ -r /sys/fs/cgroup/memory.max ]; then
  mem=$(cat /sys/fs/cgroup/memory.max)
  if [ "$mem" != "max" ]; then
    export GOMEMLIMIT="$(( mem / 1048576 * 70 / 100 ))MiB"
  fi
fi

# --- Admin login (fail closed: never start an open instance) ---
user="${SUBTRACKR_ADMIN_USERNAME:-admin}"
pass="${SUBTRACKR_ADMIN_PASSWORD:-}"
if [ "${SUBTRACKR_ALLOW_NO_AUTH:-}" != "true" ]; then
  if [ "${#pass}" -lt 12 ]; then
    echo "railway-start: SUBTRACKR_ADMIN_PASSWORD is missing or shorter than 12 characters; refusing to start an unprotected SubTrackr." >&2
    exit 1
  fi
  case "$user" in
    ""|*[!A-Za-z0-9._@-]*)
      echo "railway-start: SUBTRACKR_ADMIN_USERNAME may only contain letters, digits, '.', '_', '@' and '-'." >&2
      exit 1 ;;
  esac

  # Creates the database and runs migrations on first boot, then stores the
  # bcrypt hash. Only re-run when the variable changes (salted fingerprint kept
  # on the volume), so a password reset done by e-mail is not overwritten.
  salt_file="$DATA_DIR/.railway-admin-salt"
  fp_file="$DATA_DIR/.railway-admin-fingerprint"
  umask 077
  [ -s "$salt_file" ] || head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n' > "$salt_file"
  fp=$(printf '%s:%s:%s' "$(cat "$salt_file")" "$user" "$pass" | sha256sum | cut -d' ' -f1)
  if [ ! -s "$fp_file" ] || [ "$(cat "$fp_file")" != "$fp" ] || [ ! -s "$DB" ]; then
    /app/subtrackr --reset-password --new-password "$pass" >/dev/null
    sqlite3 "$DB" "INSERT INTO settings(key,value,created_at,updated_at) VALUES('auth_username','$user',datetime('now'),datetime('now')) ON CONFLICT(key) DO UPDATE SET value=excluded.value, updated_at=datetime('now');"
    printf '%s' "$fp" > "$fp_file"
    echo "railway-start: admin login set for user '$user'."
  fi

  # Login must always be on (the Settings page can switch it off; it comes
  # back on at the next restart unless SUBTRACKR_ALLOW_NO_AUTH=true).
  sqlite3 "$DB" "INSERT INTO settings(key,value,created_at,updated_at) VALUES('auth_enabled','true',datetime('now'),datetime('now')) ON CONFLICT(key) DO UPDATE SET value='true', updated_at=datetime('now');"
  [ "$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='auth_enabled';")" = "true" ] || { echo "railway-start: could not enable login; refusing to start." >&2; exit 1; }
  [ -n "$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='auth_password_hash';")" ] || { echo "railway-start: admin password not stored; refusing to start." >&2; exit 1; }
fi

# --- Base URL (secure cookies, iCal and reset links) on first boot only ---
domain="${RAILWAY_PUBLIC_DOMAIN:-}"
case "$domain" in
  *.*)
    if [ -z "$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='base_url';" 2>/dev/null)" ]; then
      case "$domain" in *[!A-Za-z0-9.-]*) ;; *)
        sqlite3 "$DB" "INSERT INTO settings(key,value,created_at,updated_at) VALUES('base_url','https://$domain',datetime('now'),datetime('now')) ON CONFLICT(key) DO NOTHING;" ;;
      esac
    fi ;;
esac

cd /app
exec /app/subtrackr
