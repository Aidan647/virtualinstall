#!/usr/bin/env bash

ensure_docker() {
  command -v docker >/dev/null 2>&1 || {
    echo "error: docker is required but not found" >&2
    exit 10
  }
}

ensure_apt() {
  resolve_apt_cmd
}

resolve_apt_cmd() {
  if [[ -n "$RESOLVED_APT_CMD" ]]; then
    return
  fi

  if [[ -n "$APT_CMD" ]]; then
    if [[ "$APT_CMD" == */* ]]; then
      [[ -x "$APT_CMD" ]] || die "--apt-cmd path is not executable: $APT_CMD"
      RESOLVED_APT_CMD="$APT_CMD"
      return
    fi

    command -v "$APT_CMD" >/dev/null 2>&1 || die "--apt-cmd not found in PATH: $APT_CMD"
    RESOLVED_APT_CMD="$APT_CMD"
    return
  fi

  if command -v apt-fast >/dev/null 2>&1; then
    RESOLVED_APT_CMD="apt-fast"
    return
  fi

  if command -v apt >/dev/null 2>&1; then
    RESOLVED_APT_CMD="apt"
    return
  fi

  if command -v apt-get >/dev/null 2>&1; then
    RESOLVED_APT_CMD="apt-get"
    return
  fi

  die "no apt command found (tried apt-fast, apt, apt-get)"
}

run_privileged() {
  if ((EUID == 0)); then
    "$@"
    return
  fi

  if command -v sudo >/dev/null 2>&1; then
    sudo "$@"
    return
  fi

  die "this operation requires root privileges"
}

ensure_image() {
  if ((FORCE_REBUILD == 1)); then
    echo "Forcing rebuild of Docker image $IMAGE_NAME from $SCRIPT_DIR..." >&2
    docker build --pull --no-cache -t "$IMAGE_NAME" "$SCRIPT_DIR"
    return
  fi

  if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
    echo "Image $IMAGE_NAME not found locally. Building from $SCRIPT_DIR..." >&2
    docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"
  fi
}

run_builder() {
  docker run --rm \
    -v "${HOST_OUTPUT_DIR}:/work/out" \
    "$IMAGE_NAME" \
    "$NAME" \
    "${PACKAGES[@]}"
}

expected_artifact_path() {
  local hash_input
  local hash6
  local package_name

  hash_input="${PACKAGES[*]}"
  hash6="$(printf '%s' "$hash_input" | sha256sum | cut -c1-6)"
  package_name="${NAME}-${hash6}-virtual"
  echo "${HOST_OUTPUT_DIR}/${package_name}.deb"
}

ensure_artifact() {
  local artifact_path

  artifact_path="$(expected_artifact_path)"
  if [[ -f "$artifact_path" && $FORCE_REBUILD -eq 0 ]]; then
    echo "Using existing artifact: $artifact_path" >&2
    echo "$artifact_path"
    return
  fi

  ensure_docker
  ensure_image
  run_builder >/dev/null

  [[ -f "$artifact_path" ]] || die "expected artifact not found after build: $artifact_path"
  echo "$artifact_path"
}

install_artifact() {
  local deb_path="$1"
  local tmp_deb

  [[ -n "$deb_path" ]] || die "no generated .deb found in $HOST_OUTPUT_DIR"

  ensure_apt

  tmp_deb="$(mktemp /tmp/virtualinstall-XXXXXX.deb)"
  cp -- "$deb_path" "$tmp_deb"
  chmod 0644 "$tmp_deb"

  run_privileged "$RESOLVED_APT_CMD" install "$tmp_deb"
  rm -f -- "$tmp_deb"
}

remove_by_tag() {
  local tag_files=()
  local menu_labels=()
  local selected_tag_file
  local virtual_package
  local deps_display
  local tag_file
  local choice
  local i

  ensure_apt

  shopt -s nullglob
  tag_files=(/var/lib/virtualinstall/tags/"${NAME}"-*-virtual.json)
  shopt -u nullglob

  if ((${#tag_files[@]} == 0)); then
    die "no tag files found for name: ${NAME}"
  fi

  if ((${#tag_files[@]} == 1)); then
    selected_tag_file="${tag_files[0]}"
  else
    for tag_file in "${tag_files[@]}"; do
      virtual_package="$(sed -n 's/.*"virtualPackage"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$tag_file" | head -n1)"
      deps_display="$(sed -n 's/.*"dependencies"[[:space:]]*:[[:space:]]*\[\(.*\)\].*/\1/p' "$tag_file" | head -n1)"
      deps_display="${deps_display//\"/}"
      deps_display="${deps_display//,/, }"

      if [[ -z "$virtual_package" ]]; then
        virtual_package="$(basename "$tag_file" .json)"
      fi
      if [[ -z "$deps_display" ]]; then
        deps_display="no deps"
      fi

      menu_labels+=("${virtual_package} (${deps_display})")
    done

    echo "Multiple packages found for '${NAME}'. Select one to remove:" >&2
    PS3="Selection (1-${#tag_files[@]}): "
    select choice in "${menu_labels[@]}"; do
      if [[ "$REPLY" =~ ^[0-9]+$ ]] && ((REPLY >= 1 && REPLY <= ${#tag_files[@]})); then
        i=$((REPLY - 1))
        selected_tag_file="${tag_files[$i]}"
        break
      fi
      echo "Invalid selection. Try again." >&2
    done
  fi

  virtual_package="$(sed -n 's/.*"virtualPackage"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$selected_tag_file" | head -n1)"
  [[ -n "$virtual_package" ]] || die "could not parse virtualPackage from $selected_tag_file"

  run_privileged "$RESOLVED_APT_CMD" remove "$virtual_package"
}

clean_artifacts() {
  local deb_files=()
  local removed_count
  local total_bytes=0
  local bytes
  local file
  local freed

  [[ -d "$HOST_OUTPUT_DIR" ]] || return 0

  shopt -s nullglob
  deb_files=("$HOST_OUTPUT_DIR"/*.deb)
  shopt -u nullglob

  if ((${#deb_files[@]} == 0)); then
    echo "No .deb files to clean in $HOST_OUTPUT_DIR"
    return
  fi

  for file in "${deb_files[@]}"; do
    bytes="$(stat -c%s -- "$file" 2>/dev/null || echo 0)"
    total_bytes=$((total_bytes + bytes))
  done

  removed_count=${#deb_files[@]}
  rm -f -- "${deb_files[@]}"

  if command -v numfmt >/dev/null 2>&1; then
    freed="$(numfmt --to=iec --suffix=B "$total_bytes")"
  else
    freed="${total_bytes}B"
  fi

  echo "Removed ${removed_count} .deb file(s), freed ${freed} from $HOST_OUTPUT_DIR"
}

list_tags() {
  local tag_files=()
  local tag_file
  local tag_name
  local virtual_package
  local deps_display
  local found=0

  shopt -s nullglob
  tag_files=(/var/lib/virtualinstall/tags/*.json)
  shopt -u nullglob

  if ((${#tag_files[@]} == 0)); then
    echo "No installed virtual tags found in /var/lib/virtualinstall/tags"
    return
  fi

  for tag_file in "${tag_files[@]}"; do
    tag_name="$(sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$tag_file" | head -n1)"
    virtual_package="$(sed -n 's/.*"virtualPackage"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$tag_file" | head -n1)"
    deps_display="$(sed -n 's/.*"dependencies"[[:space:]]*:[[:space:]]*\[\(.*\)\].*/\1/p' "$tag_file" | head -n1)"

    deps_display="${deps_display//\"/}"
    deps_display="${deps_display//,/, }"

    [[ -n "$tag_name" ]] || tag_name="unknown"
    [[ -n "$virtual_package" ]] || virtual_package="$(basename "$tag_file" .json)"
    [[ -n "$deps_display" ]] || deps_display="no deps"

    if [[ -n "$NAME" && "$tag_name" != "$NAME" ]]; then
      continue
    fi

    found=1
    echo "${virtual_package} (${deps_display})"
  done

  if ((found == 0)); then
    echo "No installed virtual tags found for name '${NAME}'"
  fi
}
