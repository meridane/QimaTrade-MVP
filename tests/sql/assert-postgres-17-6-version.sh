#!/usr/bin/env bash
set -euo pipefail

version_num="${1-}"
if [[ ! "$version_num" =~ ^[0-9]+$ ]]; then
  echo "::error::Expected numeric PostgreSQL server_version_num=170006; received '${version_num}'."
  exit 1
fi

if [[ "$version_num" != "170006" ]]; then
  echo "::error::Expected PostgreSQL 17.6 (server_version_num=170006); received ${version_num}."
  exit 1
fi

printf 'PostgreSQL 17.6 compatibility server_version_num=%s\n' "$version_num"
