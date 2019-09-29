#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

DB_FILE=${DB_FILE:-test.db}

rel_dir=$(dirname \
  "$(realpath --no-symlinks --relative-to "$DB_MIGRATOR_DIR" "$0")")
filename=$(basename "$0" | cut -d . -f 1)
cat "${DB_MIGRATOR_DIR}/sql/${rel_dir}/${filename}.sql" \
  | sqlite3 "$DB_FILE"
