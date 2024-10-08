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

# echo the number of the log level.
# return 0 if LEVEL is supported.
# return 1 if LEVLE is unsupported.
_log_level() {
  local LEVEL="${1}";
  [ -z "${LEVEL}" ] && _log_level "INFO" && return 1;
  echo "${LEVEL}" | grep -q -i "^DEBUG$" && echo 0 && return 0;
  echo "${LEVEL}" | grep -q -i "^INFO$"  && echo 1 && return 0;
  echo "${LEVEL}" | grep -q -i "^WARN$"  && echo 2 && return 0;
  echo "${LEVEL}" | grep -q -i "^ERROR$" && echo 3 && return 0;
  echo "${LEVEL}" | grep -q -i "^NONE$"  && echo 4 && return 0;
  _log_level "NONE";
  return 1;
}

_level_color() {
  local LEVEL="${1}"
  local NO_COLOR='\033[0m'
  local RED='\033[0;31m'
  local ORANGE='\033[0;33m'
  local GREEN='\033[0;32m'
  local BLUE='\033[0;34m'
  echo "${LEVEL}" | grep -q -i "^DEBUG$" && echo "${BLUE}" && return 0;
  echo "${LEVEL}" | grep -q -i "^INFO$"  && echo "${GREEN}" && return 0;
  echo "${LEVEL}" | grep -q -i "^WARN$"  && echo "${ORANGE}" && return 0;
  echo "${LEVEL}" | grep -q -i "^ERROR$" && echo "${RED}" && return 0;
  echo "${NO_COLOR}"
}

_color_iso_time() {
  # Highlight time within the day in ISO-8601
  # \\033[1;30m : Dark Gray
  # \\033[0;37m : Ligth Gray
  # \\033[0m    : No color
  echo "${*}" | sed -E 's/(.*[0-9]+-[0-9]+-[0-9]+)T([0-9]+:[0-9]+:[0-9]+)(.*)/\\033[1;30m\1T\\033[0;37m\2\\033[1;30m\3\\033[0m/'
}

_log_formatter() {
  local LOG_LEVEL="${LOG_LEVEL}"
  local LEVEL="${1}"; shift;
  [ "$(_log_level "${LEVEL}")" -lt "$(_log_level "${LOG_LEVEL}")" ] && return 0;
  LEVEL=$(echo "${LEVEL}" | tr '[:lower:]' '[:upper:]')
  local TIME="${1}"; shift;
  local LOCATION="${1}"; shift;
  local SCOPE="${1}"; shift;
  local NO_COLOR='\033[0m'
  local DGRAY='\033[1;30m'
  local MSG=
  MSG="${DGRAY}[$(_color_iso_time "${TIME}")${DGRAY}]${NO_COLOR}"
  if [ -n "${LOCATION}" ]; then
    MSG="${MSG}${DGRAY}[${LOCATION}]${NO_COLOR}"
  fi
  MSG="${MSG}$(_level_color "${LEVEL}")[${LEVEL}]${NO_COLOR} "
  if [ -n "${SCOPE}" ]; then
    MSG="${MSG}${DGRAY}${SCOPE}:${NO_COLOR} "
  fi
  MSG="${MSG}$(echo "${*}" | tr '\n' ' ')"
  echo -e "${MSG}" >&2
}

# We want to print an empty line for log without an argument. Thus we do not run the following check.
# [ -z "${1}" ] && return 0
log() {
  local NODE_NAME="${NODE_NAME}"
  local LOG_SCOPE="${LOG_SCOPE}"
  local LEVEL="INFO";
  if _log_level "${1}" >/dev/null; then
    LEVEL="${1}";
    shift;
  fi
  _log_formatter "${LEVEL}" "$(date -Iseconds)" "${NODE_NAME}" "${LOG_SCOPE}" "${@}";
}

_log_docker_time() {
  # Convert timestamps from `docker service logs` to ISO-8601. The timestamps is in UTC.
  # docker service logs --timestamps --no-task-ids <service>
  # 2023-06-22T01:20:54.535860111Z <task>@<node>    | <msg>
  local TIME_INPUT="${1}"
  local EPOCH=
  if ! EPOCH="$(busybox date -d "${TIME_INPUT}" -D "%Y-%m-%dT%H:%M:%S" -u +%s 2>/dev/null)"; then
    date -Iseconds
    return 1
  fi
  busybox date -d "@${EPOCH}" -Iseconds 2>&1
}

_log_docker_scope() {
  local LOG_SCOPE="${LOG_SCOPE}"
  local TASK_NODE="${1}"
  local SCOPE=
  SCOPE=$(echo "${TASK_NODE}" | sed -n "s/\(.*\)@.*/\1/p");
  if [ -z "${SCOPE}" ]; then
    echo "${LOG_SCOPE}"
    return 1
  fi
  echo "${SCOPE}"
}

_log_docker_node() {
  local NODE_NAME="${NODE_NAME}"
  local TASK_NODE="${1}"
  local NODE=
  NODE=$(echo "${TASK_NODE}" | sed -n "s/.*@\(.*\)/\1/p");
  if [ -z "${NODE}" ]; then
    echo "${NODE_NAME}"
    return 1
  fi
  echo "${NODE}"
}

# Convert logs from `docker service logs` to `log` format.
# docker service logs --timestamps --no-task-ids <service>
# 2023-06-22T01:20:54.535860111Z <task>@<node>    | <msg>
_log_docker_line() {
  local LEVEL="INFO";
  local TIME_DOCKER TIME TASK_NODE SCOPE NODE MESSAGE SPACE FIRST_WORD
  TIME_DOCKER=$(echo "${*} " | cut -d ' ' -f 1);
  TIME=$(_log_docker_time "${TIME_DOCKER}")
  TASK_NODE=$(echo "${*} " | cut -d ' ' -f 2)
  SCOPE=$(_log_docker_scope "${TASK_NODE}");
  NODE=$(_log_docker_node "${TASK_NODE}");
  MESSAGE=$(echo "${*}" | cut -d '|' -f 2-);
  # Remove the leading space.
  SPACE=$(echo "${MESSAGE} " | cut -d ' ' -f 1)
  [ -z "${SPACE}" ] && MESSAGE=$(echo "${MESSAGE} " | cut -d ' ' -f 2-)
  FIRST_WORD=$(echo "${MESSAGE} " | cut -d ' ' -f 1);
  if _log_level "${FIRST_WORD}" >/dev/null; then
    LEVEL=${FIRST_WORD};
    MESSAGE=$(echo "${MESSAGE} " | cut -d ' ' -f 2-);
  fi
  _log_formatter "${LEVEL}" "${TIME}" "${NODE}" "${SCOPE}" "${MESSAGE}";
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
  CONFIG=$(echo "${CONFIG} " | cut -d ' ' -f 1)
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

_time_elapsed_between() {
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
  _time_elapsed_between "$(date +%s)" "${START_TIME}"
}

add_unique_to_list() {
  local OLD_LIST="${1}"
  local NEW_ITEM="${2}"
  [ -z "${OLD_LIST}" ] && echo "${NEW_ITEM}" && return 0
  echo -e "${OLD_LIST}\n${NEW_ITEM}" | sort | uniq
}

# For a givne variable name <VAR>, try to read content of <VAR>_FILE if file exists.
# otherwise echo the content of <VAR>.
read_config() {
  local CONFIG_NAME="${1}"
  [ -z "${CONFIG_NAME}" ] && return 1
  local CONFIG_FILE_NAME="${CONFIG_NAME}_FILE"
  eval "local CONFIG_FILE=\${${CONFIG_FILE_NAME}}"
  if [ -r "${CONFIG_FILE:-""}" ]; then
    cat "${CONFIG_FILE}"
    return $?
  elif [ -n "${CONFIG_FILE}" ]; then
    echo "Failed to read ${CONFIG_FILE}" >&2
    return 1
  fi
  eval "local CONFIG=\${${CONFIG_NAME}}"
  echo "${CONFIG}"
}

# If env is unset, return the default value, otherwise return the value of env
# This differentiates empty string and unset env.
read_env() {
  local VNAME="${1}"; shift
  [ -z "${VNAME}" ] && return 1
  if env | grep -q "${VNAME}="; then
    eval "echo \"\${${VNAME}}\""
  else
    echo "${@}"
  fi
  return 0
}

attach_tag_to_log_scope() {
  local TAG="${1}"
  local OLD_LOG_SCOPE="${LOG_SCOPE:-""}"
  local SEP=" "
  [ -z "${OLD_LOG_SCOPE}" ] && SEP=""
  echo "${OLD_LOG_SCOPE}${SEP}${TAG}"
}

eval_cmd() {
  local TAG="${1}"; shift;
  local CMD="${*}"
  [ -z "${CMD}" ] && return 0
  local OLD_LOG_SCOPE="${LOG_SCOPE}"
  LOG_SCOPE=$(attach_tag_to_log_scope "${TAG}")
  export LOG_SCOPE
  local LOG=
  local RETURN_VALUE=0
  log INFO "Run ${TAG} command: ${CMD}"
  if LOG=$(eval "${CMD}"); then
    echo "${LOG}" | log_lines INFO
  else
    RETURN_VALUE=$?
    echo "${LOG}" | log_lines WARN
    log WARN "${TAG} command returned a non-zero value ${RETURN_VALUE}."
  fi
  log INFO "Finish ${TAG} command."
  export LOG_SCOPE="${OLD_LOG_SCOPE}"
  return "${RETURN_VALUE}"
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
  if [ -z "${NETWORK_DNS_IP:-""}" ]; then
    echo "${NETWORK_ARG}"
    return 0
  fi
  echo "${NETWORK_ARG} --dns=${NETWORK_DNS_IP}"
}

timezone_arguments() {
  echo "--env \"TZ=${TZ}\" --mount type=bind,source=/etc/localtime,destination=/etc/localtime,ro"
}

_get_docker_command_name_arg() {
  # get <NAME> from "--name <NAME>" or "--name=<NAME>"
  echo "${@}" | tr '\n' ' ' | sed -E 's/.*--name[ =]([^ ]*).*/\1/'
}

_get_docker_command_detach() {
  if echo "${@}" | grep -q -- "--detach"; then
    echo "true"
    return 0
  fi
  echo "false"
}

docker_service_logs () {
  local SERVICE_NAME="${1}"
  local RETURN_VALUE=0
  local LOGS=
  if ! LOGS=$(docker service logs --timestamps --no-task-ids "${SERVICE_NAME}" 2>&1); then
    log ERROR "Failed to obtain logs of service ${SERVICE_NAME}."
    RETURN_VALUE=1
  fi
  echo "${LOGS}" |
  while read -r LINE; do
    _log_docker_line "${LINE}"
  done
  return "${RETURN_VALUE}"
}

docker_service_logs_follow() {
  local SERVICE_NAME="${1}"
  docker service logs --timestamps --no-task-ids --follow "${SERVICE_NAME}" 2>&1 |
  while read -r LINE; do
    _log_docker_line "${LINE}"
  done
}

_docker_service_task_states() {
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

# Usage: wait_service_state <SERVICE_NAME> [--running] [--complete]
# Wait for the service, usually a global job or a replicated job, to reach either running or complete state.
# The function returns immediately when any of the tasks of the service fails.
# In case of task failing, the function returns a non-zero value.
wait_service_state() {
  local SERVICE_NAME="${1}"; shift;
  local WAIT_RUNNING WAIT_COMPLETE;
  WAIT_RUNNING=$(echo "${@}" | grep -q -- "--running" && echo "true" || echo "false")
  WAIT_COMPLETE=$(echo "${@}" | grep -q -- "--complete" && echo "true" || echo "false")
  local RETURN_VALUE=0
  local DOCKER_CMD_ERROR=1
  local SLEEP_SECONDS=1
  local STATES=
  while STATES=$(_docker_service_task_states "${SERVICE_NAME}" 2>&1); do
    if ! ("${WAIT_RUNNING}" || "${WAIT_COMPLETE}"); then
      RETURN_VALUE=0
      DOCKER_CMD_ERROR=0
      break
    fi
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
    if [ "${NUM_LINES}" -gt 0 ]; then
      if "${WAIT_RUNNING}" && [ "${NUM_RUNS}" -eq "${NUM_LINES}" ]; then
        RETURN_VALUE=0
        DOCKER_CMD_ERROR=0
        break
      fi
      if "${WAIT_COMPLETE}" && [ "${NUM_DONES}" -eq "${NUM_LINES}" ]; then
        RETURN_VALUE=0
        DOCKER_CMD_ERROR=0
        break
      fi
      if "${WAIT_COMPLETE}" && [ "${NUM_FAILS}" -gt 0 ]; then
        # Get return value of the task from the string "task: non-zero exit (1)".
        local TASK_RETURN_VALUE=
        TASK_RETURN_VALUE=$(echo "${STATES}" | grep "Failed" | sed -n 's/.*task: non-zero exit (\([0-9]\+\)).*/\1/p')
        # Get the first error code.
        RETURN_VALUE=$(echo "${TASK_RETURN_VALUE:-1} " | cut -d ' ' -f 1)
        DOCKER_CMD_ERROR=0
        break
      fi
    fi
    sleep "${SLEEP_SECONDS}"
  done
  if [ "${DOCKER_CMD_ERROR}" != "0" ]; then
    log ERROR "Failed to obtain task states of service ${SERVICE_NAME}: ${STATES}"
    return 1
  fi
  while read -r LINE; do
    log INFO "Service ${SERVICE_NAME}: ${LINE}."
  done < <(echo "${STATES}")
  return "${RETURN_VALUE}"
}

docker_version() {
  local cver capi sver sapi
  if ! cver=$(docker version --format '{{.Client.Version}}' 2>&1);    then log ERROR "${cver}"; cver="error"; fi
  if ! capi=$(docker version --format '{{.Client.APIVersion}}' 2>&1); then log ERROR "${capi}"; capi="error"; fi
  if ! sver=$(docker version --format '{{.Server.Version}}' 2>&1);    then log ERROR "${sver}"; sver="error"; fi
  if ! sapi=$(docker version --format '{{.Server.APIVersion}}' 2>&1); then log ERROR "${sapi}"; sapi="error"; fi
  echo "Docker version client ${cver} (API ${capi}) server ${sver} (API ${sapi})"
}

docker_service_remove() {
  local SERVICE_NAME="${1}"
  if ! docker service inspect --format '{{.JobStatus}}' "${SERVICE_NAME}" >/dev/null 2>&1; then
    return 0
  fi
  log INFO "Removing service ${SERVICE_NAME}."
  local LOG=
  if ! LOG=$(docker service rm "${SERVICE_NAME}" 2>&1); then
    log ERROR "Failed to remove docker service ${SERVICE_NAME}: ${LOG}"
    return 1
  fi
  log INFO "Removed service ${SERVICE_NAME}."
  return 0
}

# We do not expect failures when using docker_global_job.
# Docker will try to restart the failed tasks.
# We do not check the converge of the service, thus some jobs may failed on some nodes.
# It is better to be used togther with wait_service_state.
docker_global_job() {
  local SERVICE_NAME=
  SERVICE_NAME=$(_get_docker_command_name_arg "${@}")
  log INFO "Starting global-job ${SERVICE_NAME}."
  local LOG=
  if ! LOG=$(docker service create --mode global-job "${@}"  2>&1); then
    log ERROR "Failed to create global-job ${SERVICE_NAME}: ${LOG}"
    return 1
  fi
  return 0
}

# A job could fail when using docker_replicated_job.
docker_replicated_job() {
  local SERVICE_NAME=
  local IS_DETACH=
  SERVICE_NAME=$(_get_docker_command_name_arg "${@}")
  IS_DETACH=$(_get_docker_command_detach "${@}")
  # Add "--detach" to work around https://github.com/docker/cli/issues/2979
  # The Docker CLI does not exit on failures.
  log INFO "Starting replicated-job ${SERVICE_NAME}."
  local LOG=
  if ! LOG=$(docker service create --mode replicated-job --detach "${@}" 2>&1); then
    log ERROR "Failed to create replicated-job ${SERVICE_NAME}: ${LOG}"
    return 1
  fi
  # If the command line does not contain '--detach', the function returns til the replicated job is complete.
  if ! "${IS_DETACH}"; then
    wait_service_state "${SERVICE_NAME}" --complete || return $?
  fi
  return 0
}

_container_status() {
  local CNAME="${1}"
  docker container inspect --format '{{.State.Status}}' "${CNAME}" 2>/dev/null
}

docker_remove() {
  local CNAME="${1}"
  local STATUS=
  STATUS=$(_container_status "${CNAME}")
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
  while ! docker run "${@}" >/dev/null; do
    if [ ${RETRIES} -ge ${MAX_RETRIES} ]; then
      echo "Failed to run docker. Reached the max retries ${MAX_RETRIES}." >&2
      return 1
    fi
    RETRIES=$((RETRIES + 1))
    sleep ${SLEEP_SECONDS}
    echo "Retry docker run (${RETRIES})."
  done
}
