#!/usr/bin/env bash

# Shared utility helpers.
die() {
  echo "error: $*" >&2
  exit 1
}

sanitize_name() {
  local raw="$1"
  local cleaned

  cleaned="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9.+-]+/-/g; s/^-+//; s/-+$//')"
  if [[ -z "$cleaned" ]]; then
    echo "invalid"
  else
    echo "$cleaned"
  fi
}
