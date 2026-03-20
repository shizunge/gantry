#!/bin/sh
# Copyright (C) 2024-2026 Shizun Ge
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

main() {
  # Read environment variables
  local TRIGGER_FILE="${TRIGGER_FILE:-}"
  local UPDATE_START_FILE="${UPDATE_START:-}"
  echo "TRIGGER_FILE=${TRIGGER_FILE}"
  echo "UPDATE_START_FILE=${UPDATE_START_FILE}"
  [ -z "${TRIGGER_FILE}" ] && return 1;
  [ -z "${UPDATE_START_FILE}" ] && return 1;
  # Perpare the trigger file to pass parameters to Gantry.
  # We setup GANTRY_PRE_RUN_CMD of Gantry to source this file.
  local TMP_FILE=
  TMP_FILE=$(mktemp) || return 1;
  echo "export GANTRY_SERVICES_EXCLUDED=${GANTRY_SERVICES_EXCLUDED:-}" > "${TMP_FILE}"
  echo "export GANTRY_SERVICES_EXCLUDED_FILTERS=${GANTRY_SERVICES_EXCLUDED_FILTERS:-}" > "${TMP_FILE}"
  echo "export GANTRY_SERVICES_FILTERS=${GANTRY_SERVICES_FILTERS:-}" > "${TMP_FILE}"
  echo "echo \"environment variables loaded.\"" > "${TMP_FILE}"
  local UPDATE_START_TIME=0
  local TRIGGER_START_TIME=
  TRIGGER_START_TIME=$(date +%s)
  # Keep trying until it actually triggers the update.
  while [ "${UPDATE_START_TIME}" -lt "${TRIGGER_START_TIME}" ]; do
    echo "Triggering update."
    cp "${TMP_FILE}" "${TRIGGER_FILE}"
    sleep 1
    # Check the update is actually triggered.
    # We setup GANTRY_PRE_RUN_CMD of Gantry to update ${UPDATE_START_FILE}.
    [ -f "${UPDATE_START_FILE}" ] && UPDATE_START_TIME=$(head -1 "${UPDATE_START_FILE}")
  done
  rm "${TMP_FILE}"
}

main "${@}"
