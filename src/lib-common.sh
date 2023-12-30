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

# echo the number of the log level.
# return 0 if LEVEL is supported.
# return 1 if LEVLE is unsupported.
log_level() {
  local LEVEL="${1}";
  [ -z "${LEVEL}" ] && log_level "INFO" && return 1;
  [ "${LEVEL}" = "DEBUG" ] && echo 0 && return 0;
  [ "${LEVEL}" = "INFO"  ] && echo 1 && return 0;
  [ "${LEVEL}" = "WARN"  ] && echo 2 && return 0;
  [ "${LEVEL}" = "ERROR" ] && echo 3 && return 0;
  [ "${LEVEL}" = "NONE"  ] && echo 4 && return 0;
  log_level "NONE";
  return 1;
}

log_formatter() {
  local LOG_LEVEL="${LOG_LEVEL}"
  local LEVEL="${1}"; shift;
  [ "$(log_level "${LEVEL}")" -lt "$(log_level "${LOG_LEVEL}")" ] && return 0;
  local TIME="${1}"; shift;
  local LOCATION="${1}"; shift;
  local SCOPE="${1}"; shift;
  local LOCATION_STR=
  local SCOPE_STR=
  local MESSAGE_STR=
  LOCATION_STR=$(if [ -n "${LOCATION}" ]; then echo "[${LOCATION}]"; else echo ""; fi);
  SCOPE_STR=$(if [ -n "${SCOPE}" ]; then echo "${SCOPE}: "; else echo ""; fi);
  MESSAGE_STR=$(echo "${*}" | tr '\n' ' ')
  local MESSAGE="[${TIME}]${LOCATION_STR}[${LEVEL}] ${SCOPE_STR}${MESSAGE_STR}";
  echo "${MESSAGE}" >&2;
}

# We want to print an empty line for log without an argument. Thus we do not run the following check.
# [ -z "${1}" ] && return 0
log() {
  local NODE_NAME="${NODE_NAME}"
  local LOG_SCOPE="${LOG_SCOPE}"
  local LEVEL="INFO";
  if log_level "${1}" >/dev/null; then
    LEVEL="${1}";
    shift;
  fi;
  log_formatter "${LEVEL}" "$(date -Iseconds)" "${NODE_NAME}" "${LOG_SCOPE}" "${@}";
}

log_docker_time() {
  # Convert timestamps from `docker service logs` to ISO-8601. The timestamps is in UTC.
  # docker service logs --timestamps --no-task-ids <service>
  # 2023-06-22T01:20:54.535860111Z <task>@<node>    | <msg>
  local TIME_INPUT="${1}"
  local EPOCH=
  if ! EPOCH="$(busybox date -d "${TIME_INPUT}" -D "%Y-%m-%dT%H:%M:%S" -u +%s 2>/dev/null)"; then
    local TIME=
    TIME=$(echo "${TIME_INPUT}" | cut -d '.' -f 1)
    echo "${TIME}+00:00"
    return 0
  fi
  busybox date -d "@${EPOCH}" -Iseconds 2>&1
}

# docker service logs --timestamps --no-task-ids <service>
# 2023-06-22T01:20:54.535860111Z <task>@<node>    | <msg>
log_docker_line() {
  local LEVEL="INFO";
  local TIME_DOCKER TIME SCOPE NODE MESSAGE SPACE FIRST_WORD
  TIME_DOCKER=$(echo "${@}" | cut -d ' ' -f 1);
  TIME=$(log_docker_time "${TIME_DOCKER}")
  SCOPE=$(echo "${@}" | cut -d ' ' -f 2 | cut -d '@' -f 1);
  NODE=$(echo "${@}" | cut -d ' ' -f 2 | cut -d '@' -f 2);
  MESSAGE=$(echo "${@}" | cut -d '|' -f 2-);
  # Remove the leading space.
  SPACE=$(echo "${MESSAGE}" | cut -d ' ' -f 1)
  [ -z "${SPACE}" ] && MESSAGE=$(echo "${MESSAGE}" | cut -d ' ' -f 2-)
  FIRST_WORD=$(echo "${MESSAGE}" | cut -d ' ' -f 1);
  if log_level "${FIRST_WORD}" >/dev/null; then
    LEVEL=${FIRST_WORD};
    MESSAGE=$(echo "${MESSAGE}" | cut -d ' ' -f 2-);
  fi
  log_formatter "${LEVEL}" "${TIME}" "${NODE}" "${SCOPE}" "${MESSAGE}";
}

# Usage: echo "${LOGS}" | log_lines INFO
log_lines() {
  local LEVEL="${1}";
  while read -r LINE; do
    [ -z "${LINE}" ] && continue;
    log "${LEVEL}" "${LINE}";
  done
}

is_number() {
  [ "${1}" -eq "${1}" ] 2>/dev/null;
}

is_true() {
  local CONFIG="${1}"
  CONFIG=$(echo "${CONFIG}" | cut -d ' ' -f 1)
  echo "${CONFIG}" | grep -q -i "true"
}

difference_between() {
  local NUM0="${1}"
  local NUM1="${2}"
  if is_number "${NUM0}" && is_number "${NUM1}"; then
    if [ "${NUM0}" -gt "${NUM1}" ]; then
      echo "$((NUM0 - NUM1))"
    else
      echo "$((NUM1 - NUM0))"
    fi
    return 0
  fi
  echo "NaN"
  return 1
}

time_elapsed_between() {
  local TIME0="${1}"
  local TIME1="${2}"
  local SECONDS_ELAPSED=
  if ! SECONDS_ELAPSED=$(difference_between "${TIME0}" "${TIME1}"); then
    echo "NaN"
    return 1
  fi
  date -u -d "@${SECONDS_ELAPSED}" +'%-Mm %-Ss'
}

time_elapsed_since() {
  local START_TIME="${1}"
  time_elapsed_between "$(date +%s)" "${START_TIME}"
}

add_uniq_to_list() {
  local OLD_LIST="${1}"
  local NEW_ITEM="${2}"
  echo -e "${OLD_LIST}\n${NEW_ITEM}" | sort | uniq
}

# For a givne variable name <VAR>, try to read content of <VAR>_FILE if file exists.
# otherwise echo the content of <VAR>.
read_config() {
  local CONFIG_NAME="${1}"
  [ -z "${CONFIG_NAME}" ] && return 1
  local CONFIG_FILE_NAME="${CONFIG_NAME}_FILE"
  eval "local CONFIG_FILE=\${${CONFIG_FILE_NAME}}"
  if [ -r "${CONFIG_FILE}" ]; then
    cat "${CONFIG_FILE}"
    return $?
  elif [ -n "${CONFIG_FILE}" ]; then
    echo "Failed to read ${CONFIG_FILE}" >&2
    return 1
  fi
  eval "local CONFIG=\${${CONFIG_NAME}}"
  echo "${CONFIG}"
}

swarm_network_arguments() {
  if [ -z "${NETWORK_NAME}" ]; then
    echo ""
    return 0
  fi
  NETWORK_NAME=$(docker network ls --filter "name=${NETWORK_NAME}" --format '{{.Name}}')
  if [ -z "${NETWORK_NAME}" ]; then
    echo ""
    return 0
  fi
  local NETWORK_ARG="--network=${NETWORK_NAME}"
  if [ -z "${NETWORK_DNS_IP}" ]; then
    echo "${NETWORK_ARG}"
    return 0
  fi
  echo "${NETWORK_ARG} --dns=${NETWORK_DNS_IP}"
}

get_docker_command_name_arg() {
  # get <NAME> from "--name <NAME>" or "--name=<NAME>"
  echo "${@}" | tr '\n' ' ' | sed -E 's/.*--name[ =]([^ ]*).*/\1/'
}

get_docker_command_detach() {
  if echo "${@}" | grep -q -- "--detach"; then
    echo "true"
    return 0
  fi
  echo "false"
}

docker_service_logs () {
  local SERVICE_NAME="${1}"
  local LOGS=
  if ! LOGS=$(docker service logs --timestamps --no-task-ids "${SERVICE_NAME}" 2>&1); then
    log ERROR "Failed to obtain logs of service ${SERVICE_NAME}. ${LOGS}"
    return 1
  fi
  echo "${LOGS}" |
  while read -r LINE; do
    log_docker_line "${LINE}"
  done
}

docker_service_logs_follow() {
  local SERVICE_NAME="${1}"
  docker service logs --timestamps --no-task-ids --follow "${SERVICE_NAME}" 2>&1 |
  while read -r LINE; do
    log_docker_line "${LINE}"
  done
}

docker_service_task_states() {
  local SERVICE_NAME="${1}"
  # We won't get the return value of the command via $? if we use "local STATES=$(command)".
  local STATES=
  if ! STATES=$(docker service ps --no-trunc --format '[{{.Name}}][{{.Node}}] {{.CurrentState}} {{.Error}}' "${SERVICE_NAME}" 2>&1); then
    echo "${STATES}" >&2
    return 1
  fi
  local NAME_LIST=
  echo "${STATES}" | while read -r LINE; do
    local NAME=
    local NODE_STATE_AND_ERROR=
    NAME=$(echo "${LINE}" | cut -d ']' -f 1 | cut -d '[' -f 2)
    NODE_STATE_AND_ERROR=$(echo "${LINE}" | cut -d ']' -f 2-)
    # We assume that the first State of each task is the latest one that we want to report.
    if ! echo "${NAME_LIST}" | grep -q "${NAME}"; then
      echo "${NODE_STATE_AND_ERROR}"
    fi
    NAME_LIST=$(echo -e "${NAME_LIST}\n${NAME}" | sort | uniq)
  done
}

wait_service_state() {
  local SERVICE_NAME="${1}"
  local WAIT_RUNNING="${2:-"false"}"
  local WAIT_COMPLETE="${3:-"false"}"
  local RETURN_VALUE="${4:-0}"
  local SLEEP_SECONDS="${5:-1}"
  local STATES=
  STATES=$(docker_service_task_states "${SERVICE_NAME}" 2>&1)
  while is_true "${WAIT_RUNNING}" || is_true "${WAIT_COMPLETE}" ; do
    local NUM_LINES=0
    local NUM_RUNS=0
    local NUM_DONES=0
    local NUM_FAILS=0
    while read -r LINE; do
      [ -z "${LINE}" ] && continue;
      NUM_LINES=$((NUM_LINES+1));
      echo "${LINE}" | grep -q "Running" && NUM_RUNS=$((NUM_RUNS+1));
      echo "${LINE}" | grep -q "Complete" && NUM_DONES=$((NUM_DONES+1));
      echo "${LINE}" | grep -q "Failed" && NUM_FAILS=$((NUM_FAILS+1));
    done < <(echo "${STATES}")
    if [ ${NUM_LINES} -gt 0 ]; then
      if ${WAIT_RUNNING} && [ ${NUM_RUNS} -eq ${NUM_LINES} ]; then
        break
      fi
      if ${WAIT_COMPLETE} && [ ${NUM_DONES} -eq ${NUM_LINES} ]; then
        break
      fi
      if ${WAIT_COMPLETE} && [ ${NUM_FAILS} -gt 0 ]; then
        # Get return value of the task from the string "task: non-zero exit (1)".
        local TASK_STATE=
        local TASK_RETURN_VALUE=
        TASK_STATE=$(echo "${STATES}" | grep "Failed")
        TASK_RETURN_VALUE=$(echo "${TASK_STATE}" | sed -n 's/.*task: non-zero exit (\([0-9]\+\)).*/\1/p')
        # Get the first error code.
        RETURN_VALUE=$(echo "${TASK_RETURN_VALUE:-1}" | cut -d ' ' -f 1)
        break
      fi
    fi
    sleep "${SLEEP_SECONDS}"
    if ! STATES=$(docker_service_task_states "${SERVICE_NAME}" 2>&1); then
      log ERROR "Failed to obtain task states of service ${SERVICE_NAME}: ${STATES}"
      return 1
    fi
  done
  echo "${STATES}" | while read -r LINE; do
    log INFO "Service ${SERVICE_NAME}: ${LINE}."
  done
  return "${RETURN_VALUE}"
}

docker_service_remove() {
  local SERVICE_NAME="${1}"
  if ! docker service inspect --format '{{.JobStatus}}' "${SERVICE_NAME}" >/dev/null 2>&1; then
    return 0
  fi
  log INFO "Removing service ${SERVICE_NAME}."
  docker service rm "${SERVICE_NAME}" >/dev/null
  local RETURN_VALUE=$?
  log INFO "Removed service ${SERVICE_NAME}."
  return ${RETURN_VALUE}
}

# We do not expect failures when using docker_global_job.
# Docker will try to restart the failed tasks.
# We do not check the converge of the service. It must be used togther with wait_service_state.
docker_global_job() {
  local SERVICE_NAME=
  SERVICE_NAME=$(get_docker_command_name_arg "${@}")
  log INFO "Starting service ${SERVICE_NAME}."
  docker service create \
    --mode global-job \
    "${@}" >/dev/null
}

# A job could fail when using docker_replicated_job.
docker_replicated_job() {
  local SERVICE_NAME=
  local IS_DETACH=
  SERVICE_NAME=$(get_docker_command_name_arg "${@}")
  IS_DETACH=$(get_docker_command_detach "${@}")
  # Add "--detach" to work around https://github.com/docker/cli/issues/2979
  # The Docker CLI does not exit on failures.
  local WAIT_RUNNING="false"
  local WAIT_COMPLETE=
  WAIT_COMPLETE=$(if ${IS_DETACH}; then echo "false"; else echo "true"; fi)
  log INFO "Starting service ${SERVICE_NAME}."
  docker service create \
    --mode replicated-job --detach \
    "${@}" >/dev/null
  local RETURN_VALUE=$?
  # return the code from wait_service_state
  wait_service_state "${SERVICE_NAME}" "${WAIT_RUNNING}" "${WAIT_COMPLETE}" "${RETURN_VALUE}"
}

container_status() {
  local CNAME="${1}"
  docker container inspect --format '{{.State.Status}}' "${CNAME}" 2>/dev/null
}

docker_remove() {
  local CNAME="${1}"
  local STATUS=
  STATUS=$(container_status "${CNAME}")
  if [ -z "${STATUS}" ]; then
    return 0
  fi
  log INFO "Removing container ${CNAME}."
  if [ "${STATUS}" = "running" ]; then
    docker stop "${CNAME}" >/dev/null 2>/dev/null
  fi
  docker rm "${CNAME}" >/dev/null
}

docker_run() {
  local RETRIES=0
  local MAX_RETRIES=5
  local SLEEP_SECONDS=10
  while ! docker run \
    "${@}" >/dev/null;
  do
    if [ ${RETRIES} -ge ${MAX_RETRIES} ]; then
      echo "Failed to run docker. Reached the max retries ${MAX_RETRIES}." >&2
      return 1
    fi
    RETRIES=$((RETRIES + 1))
    sleep ${SLEEP_SECONDS}
    echo "Retry docker run (${RETRIES})."
  done
}
