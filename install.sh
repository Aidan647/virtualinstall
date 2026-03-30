#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/Aidan647/virtualinstall"
INSTALL_DIR="${HOME}/.local/share/virtualinstall"
BIN_DIR="${HOME}/.local/bin"
LAUNCHER_PATH="${BIN_DIR}/virtualinstall"
RC_MARKER_START="# >>> virtualinstall >>>"
RC_MARKER_END="# <<< virtualinstall <<<"

fail() {
  echo "error: $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

sync_repo() {
  mkdir -p "${HOME}/.local/share"

  if [[ -d "${INSTALL_DIR}/.git" ]]; then
    echo "Repository already exists at ${INSTALL_DIR}"

    if git -C "${INSTALL_DIR}" diff --quiet && git -C "${INSTALL_DIR}" diff --cached --quiet; then
      echo "Updating repository..."
      git -C "${INSTALL_DIR}" pull --ff-only
    else
      echo "Local changes detected in ${INSTALL_DIR}; skipping pull." >&2
      echo "Commit/stash your changes there, then re-run installer to update." >&2
    fi
  elif [[ -d "${INSTALL_DIR}" ]]; then
    fail "${INSTALL_DIR} exists but is not a git repository"
  else
    echo "Cloning repository to ${INSTALL_DIR}..."
    git clone "${REPO_URL}" "${INSTALL_DIR}"
  fi
}

install_launcher() {
  mkdir -p "${BIN_DIR}"

  cat > "${LAUNCHER_PATH}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exec "$HOME/.local/share/virtualinstall/build.sh" "$@"
EOF

  chmod +x "${LAUNCHER_PATH}"
  echo "Installed launcher: ${LAUNCHER_PATH}"
}

ensure_rc_block() {
  local rc_file="$1"
  mkdir -p "$(dirname "$rc_file")"
  touch "$rc_file"

  if grep -Fq "${RC_MARKER_START}" "$rc_file"; then
    echo "virtualinstall block already present in ${rc_file}"
    return
  fi

  cat >> "$rc_file" <<EOF

${RC_MARKER_START}
# Added by virtualinstall installer.
if [[ ":\$PATH:" != *":\$HOME/.local/bin:"* ]]; then
  export PATH="\$HOME/.local/bin:\$PATH"
fi
alias virtualinstall="\$HOME/.local/bin/virtualinstall"
${RC_MARKER_END}
EOF

  echo "Updated shell rc file: ${rc_file}"
}

prompt_shell_target() {
  echo "Select shell rc file(s) to update:"
  echo "  1) bash (~/.bashrc)"
  echo "  2) zsh (~/.zshrc)"
  echo "  3) other (custom path)"
  echo "  4) bash + zsh"

  local choice
  read -r -p "Enter choice [1-4]: " choice

  case "$choice" in
    1)
      ensure_rc_block "${HOME}/.bashrc"
      ;;
    2)
      ensure_rc_block "${HOME}/.zshrc"
      ;;
    3)
      local custom_rc
      read -r -p "Enter rc file path: " custom_rc
      [[ -n "$custom_rc" ]] || fail "custom rc file path cannot be empty"

      if [[ "$custom_rc" == ~* ]]; then
        custom_rc="${custom_rc/#\~/${HOME}}"
      fi
      ensure_rc_block "$custom_rc"
      ;;
    4)
      ensure_rc_block "${HOME}/.bashrc"
      ensure_rc_block "${HOME}/.zshrc"
      ;;
    *)
      fail "invalid choice: ${choice}"
      ;;
  esac
}

main() {
  require_cmd git

  sync_repo
  install_launcher
  prompt_shell_target

  echo
  echo "Installation complete."
  echo "Open a new shell or source your rc file to use: virtualinstall"
}

main "$@"
