#!/usr/bin/env bash
# Shared pins: installation and generation must use the same toolchain.
set -euo pipefail

readonly PROTOC_VERSION=33.1
readonly PLUGIN_NAMES=(protoc-gen-go protoc-gen-go-grpc protoc-gen-go-http protoc-gen-openapi)
readonly PLUGIN_MODULES=(
  google.golang.org/protobuf
  google.golang.org/grpc/cmd/protoc-gen-go-grpc
  github.com/go-kratos/kratos/cmd/protoc-gen-go-http/v2
  github.com/google/gnostic
)
readonly PLUGIN_PACKAGES=(
  google.golang.org/protobuf/cmd/protoc-gen-go
  google.golang.org/grpc/cmd/protoc-gen-go-grpc
  github.com/go-kratos/kratos/cmd/protoc-gen-go-http/v2
  github.com/google/gnostic/cmd/protoc-gen-openapi
)
readonly PLUGIN_VERSIONS=(v1.36.11 v1.6.0 v2.0.0-20260327083312-4ed1bedbb024 v0.7.1)

proto_error() {
  printf 'proto tools: %s\n' "$*" >&2
  return 1
}

proto_binary() {
  local binary
  binary=$(type -P "$1") || { proto_error "missing $1 on PATH; install pinned tools explicitly (make init-proto-tools)"; return 1; }
  case "$binary" in
    /*) printf '%s\n' "$binary" ;;
    *) printf '%s/%s\n' "$PWD" "$binary" ;;
  esac
}

proto_check_tools() {
  local go_binary actual metadata i kind module version rest package found
  PROTOC_BINARY=$(proto_binary protoc)
  actual=$("$PROTOC_BINARY" --version)
  [[ "$actual" == "libprotoc $PROTOC_VERSION" ]] || {
    proto_error "protoc: expected libprotoc $PROTOC_VERSION, got $actual ($PROTOC_BINARY)"; return 1;
  }
  go_binary=$(proto_binary go)
  PLUGIN_BINARIES=()
  for i in "${!PLUGIN_NAMES[@]}"; do
    PLUGIN_BINARIES+=("$(proto_binary "${PLUGIN_NAMES[$i]}")")
    metadata=$(GOTOOLCHAIN=local "$go_binary" version -m "${PLUGIN_BINARIES[$i]}")
    package= found=
    while read -r kind module version rest; do
      case "$kind" in
        path) package=$module ;;
        mod) found="$module $version" ;;
        '=>') proto_error "${PLUGIN_NAMES[$i]}: replaced module is not a pinned release"; return 1 ;;
      esac
    done <<< "$metadata"
    if [[ "$package" != "${PLUGIN_PACKAGES[$i]}" || "$found" != "${PLUGIN_MODULES[$i]} ${PLUGIN_VERSIONS[$i]}" ]]; then
      proto_error "${PLUGIN_NAMES[$i]}: expected ${PLUGIN_MODULES[$i]} ${PLUGIN_VERSIONS[$i]}, got ${found:-no module build info} (${PLUGIN_BINARIES[$i]})"
      return 1
    fi
  done
}

proto_install_tools() {
  local i
  for i in "${!PLUGIN_NAMES[@]}"; do
    go install "${PLUGIN_PACKAGES[$i]}@${PLUGIN_VERSIONS[$i]}"
  done
  printf 'Install protoc %s separately and put it and the pinned plugins on PATH.\n' "$PROTOC_VERSION"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  case "${1:-check}" in
    check) proto_check_tools ;;
    install) proto_install_tools ;;
    *) proto_error 'usage: proto-tools.sh [check|install]' ;;
  esac
fi
