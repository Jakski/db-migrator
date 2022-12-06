#!/usr/bin/env bash
################################################################################
# MIT License
#
# Copyright (c) 2022 Jakub Pieńkowski
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
################################################################################
# This file is a self contained database migration managment script. It requires
# the following configuration directory tree:
#
# - upgrades/[0-9]+.* - upgrade scripts for schema versions
# - downgrades/[0-9]+.* - downgrade scripts for schema versions
# - get_version* - executable for retrieving current schema version as a single
#   number
# - set_version* - executable for setting schema version. It must accept schema
#   version as first argument.
#
# All configuration files are executable files giving user freedom to implement
# support for any database - not only relational ones. Every script inherits
# environment variable DB_MIGRATOR_DIR pointing to directory with configuration.
# User scripts can use it to implement migrations.
#
# Example configuration is available in source repository:
#
#   https://github.com/Jakski/db-migrator/tree/master/tests
################################################################################
#shellcheck disable=SC2128
# SC2128: Expanding an array without an index only gives the first element.

set -eEuo pipefail
shopt -s inherit_errexit nullglob lastpipe

on_error() {
	declare \
		cmd=$BASH_COMMAND \
		exit_code=$?
	if [ "$exit_code" != 0 ]; then
		echo "Failing with exit code ${exit_code} at ${*} in command: ${cmd}" >&2
	fi
	exit "$exit_code"
}

print_help() {
	declare -a output
mapfile -d "" output << EOF
Description:
  Dead simple tool for managing database schema migrations
Options:
  -h          show this help message
  -d DIR      use SQL scripts from this directory
  -s VERSION  migrate to this schema version(latest by default)
  -g          display schema version
EOF
	echo -n "$output"
}

upgrade_schema() {
	declare \
		next_version=$(("$1" + 1)) \
		dest_version=$2 \
		upgrade_script="" \
		i
	while [ "$next_version" -le "$dest_version" ]; do
		for i in "${SCRIPTS_DIR}/upgrades/"*; do
			if [[ ${i##*/} =~ ^${next_version} ]]; then
				upgrade_script=$i
				break
			fi
		done
		if [ -z "$upgrade_script" ]; then
			echo "Missing upgrade script for version ${next_version}!" >&2
			return 1
		fi
		echo "Upgrading to ${next_version}..."
		set_version "$next_version"
		"$upgrade_script" || {
			echo "Upgrade failed. Schema might be corrupted!" >&2
			return 1
		}
		next_version=$(("$next_version" + 1))
	done
}

downgrade_schema() {
	declare \
		current_version=$1 \
		dest_version=$2 \
		version="" \
		downgrade_script="" \
		i
	while [ "$current_version" -gt "$dest_version" ]; do
		for i in "${SCRIPTS_DIR}/downgrades/"*; do
			if [[ ${i##*/} =~ ^${current_version} ]]; then
				downgrade_script=$i
				break
			fi
		done
		if [ -z "$downgrade_script" ]; then
			echo "Missing upgrade script for version ${current_version}!" >&2
			return 1
		fi
		echo "Downgrading from ${current_version}..."
		current_version=$(("$current_version" - 1))
		set_version "$current_version"
		"$downgrade_script" || {
			echo "Downgrade failed. Schema might be corrupted!" >&2
			return 1
		}
	done
}

set_version() {
	declare \
		version=$1 \
		version_script="" \
		i
	for i in "${SCRIPTS_DIR}/"*; do
		if [[ ${i##*/} =~ ^set_version ]]; then
			version_script=$i
			break
		fi
	done
	if [ -z "$version_script" ]; then
		echo "Couldn't find set_version script!" >&2
		return 1
	fi
	"$version_script" "$version"
}

get_version() {
	declare \
		version_script="" \
		i
	for i in "${SCRIPTS_DIR}/"*; do
		if [[ ${i##*/} =~ ^get_version ]]; then
			version_script=$i
			break
		fi
	done
	if [ -z "$version_script" ]; then
		echo "Couldn't find get_version script!" >&2
		return 1
	fi
	"$version_script"
}

main() {
	trap 'on_error "${BASH_SOURCE[0]}:${LINENO}"' ERR
	declare \
		opt \
		OPTARG \
		dest_version="" \
		show_version=""
	SCRIPTS_DIR=""
	while getopts ":hd:s:g" opt; do
		case "$opt" in
		d)
			SCRIPTS_DIR=$(realpath "$OPTARG")
			;;
		s)
			dest_version=$OPTARG
			;;
		g)
			show_version=1
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
	export DB_MIGRATOR_DIR=$SCRIPTS_DIR
	[ -n "$show_version" ] && {
		get_version
		exit
	}
	declare current_version
	current_version=$(get_version) || {
		exit 1
	}
	if [ -z "$dest_version" ]; then
		# SC2012: Use find instead of ls to better handle non-alphanumeric filenames.
		# shellcheck disable=SC2012
		dest_version=$(ls "${SCRIPTS_DIR}/upgrades" |
			sort -rn |
			head -n 1 |
			cut -d . -f 1)
	fi
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
