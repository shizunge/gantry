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
    echo "[$(date -Iseconds)] Loading libraries from ${LIB_DIR}" >&2
  fi
  . "${LIB_DIR}/notification.sh"
  . "${LIB_DIR}/docker_hub_rate.sh"
  . "${LIB_DIR}/lib-common.sh"
  . "${LIB_DIR}/lib-gantry.sh"
}

_run_on_node() {
  local HOST_NAME=
  if ! HOST_NAME=$(docker node inspect self --format "{{.Description.Hostname}}" 2>&1); then
    log DEBUG "Failed to run \"docker node inspect self\": ${HOST_NAME}"
    return 1
  fi
  echo "${HOST_NAME}"
  return 0
}

_read_docker_hub_rate() {
  local HOST PASSWORD USER
  if ! PASSWORD=$(gantry_read_registry_password 2>&1); then
    log ERROR "Failed to read registry PASSWORD: ${PASSWORD}";
    PASSWORD=
  fi
  if ! USER=$(gantry_read_registry_username 2>&1); then
    log ERROR "Failed to read registry USER: ${USER}";
    USER=
  fi
  if ! HOST=$(gantry_read_registry_host 2>&1); then
    log ERROR "Failed to read registry HOST: ${HOST}";
    HOST=
  fi
  local USER_AND_PASS=
  if [ -n "${USER}" ] && [ -n "${PASSWORD}" ]; then
    if [ -z "${HOST}" ] || [ "${HOST}" = "docker.io" ]; then
      USER_AND_PASS="${USER}:${PASSWORD}"
    fi
  fi
  # Set IMAGE to empyt to use the default image.
  local IMAGE=
  docker_hub_rate "${IMAGE}" "${USER_AND_PASS}"
}

gantry() {
  local PRE_RUN_CMD="${GANTRY_PRE_RUN_CMD:-""}"
  local POST_RUN_CMD="${GANTRY_POST_RUN_CMD:-""}"
  local STACK="${1}"
  [ -z "${STACK}" ] && STACK=$(gantry_current_service_name)
  [ -z "${STACK}" ] && STACK="gantry"
  export LOG_SCOPE="${STACK}"
  local START_TIME=
  START_TIME=$(date +%s)

  [ -n "${DOCKER_HOST}" ] && log DEBUG "DOCKER_HOST=${DOCKER_HOST}"
  local RUN_ON_NODE=
  if ! RUN_ON_NODE=$(_run_on_node); then
    local HOST_STRING="${DOCKER_HOST:-"the current node"}"
    log ERROR "Skip updating all services because ${HOST_STRING} is not a swarm manager.";
    return 1
  elif [ -z "${NODE_NAME}" ]; then
    log DEBUG "Set NODE_NAME=${RUN_ON_NODE}"
    export NODE_NAME="${RUN_ON_NODE}"
  fi
  log INFO "Run on Docker host ${RUN_ON_NODE}. $(docker_version)"

  local ACCUMULATED_ERRORS=0

  eval_cmd "pre-run" "${PRE_RUN_CMD}"

  log INFO "Starting."
  gantry_initialize "${STACK}"
  ACCUMULATED_ERRORS=$((ACCUMULATED_ERRORS + $?))

  local DOCKER_HUB_RATE_BEFORE=
  DOCKER_HUB_RATE_BEFORE=$(_read_docker_hub_rate)
  log INFO "Before updating, Docker Hub rate remains ${DOCKER_HUB_RATE_BEFORE}."

  local SERVICES_LIST=
  SERVICES_LIST=$(gantry_get_services_list)
  ACCUMULATED_ERRORS=$((ACCUMULATED_ERRORS + $?))

  if [ "${ACCUMULATED_ERRORS}" -eq 0 ]; then
    log INFO "Starting updating."
    gantry_update_services_list "${SERVICES_LIST}"
    ACCUMULATED_ERRORS=$((ACCUMULATED_ERRORS + $?))
  else
    log WARN "Skip updating all services due to previous error(s)."
  fi

  local DOCKER_HUB_RATE_AFTER=
  local DOCKER_HUB_RATE_USED=
  DOCKER_HUB_RATE_AFTER=$(_read_docker_hub_rate)
  DOCKER_HUB_RATE_USED=$(difference_between "${DOCKER_HUB_RATE_BEFORE}" "${DOCKER_HUB_RATE_AFTER}")
  log INFO "After updating, Docker Hub rate remains ${DOCKER_HUB_RATE_AFTER}. Used rate ${DOCKER_HUB_RATE_USED}."

  gantry_finalize "${STACK}" "${ACCUMULATED_ERRORS}";
  ACCUMULATED_ERRORS=$((ACCUMULATED_ERRORS + $?))

  eval_cmd "post-run" "${POST_RUN_CMD}"

  local TIME_ELAPSED=
  TIME_ELAPSED=$(time_elapsed_since "${START_TIME}")
  local MESSAGE="Done. Use ${TIME_ELAPSED}. ${ACCUMULATED_ERRORS} error(s)."
  local RETURN_VALUE=0
  if [ "${ACCUMULATED_ERRORS}" -gt 0 ]; then
    log ERROR "${MESSAGE}"
    RETURN_VALUE=1
  else
    log INFO "${MESSAGE}"
    RETURN_VALUE=0
  fi
  return "${RETURN_VALUE}"
}

main() {
  LOG_LEVEL="${GANTRY_LOG_LEVEL:-${LOG_LEVEL}}"
  NODE_NAME="${GANTRY_NODE_NAME:-${NODE_NAME}}"
  export LOG_LEVEL NODE_NAME
  local INTERVAL_SECONDS=
  INTERVAL_SECONDS=$(gantry_read_number GANTRY_SLEEP_SECONDS 0) || return 1
  local IMAGES_TO_REMOVE="${GANTRY_IMAGES_TO_REMOVE:-""}"
  if [ -n "${IMAGES_TO_REMOVE}" ]; then
    # Image remover runs as a global job. The log will be collected via docker commands then formatted.
    # Redefine the log function for the formater.
    log() { echo "${@}"; }
    gantry_remove_images "${IMAGES_TO_REMOVE}"
    return $?
  fi
  local RETURN_VALUE=0
  while true; do
    local NEXT_RUN_TARGET_TIME=$(($(date +%s) + INTERVAL_SECONDS))
    gantry "${@}"
    RETURN_VALUE=$?
    [ "${INTERVAL_SECONDS}" -le 0 ] && break;
    log INFO "Schedule next update at $(busybox date -d "@${NEXT_RUN_TARGET_TIME}" -Iseconds)."
    local SLEEP_SECONDS=$((NEXT_RUN_TARGET_TIME - $(date +%s)))
    if [ "${SLEEP_SECONDS}" -gt 0 ]; then
      log INFO "Sleep ${SLEEP_SECONDS} seconds before next update."
      sleep "${SLEEP_SECONDS}"
    fi
  done
  return "${RETURN_VALUE}"
}

load_libraries
main "${@}"
