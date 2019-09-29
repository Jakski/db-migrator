#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

DB_FILE=${DB_FILE:-test.db}

sqlite3 "$DB_FILE" << EOF
INSERT INTO schema_version (version, date)
  VALUES ($1, datetime('now','localtime'));
EOF
