#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/lib/build-common.sh"
source "${SCRIPT_DIR}/lib/build-args.sh"
source "${SCRIPT_DIR}/lib/build-actions.sh"

IMAGE_NAME="${VIRTUALINSTALL_IMAGE:-virtualinstall:latest}"
HOST_OUTPUT_DIR="${PWD}/out"
COMMAND=""
NAME=""
PACKAGES=()
FORCE_REBUILD=0
APT_CMD=""
RESOLVED_APT_CMD=""

main() {
  parse_args "$@"

  case "$COMMAND" in
    create)
      ensure_artifact
      ;;
    install)
      local deb_path
      deb_path="$(ensure_artifact)"
      install_artifact "$deb_path"
      ;;
    remove)
      remove_by_tag
      ;;
    clean)
      clean_artifacts
      ;;
    list)
      list_tags
      ;;
  esac
}

main "$@"
