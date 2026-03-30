#!/usr/bin/env bash

usage() {
  cat <<EOF
Usage:
  build.sh create <name> [--output-dir <host-dir>] [--rebuild-image] -- <pkg1> <pkg2> ...
  build.sh install <name> [--output-dir <host-dir>] [--rebuild-image] [--apt-cmd <cmd>] -- <pkg1> <pkg2> ...
  build.sh remove <name> [--apt-cmd <cmd>]
  build.sh clean [--output-dir <host-dir>]
  build.sh list [name]

Examples:
  build.sh create default -- git ncdu lsd curl wget duf
  build.sh install base --output-dir ./out -- git curl
  build.sh install base --apt-cmd apt-get -- git curl
  build.sh install dev --rebuild-image -- jq ripgrep
  build.sh remove base
  build.sh clean --output-dir ./out
  build.sh list
  build.sh list default

Notes:
  - This is the host wrapper command.
  - It builds/runs Docker image ${IMAGE_NAME}.
  - Container script receives only: <name> <pkg1> [pkg2 ...].
  - Use '--' to separate build options from dependency list.
  - Use '--rebuild-image' to force a fresh Docker image build.
  - APT command selection defaults to: apt-fast, then apt, then apt-get.
  - Use '--apt-cmd <cmd>' to override APT command selection.
  - Generated package is written to host output dir (default: ./out).
  - 'install' builds then installs the generated .deb.
  - 'remove' uninstalls using tag files in /var/lib/virtualinstall/tags/ and prompts when multiple match.
  - 'clean' removes generated .deb files from output dir.
  - 'list' shows installed virtual tag packages (optionally filtered by name).
EOF
}

parse_args() {
  local saw_separator=0

  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi

  COMMAND="${1:-}"
  [[ -n "$COMMAND" ]] || die "expected command: create, install, remove, clean, or list"
  shift

  case "$COMMAND" in
    create|install)
      ;;
    remove)
      ;;
    clean)
      ;;
    list)
      ;;
    *)
      die "unknown command: $COMMAND"
      ;;
  esac

  if [[ "$COMMAND" == "list" ]]; then
    if (($# > 1)); then
      die "list accepts at most one optional name"
    fi

    if (($# == 1)); then
      NAME="$(sanitize_name "$1")"
      [[ "$NAME" != "invalid" ]] || die "invalid name"
    fi
    return
  fi

  if [[ "$COMMAND" == "clean" ]]; then
    while (($#)); do
      case "$1" in
        --output-dir)
          (($# >= 2)) || die "--output-dir requires a value"
          HOST_OUTPUT_DIR="$2"
          shift 2
          ;;
        -h|--help)
          usage
          exit 0
          ;;
        --*)
          die "unknown option: $1"
          ;;
        *)
          die "clean does not accept positional arguments"
          ;;
      esac
    done

    mkdir -p "$HOST_OUTPUT_DIR"
    return
  fi

  (($# >= 1)) || die "expected <name> after $COMMAND"
  NAME="$1"
  NAME="$(sanitize_name "$NAME")"
  [[ "$NAME" != "invalid" ]] || die "invalid name"
  shift

  if [[ "$COMMAND" == "remove" ]]; then
    while (($#)); do
      case "$1" in
        --apt-cmd)
          (($# >= 2)) || die "--apt-cmd requires a value"
          APT_CMD="$2"
          shift 2
          ;;
        -h|--help)
          usage
          exit 0
          ;;
        --*)
          die "unknown option: $1"
          ;;
        *)
          die "remove does not accept positional arguments after <name>"
          ;;
      esac
    done
    [[ -n "$NAME" ]] || die "name must be non-empty"
    return
  fi

  while (($#)); do
    case "$1" in
      --output-dir)
        (($# >= 2)) || die "--output-dir requires a value"
        HOST_OUTPUT_DIR="$2"
        shift 2
        ;;
      --rebuild-image)
        FORCE_REBUILD=1
        shift
        ;;
      --apt-cmd)
        (($# >= 2)) || die "--apt-cmd requires a value"
        APT_CMD="$2"
        shift 2
        ;;
      --)
        saw_separator=1
        shift
        break
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      --*)
        die "unknown option: $1"
        ;;
      *)
        die "expected '--' before package list (got: $1)"
        ;;
    esac
  done

  ((saw_separator == 1)) || die "missing '--' before package list"
  (($# > 0)) || die "no packages provided after '--'"

  PACKAGES=("$@")
  [[ -n "$NAME" ]] || die "name must be non-empty"

  mkdir -p "$HOST_OUTPUT_DIR"
}
