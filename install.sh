#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/Aidan647/virtualinstall"
INSTALL_DIR="${HOME}/.local/share/virtualinstall"
BIN_DIR="${HOME}/.local/bin"
LAUNCHER_PATH="${BIN_DIR}/virtualinstall"
RC_MARKER_START="# >>> virtualinstall >>>"
RC_MARKER_END="# <<< virtualinstall <<<"
UPDATED_RC_FILES=()

fail() {
  echo "error: $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

require_runtime_cmds() {
  local cmd
  for cmd in dpkg-deb apt-cache sha256sum sed tr mktemp; do
    require_cmd "$cmd"
  done
}

prompt_input() {
  local var_name="$1"
  local prompt_text="$2"

  if [[ -r /dev/tty ]]; then
    read -r -p "$prompt_text" "$var_name" < /dev/tty
    return
  fi

  fail "no interactive tty available; set installer env vars instead"
}

minimize_repo() {
  if [[ -d "${INSTALL_DIR}/.git" ]]; then
    git -C "${INSTALL_DIR}" reflog expire --expire=now --all >/dev/null 2>&1 || true
    git -C "${INSTALL_DIR}" gc --prune=now --quiet >/dev/null 2>&1 || true
  fi
}

sync_repo() {
  mkdir -p "${HOME}/.local/share"

  if [[ -d "${INSTALL_DIR}/.git" ]]; then
    echo "Repository already exists at ${INSTALL_DIR}"

    if git -C "${INSTALL_DIR}" diff --quiet && git -C "${INSTALL_DIR}" diff --cached --quiet; then
      echo "Updating repository..."
      git -C "${INSTALL_DIR}" pull --ff-only --depth=1
      minimize_repo
    else
      echo "Local changes detected in ${INSTALL_DIR}; skipping pull." >&2
      echo "Commit/stash your changes there, then re-run installer to update." >&2
    fi
  elif [[ -d "${INSTALL_DIR}" ]]; then
    fail "${INSTALL_DIR} exists but is not a git repository"
  else
    echo "Cloning repository to ${INSTALL_DIR}..."
    git clone --depth=1 --single-branch "${REPO_URL}" "${INSTALL_DIR}"
    minimize_repo
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
    UPDATED_RC_FILES+=("$rc_file")
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
  UPDATED_RC_FILES+=("$rc_file")
}

print_next_steps() {
  local rc_file

  echo
  echo "Installation complete."
  echo "You can run it immediately with:"
  echo "  ${LAUNCHER_PATH} --help"

  if [[ ":$PATH:" == *":${BIN_DIR}:"* ]]; then
    echo "Your PATH already includes ${BIN_DIR}."
    echo "Command should already work:"
    echo "  virtualinstall --help"
  else
    echo "To enable 'virtualinstall' command in this shell, run:"
    for rc_file in "${UPDATED_RC_FILES[@]}"; do
      echo "  source ${rc_file}"
    done
    echo "Then run:"
    echo "  virtualinstall --help"
  fi
}

prompt_shell_target() {
  echo "Select shell rc file(s) to update:"
  echo "  1) bash (~/.bashrc)"
  echo "  2) zsh (~/.zshrc)"
  echo "  3) other (custom path)"
  echo "  4) bash + zsh"

  local choice
  choice="${INSTALL_SHELL_CHOICE:-}"
  if [[ -z "$choice" ]]; then
    prompt_input choice "Enter choice [1-4]: "
  fi

  case "$choice" in
    1)
      ensure_rc_block "${HOME}/.bashrc"
      ;;
    2)
      ensure_rc_block "${HOME}/.zshrc"
      ;;
    3)
      local custom_rc
      custom_rc="${INSTALL_CUSTOM_RC:-}"
      if [[ -z "$custom_rc" ]]; then
        prompt_input custom_rc "Enter rc file path: "
      fi
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
  require_runtime_cmds

  sync_repo
  install_launcher
  prompt_shell_target
  print_next_steps
}

main "$@"
