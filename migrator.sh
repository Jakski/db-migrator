#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

on_exit() {
  local exit_code=$?
  if [ "$exit_code" -ne 0 ]; then
    echo "Aborting" >&2
  fi
}

print_help() {
cat << EOF
Description:
  Dead simple tool for managing database schema migrations
Options:
  -h          show this help message
  -d DIR      use SQL scripts from this directory
  -s VERSION  migrate to this schema version(latest by default)
  -g          display schema version
EOF
}

upgrade_schema() {
  local \
    current_version=$1 \
    dest_version=$2 \
    version="" \
    upgrade_script=""
  ls "${SCRIPTS_DIR}/upgrades" \
    | sort -n \
  | while read -r upgrade_script; do
    version=$(echo "$upgrade_script" | cut -d . -f 1)
    if [ "$version" -gt "$current_version" ] \
      && [ "$version" -le "$dest_version" ]; then
      echo "Upgrading to ${version}..."
      set_version "$version"
      "${SCRIPTS_DIR}/upgrades/${upgrade_script}" || {
        echo "Upgrade failed. Schema might be corrupted!" >&2
        exit 1
      }
    fi
  done
}

downgrade_schema() {
  local \
    current_version=$1 \
    dest_version=$2 \
    version="" \
    downgrade_script=""
  ls "${SCRIPTS_DIR}/downgrades" \
    | sort -rn \
  | while read -r downgrade_script; do
    version=$(echo "$downgrade_script" | cut -d . -f 1)
    if [ "$version" -le "$current_version" ] \
      && [ "$version" -gt "$dest_version" ]; then
      echo "Downgrading from ${version}..."
      set_version "$(($version - 1))"
      "${SCRIPTS_DIR}/downgrades/${downgrade_script}" || {
        echo "Downgrade failed. Schema might be corrupted!" >&2
        exit 1
      }
    fi
  done
}

set_version() {
  local \
    version=$1 \
    version_script
  version_script=$(ls "$SCRIPTS_DIR" | grep ^set_version | head -n 1)
  "${SCRIPTS_DIR}/${version_script}" "$version"
}

get_version() {
  local version_script
  version_script=$(ls "$SCRIPTS_DIR" | grep ^get_version | head -n 1)
  "${SCRIPTS_DIR}/${version_script}"
}

main() {
  local \
    opt \
    OPTARG \
    dest_version=""
  SCRIPTS_DIR=""
  trap on_exit EXIT
  while getopts ":hc:d:s:g" opt; do
    case "$opt" in
    d)
      SCRIPTS_DIR=$(realpath "$OPTARG")
      ;;
    c)
      script_cmd=$OPTARG
      ;;
    s)
      dest_version=$OPTARG
      ;;
    g)
      echo "$(get_version)"
      exit
      ;;
    h)
      print_help
      exit
      ;;
    *)
      print_help
      exit 1
      ;;
    esac
  done
  [ -z "$SCRIPTS_DIR" ] && {
    echo "Missing directory with scripts!" >&2
    exit 1
  }
  local current_version
  current_version=$(get_version) || {
    exit 1
  }
  if [ -z "$dest_version" ]; then
    dest_version=$(ls "${SCRIPTS_DIR}/upgrades" \
      | sort -rn \
      | head -n 1 \
      | cut -d . -f 1)
  fi
  export DB_MIGRATOR_DIR=$SCRIPTS_DIR
  if [ -z "$dest_version" ]; then
    echo "No migrations detected"
  elif [ "$dest_version" -gt "$current_version" ]; then
    upgrade_schema "$current_version" "$dest_version"
    echo "Current schema version is $(get_version)"
  elif [ "$dest_version" -lt "$current_version" ]; then
    downgrade_schema "$current_version" "$dest_version"
    echo "Current schema version is $(get_version)"
  else
    echo "Schema version is up-to-date"
  fi
}

main "$@"
