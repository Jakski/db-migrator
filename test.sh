#!/usr/bin/env bash
################################################################################
# Requirements:
# - sqlite3
################################################################################

set -eEuo pipefail
shopt -s inherit_errexit nullglob lastpipe

PROGRAM=./migrator.sh

on_error() {
	declare \
		cmd=$BASH_COMMAND \
		exit_code=$?
	if [ "$exit_code" != 0 ]; then
		echo "Failing with exit code ${exit_code} at ${*} in command: ${cmd}" >&2
	fi
	exit "$exit_code"
}

main() {
	trap 'on_error "${BASH_SOURCE[0]}:${LINENO}"' ERR
	shellcheck ./*.sh
	echo "Starting tests:"
	echo ""
	rm -f test.db

	echo -n "* Get database version with empty database..."
	local version
	version=$("$PROGRAM" -d tests -g)
	[ "$version" -ne 0 ] && exit 1
	echo " OK"

	echo -n "* Upgrade to latest version..."
	"$PROGRAM" -d tests >/dev/null
	version=$("$PROGRAM" -d tests -g)
	[ "$version" -ne 2 ] && exit 1
	echo " OK"

	echo -n "* Upgrade to selected version..."
	rm -f test.db
	"$PROGRAM" -d tests -s 1 >/dev/null
	version=$("$PROGRAM" -d tests -g)
	[ "$version" -ne 1 ] && exit 1
	echo " OK"

	echo -n "* Rollback to base version..."
	"$PROGRAM" -d tests -s 0 >/dev/null
	version=$("$PROGRAM" -d tests -g)
	[ "$version" -ne 0 ] && exit 1
	echo " OK"

	echo -n "* Do invalid downgrade..."
	local exit_code=""
	rm -f test.db
	"$PROGRAM" -d tests >/dev/null
	"$PROGRAM" -d tests -s 1 >/dev/null 2>&1 || {
		exit_code=$?
	}
	[ -z "$exit_code" ] && exit 1
	echo " OK"

	echo -n "* Do invalid upgrade..."
	exit_code=""
	"$PROGRAM" -d tests -s 3 >/dev/null 2>&1 || {
		exit_code=$?
	}
	[ -z "$exit_code" ] && exit 1
	echo " OK"

	rm -f test.db
}

main "$@"
