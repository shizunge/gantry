#!/bin/sh
# Copyright (C) 2023 Shizun Ge
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
source ./notification.sh
source ./docker_hub_rate.sh
source ./lib-common.sh
source ./lib-gantry.sh

skip_current_node() {
  local SELF_ID=$(docker node inspect self --format {{.Description.Hostname}} 2>/dev/null);
  if [ -z "${SELF_ID}" ]; then
    log WARN "Skip because the current node is not a swarm manager.";
    return 0
  fi
  log INFO "Run on current node ${SELF_ID}.";
  return 1
}

gantry() {
  local STACK=${1:-gantry}
  local START_TIME=$(date +%s)

  if skip_current_node ; then
    return 0
  fi
  local ACCUMULATED_ERRORS=0

  log INFO "Starting."
  gantry_initialize "${STACK}"
  ACCUMULATED_ERRORS=$((ACCUMULATED_ERRORS + $?))

  local DOCKER_HUB_RATE_BEFORE=$(docker_hub_rate)
  ACCUMULATED_ERRORS=$((ACCUMULATED_ERRORS + $?))
  log INFO "Before updating, Docker Hub rate remains ${DOCKER_HUB_RATE_BEFORE}."

  log INFO "Starting updating."
  gantry_update_services_list $(gantry_get_services_list)
  ACCUMULATED_ERRORS=$((ACCUMULATED_ERRORS + $?))

  local DOCKER_HUB_RATE_AFTER=$(docker_hub_rate)
  ACCUMULATED_ERRORS=$((ACCUMULATED_ERRORS + $?))
  local DOCKER_HUB_RATE_USED=$(difference_between "${DOCKER_HUB_RATE_BEFORE}" "${DOCKER_HUB_RATE_AFTER}")
  log INFO "After updating, Docker Hub rate remains ${DOCKER_HUB_RATE_AFTER}. Used rate ${DOCKER_HUB_RATE_USED}."

  gantry_finalize "${STACK}";
  ACCUMULATED_ERRORS=$((ACCUMULATED_ERRORS + $?))

  local TIME_ELAPSED=$(time_elapsed_since ${START_TIME})
  local MESSAGE="Done. Use ${TIME_ELAPSED}. ${ACCUMULATED_ERRORS} errors."
  if [ ${ACCUMULATED_ERRORS} -gt 0 ]; then
    log WARN ${MESSAGE}
  else
    log INFO ${MESSAGE}
  fi
  return ${ACCUMULATED_ERRORS}
}

main() {
  LOG_LEVEL=${GANTRY_LOG_LEVEL:-${LOG_LEVEL}}
  NODE_NAME=${GANTRY_NODE_NAME:-${NODE_NAME}}
  local SLEEP_SECONDS=${GANTRY_SLEEP_SECONDS:-0}
  if ! is_number "${SLEEP_SECONDS}"; then 
    log ERROR "GANTRY_SLEEP_SECONDS must be a number. Got \"${GANTRY_SLEEP_SECONDS}\"."
    return 1;
  fi
  local STACK=${1:-gantry}
  local RETURN_VALUE=0
  while true; do
    LOG_SCOPE=${STACK}
    gantry ${@}
    RETURN_VALUE=$?
    [ "${SLEEP_SECONDS}" -le 0 ] && break;
    log INFO "Sleeping ${SLEEP_SECONDS} seconds before next update."
    sleep ${SLEEP_SECONDS}
  done
  return ${RETURN_VALUE}
}

main ${@}
