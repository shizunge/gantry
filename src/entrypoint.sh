#!/bin/sh
# Copyright (C) 2023-2024 Shizun Ge
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

load_libraries() {
  local LOCAL_LOG_LEVEL="${GANTRY_LOG_LEVEL:-""}"
  local LIB_DIR=
  if [ -n "${GANTRY_LIB_DIR:-""}" ]; then
    LIB_DIR="${GANTRY_LIB_DIR}"
  elif [ -n "${BASH_SOURCE:-""}" ]; then
    # SC3054 (warning): In POSIX sh, array references are undefined.
    # shellcheck disable=SC3054
    LIB_DIR="$( cd "$(dirname "${BASH_SOURCE[0]}")" || return 1; pwd -P )"
  elif [ -r "./src/lib-gantry.sh" ]; then
    LIB_DIR="./src"
  elif [ -r "./lib-gantry.sh" ]; then
    LIB_DIR="."
  fi
  # log function is not available before loading the library.
  if ! echo "${LOCAL_LOG_LEVEL}" | grep -q -i "NONE"; then
    echo "Loading libraries from ${LIB_DIR}"
  fi
  . ${LIB_DIR}/notification.sh
  . ${LIB_DIR}/docker_hub_rate.sh
  . ${LIB_DIR}/lib-common.sh
  . ${LIB_DIR}/lib-gantry.sh
}

_skip_current_node() {
  local SELF_ID=
  SELF_ID=$(docker node inspect self --format "{{.Description.Hostname}}" 2>/dev/null);
  if [ -z "${SELF_ID}" ]; then
    log WARN "Skip because the current node is not a swarm manager.";
    return 0
  fi
  log INFO "Run on current node ${SELF_ID}.";
  return 1
}

gantry() {
  local STACK="${1:-gantry}"
  local START_TIME=
  START_TIME=$(date +%s)

  if _skip_current_node ; then
    return 0
  fi
  local ACCUMULATED_ERRORS=0
  local DOCKER_HUB_RATE_BEFORE=
  local DOCKER_HUB_RATE_AFTER=
  local DOCKER_HUB_RATE_USED=
  local TIME_ELAPSED=

  eval_cmd "pre-run" "${GANTRY_PRE_RUN_CMD:-""}"

  log INFO "Starting."
  gantry_initialize "${STACK}"
  ACCUMULATED_ERRORS=$((ACCUMULATED_ERRORS + $?))

  # SC2119: Use docker_hub_rate "$@" if function's $1 should mean script's $1.
  # shellcheck disable=SC2119
  DOCKER_HUB_RATE_BEFORE=$(docker_hub_rate)
  ACCUMULATED_ERRORS=$((ACCUMULATED_ERRORS + $?))
  log INFO "Before updating, Docker Hub rate remains ${DOCKER_HUB_RATE_BEFORE}."

  log INFO "Starting updating."
  gantry_update_services_list "$(gantry_get_services_list)"
  ACCUMULATED_ERRORS=$((ACCUMULATED_ERRORS + $?))

  # SC2119: Use docker_hub_rate "$@" if function's $1 should mean script's $1.
  # shellcheck disable=SC2119
  DOCKER_HUB_RATE_AFTER=$(docker_hub_rate)
  ACCUMULATED_ERRORS=$((ACCUMULATED_ERRORS + $?))
  DOCKER_HUB_RATE_USED=$(difference_between "${DOCKER_HUB_RATE_BEFORE}" "${DOCKER_HUB_RATE_AFTER}")
  log INFO "After updating, Docker Hub rate remains ${DOCKER_HUB_RATE_AFTER}. Used rate ${DOCKER_HUB_RATE_USED}."

  gantry_finalize "${STACK}";
  ACCUMULATED_ERRORS=$((ACCUMULATED_ERRORS + $?))

  TIME_ELAPSED=$(time_elapsed_since "${START_TIME}")
  local MESSAGE="Done. Use ${TIME_ELAPSED}. ${ACCUMULATED_ERRORS} errors."
  if [ ${ACCUMULATED_ERRORS} -gt 0 ]; then
    log WARN "${MESSAGE}"
  else
    log INFO "${MESSAGE}"
  fi

  eval_cmd "post-run" "${GANTRY_POST_RUN_CMD:-""}"

  return ${ACCUMULATED_ERRORS}
}

main() {
  LOG_LEVEL="${GANTRY_LOG_LEVEL:-${LOG_LEVEL}}"
  NODE_NAME="${GANTRY_NODE_NAME:-${NODE_NAME}}"
  export LOG_LEVEL NODE_NAME
  if [ -n "${GANTRY_IMAGES_TO_REMOVE:-""}" ]; then
    # Image remover runs as a global job. The log will be collected via docker commands then formatted.
    # Redefine the log function for the formater.
    log() { echo "${@}"; }
    gantry_remove_images "${GANTRY_IMAGES_TO_REMOVE}"
    return $?
  fi
  local INTERVAL_SECONDS="${GANTRY_SLEEP_SECONDS:-0}"
  if ! is_number "${INTERVAL_SECONDS}"; then 
    log ERROR "GANTRY_SLEEP_SECONDS must be a number. Got \"${GANTRY_SLEEP_SECONDS}\"."
    return 1;
  fi
  local STACK="${1:-gantry}"
  local RETURN_VALUE=0
  local NEXT_RUN_TARGET_TIME SLEEP_SECONDS
  while true; do
    export LOG_SCOPE="${STACK}"
    NEXT_RUN_TARGET_TIME=$(($(date +%s) + INTERVAL_SECONDS))
    gantry "${@}"
    RETURN_VALUE=$?
    [ "${INTERVAL_SECONDS}" -le 0 ] && break;
    SLEEP_SECONDS=$((NEXT_RUN_TARGET_TIME - $(date +%s)))
    if [ "${SLEEP_SECONDS}" -gt 0 ]; then
      log INFO "Sleeping ${SLEEP_SECONDS} seconds before next update."
      sleep "${SLEEP_SECONDS}"
    fi
  done
  return ${RETURN_VALUE}
}

load_libraries
main "${@}"
