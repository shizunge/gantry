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

_random_string() {
  head /dev/urandom | LANG=C tr -dc 'a-zA-Z0-9' | head -c 8
}

_pipe_name() {
  local BASE_NAME="${1:-pipe-base-name}"
  local RANDOM_STR=
  RANDOM_STR=$(_random_string)
  local TIMESTAMP=
  TIMESTAMP=$(date +%s)
  local PIPE_NAME="/tmp/${BASE_NAME}-$$-${TIMESTAMP}-${RANDOM_STR}"
  echo "${PIPE_NAME}"
}

# Run "grep -q" and avoid broken pipe errors.
grep_q() {
  # "grep -q" will exit immediately when the first line of data matches, and leading to broken pipe errors.
  grep -q -- "${@}";
  local GREP_RETURN=$?;
  # Add "cat > /dev/null" to avoid broken pipe errors.
  cat >/dev/null;
  return "${GREP_RETURN}"
}

# Similar to grep_q.
# grep case insensitively.
grep_q_i() {
  grep -q -i -- "${@}";
  local GREP_RETURN=$?;
  cat >/dev/null;
  return "${GREP_RETURN}"
}

# Extract ${POSITION}th part of the string from a single line ${SINGLE_LINE}, separated by ${DELIMITER}.
extract_string() {
  local SINGLE_LINE="${1}"
  local DELIMITER="${2}"
  local POSITION="${3}"
  # When the input contains no ${DELIMITER}, there are the expect outputs
  # * ${POSITION} is 1 -> the ${SINGLE_LINE}
  # * Other ${POSITION} -> an empty string
  # The following command(s) won't work if we do not add the ${DELIMITER} to the end of ${SINGLE_LINE}
  # * `echo "${SINGLE_LINE}" | cut -s -d "${DELIMITER}" -f 1`: actually return an empty string.
  # * `echo "${SINGLE_LINE}" | cut -d "${DELIMITER}" -f 2`: actually returns the any line that contains no delimiter.
  # We add a ${DELIMITER} to the echo command to ensure the string contains at least one ${DELIMITER},
  # to help us get the expected output above.
  # When the input contains a ${DELIMITER}, for the following command(s)
  # * `echo "${SINGLE_LINE}${DELIMITER}" | cut -d "${DELIMITER}" -f 2-`
  # we do not want to see a ${DELIMITER} at the end of the ouput,
  # therefore we do not always add the ${DELIMITER} to the end of ${SINGLE_LINE}.
  local ECHO_STRING="${SINGLE_LINE}"
  if ! echo "${SINGLE_LINE}" | grep_q "${DELIMITER}"; then
    ECHO_STRING="${SINGLE_LINE}${DELIMITER}"
  fi
  echo "${ECHO_STRING}" | cut -d "${DELIMITER}" -f "${POSITION}"
}

# echo the number of the log level.
# return 0 if LEVEL is supported.
# return 1 if LEVLE is unsupported.
_log_level() {
  local LEVEL="${1}";
  [ -z "${LEVEL}" ] && _log_level "INFO" && return 1;
  echo "${LEVEL}" | grep_q_i "^DEBUG$" && echo 0 && return 0;
  echo "${LEVEL}" | grep_q_i "^INFO$"  && echo 1 && return 0;
  echo "${LEVEL}" | grep_q_i "^WARN$"  && echo 2 && return 0;
  echo "${LEVEL}" | grep_q_i "^ERROR$" && echo 3 && return 0;
  echo "${LEVEL}" | grep_q_i "^NONE$"  && echo 4 && return 0;
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
  echo "${LEVEL}" | grep_q_i "^DEBUG$" && echo "${BLUE}" && return 0;
  echo "${LEVEL}" | grep_q_i "^INFO$"  && echo "${GREEN}" && return 0;
  echo "${LEVEL}" | grep_q_i "^WARN$"  && echo "${ORANGE}" && return 0;
  echo "${LEVEL}" | grep_q_i "^ERROR$" && echo "${RED}" && return 0;
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
  local TIME_DOCKER TIME TASK_NODE SCOPE NODE MESSAGE FIRST_WORD
  TIME_DOCKER=$(extract_string "${*}" ' ' 1)
  TIME=$(_log_docker_time "${TIME_DOCKER}")
  TASK_NODE=$(extract_string "${*}" ' ' 2)
  SCOPE=$(_log_docker_scope "${TASK_NODE}");
  NODE=$(_log_docker_node "${TASK_NODE}");
  MESSAGE=$(extract_string "${*}" '|' 2-);
  # Remove a single leading space.
  [ "${MESSAGE:0:1}" = " " ] && MESSAGE="${MESSAGE:1}"
  FIRST_WORD=$(extract_string "${MESSAGE}" ' ' 1);
  if _log_level "${FIRST_WORD}" >/dev/null; then
    LEVEL=${FIRST_WORD};
    MESSAGE=$(extract_string "${MESSAGE}" ' ' 2-);
  fi
  _log_formatter "${LEVEL}" "${TIME}" "${NODE}" "${SCOPE}" "${MESSAGE}";
}

_log_docker_multiple_lines() {
  local LINE=
  while read -r LINE; do
    _log_docker_line "${LINE}"
  done
}

# Usage: echo "${LOGS}" | log_lines INFO
log_lines() {
  local LEVEL="${1}";
  local LINE=;
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
  CONFIG=$(extract_string "${CONFIG}" ' ' 1)
  echo "${CONFIG}" | grep_q_i "true"
}

first_minus_second() {
  local NUM0="${1}"
  local NUM1="${2}"
  if is_number "${NUM0}" && is_number "${NUM1}"; then
    echo "$((NUM0 - NUM1))"
    return 0
  fi
  echo "NaN"
  return 1
}

_time_elapsed_between() {
  local TIME0="${1}"
  local TIME1="${2}"
  local SECONDS_ELAPSED=
  if ! SECONDS_ELAPSED=$(first_minus_second "${TIME0}" "${TIME1}"); then
    echo "NaN"
    return 1
  fi
  local HOUR=0
  local MIN=0
  local SEC=0
  HOUR=$((SECONDS_ELAPSED / 3600))
  local WITHIN_AN_HOUR=0
  WITHIN_AN_HOUR=$((SECONDS_ELAPSED % 3600))
  MIN=$((WITHIN_AN_HOUR / 60))
  SEC=$((WITHIN_AN_HOUR % 60))
  local TIME_STR=""
  [ "${HOUR}" != "0" ] && TIME_STR="${HOUR}h "
  if [ -n "${TIME_STR}" ] || [ "${MIN}" != "0" ]; then TIME_STR="${TIME_STR}${MIN}m "; fi
  TIME_STR="${TIME_STR}${SEC}s"
  echo "${TIME_STR}"
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
  if env | grep_q "^${VNAME}="; then
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

_eval_cmd_core() {
  local STDOUT_CMD="${1}"; shift;
  local CMD="${*}"
  local PIPE_NAME=
  PIPE_NAME="$(_pipe_name "eval-cmd-stdout-pipe")"
  mkfifo "${PIPE_NAME}"
  local PID=
  eval "${STDOUT_CMD}" < "${PIPE_NAME}" &
  PID="${!}"
  local RETURN_VALUE=
  # No redirect for stderr, unless it is done by the CMD.
  eval "${CMD}" > "${PIPE_NAME}"
  RETURN_VALUE=$?
  wait "${PID}"
  rm "${PIPE_NAME}"
  return "${RETURN_VALUE}"
}

eval_cmd() {
  local TAG="${1}"; shift;
  local CMD="${*}"
  [ -z "${CMD}" ] && return 0
  local OLD_LOG_SCOPE="${LOG_SCOPE}"
  LOG_SCOPE=$(attach_tag_to_log_scope "${TAG}")
  export LOG_SCOPE
  log INFO "Run ${TAG} command: ${CMD}"
  local LOG_CMD="log_lines INFO"
  local RETURN_VALUE=0
  _eval_cmd_core "${LOG_CMD}" "${CMD}"
  RETURN_VALUE=$?
  if [ "${RETURN_VALUE}" = "0" ]; then
    log INFO "Finish ${TAG} command."
  else
    log ERROR "Finish ${TAG} command with a non-zero return value ${RETURN_VALUE}."
  fi
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
  if echo "${@}" | grep_q "--detach=false"; then
    echo "false"
  elif echo "${@}" | grep_q "--detach"; then
    # assume we find --detach or --detach=true.
    echo "true"
  else
    echo "false"
  fi
  return 0
}

docker_service_logs() {
  local SERVICE_NAME="${1}"
  local LOG_CMD="_log_docker_multiple_lines"
  local CMD="docker service logs --timestamps --no-task-ids ${SERVICE_NAME} 2>&1"
  local RETURN_VALUE=0
  _eval_cmd_core "${LOG_CMD}" "${CMD}"
  RETURN_VALUE=$?
  [ "${RETURN_VALUE}" != 0 ] && log ERROR "Failed to obtain logs of service ${SERVICE_NAME}. Return code ${RETURN_VALUE}."
  return "${RETURN_VALUE}"
}

_docker_service_exists() {
  local SERVICE_NAME="${1}"
  docker service inspect --format '{{.ID}}' "${SERVICE_NAME}" >/dev/null 2>&1
}

_docker_wait_until_service_removed() {
  local SERVICE_NAME="${1}"
  while _docker_service_exists "${SERVICE_NAME}"; do
    sleep 1s
  done
}

# "docker service logs --follow" does not stop when the service stops.
# This function will check the status of the service and stop the "docker service logs" command.
_docker_service_logs_follow_and_stop() {
  local SERVICE_NAME="${1}"
  ! _docker_service_exists "${SERVICE_NAME}" && return 1;
  local PID=
  docker service logs --timestamps --no-task-ids --follow "${SERVICE_NAME}" 2>&1 &
  PID="${!}"
  _docker_wait_until_service_removed "${SERVICE_NAME}"
  kill "${PID}" 2>&1
}

docker_service_logs_follow() {
  local SERVICE_NAME="${1}"
  _docker_service_logs_follow_and_stop "${SERVICE_NAME}" | _log_docker_multiple_lines
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
  local LINE=
  echo "${STATES}" | while read -r LINE; do
    local NAME=
    local NODE_STATE_AND_ERROR=
    NAME=$(echo "${LINE}" | cut -d ']' -f 1 | cut -d '[' -f 2)
    NODE_STATE_AND_ERROR=$(echo "${LINE}" | cut -d ']' -f 2-)
    # We assume that the first State of each task is the latest one that we want to report.
    if ! echo "${NAME_LIST}" | grep_q "${NAME}"; then
      echo "${NODE_STATE_AND_ERROR}"
    fi
    NAME_LIST=$(echo -e "${NAME_LIST}\n${NAME}" | sort | uniq)
  done
}

# Echo the return value from the tasks.
# Return 0: All tasks reach the want state, or there is an error.
# Return 1: Keep waiting.
_all_tasks_reach_state() {
  local WANT_STATE="${1}"
  local CHECK_FAILURES="${2}"
  local STATES="${3}"
  local NUM_LINES=0
  local NUM_STATES=0
  local NUM_FAILS=0
  local LINE=
  while read -r LINE; do
    [ -z "${LINE}" ] && continue;
    NUM_LINES=$((NUM_LINES+1));
    echo "${LINE}" | grep_q "${WANT_STATE}" && NUM_STATES=$((NUM_STATES+1));
    "${CHECK_FAILURES}" && echo "${LINE}" | grep_q "Failed" && NUM_FAILS=$((NUM_FAILS+1));
  done < <(echo "${STATES}")
  if [ "${NUM_LINES}" -le 0 ]; then
    # continue
    return 1
  fi
  if [ "${NUM_STATES}" = "${NUM_LINES}" ]; then
    # break
    echo "0"
    return 0
  fi
  if [ "${NUM_FAILS}" = 0 ]; then
    # continue
    return 1
  fi
  # Get return value of the task from the string "task: non-zero exit (1)".
  local TASK_RETURN_VALUE=
  TASK_RETURN_VALUE=$(echo "${STATES}" | grep "Failed" | sed -n 's/.*task: non-zero exit (\([0-9]\+\)).*/\1/p')
  # Get the first error code.
  local RETURN_VALUE=
  RETURN_VALUE=$(extract_string "${TASK_RETURN_VALUE:-1}" ' ' 1)
  # break
  echo "${RETURN_VALUE}"
  return 0
}

# Usage: wait_service_state <SERVICE_NAME> <WANT_STATE>
# Wait for the service, usually a global job or a replicated job,
# to reach either running or complete state.
# Valid WANT_STATE includes "Running" and "Complete"
# When the WANT_STATE is complete, the function returns immediately
# when any of the tasks of the service fails.
# In case of task failing, the function returns a non-zero value.
wait_service_state() {
  local SERVICE_NAME="${1}";
  local WANT_STATE="${2}";
  local CHECK_FAILURES=false
  [ "${WANT_STATE}" = "Complete" ] && CHECK_FAILURES=true
  local SLEEP_SECONDS=1
  local DOCKER_CMD_ERROR=1
  local RETURN_VALUE=0
  local STATES=
  while STATES=$(_docker_service_task_states "${SERVICE_NAME}" 2>&1); do
    DOCKER_CMD_ERROR=0
    RETURN_VALUE=$(_all_tasks_reach_state "${WANT_STATE}" "${CHECK_FAILURES}" "${STATES}") && break
    sleep "${SLEEP_SECONDS}"
    DOCKER_CMD_ERROR=1
  done
  if [ "${DOCKER_CMD_ERROR}" != "0" ]; then
    log ERROR "Failed to obtain task states of service ${SERVICE_NAME}: ${STATES}"
    return 1
  fi
  local LINE=
  echo "${STATES}" | while read -r LINE; do
    log INFO "Service ${SERVICE_NAME}: ${LINE}."
  done
  return "${RETURN_VALUE}"
}

docker_service_remove() {
  local SERVICE_NAME="${1}"
  local POST_COMMAND="${2}"
  ! _docker_service_exists "${SERVICE_NAME}" && return 0
  log INFO "Removing service ${SERVICE_NAME}."
  local LOG=
  if ! LOG=$(docker service rm "${SERVICE_NAME}" 2>&1); then
    log ERROR "Failed to remove docker service ${SERVICE_NAME}: ${LOG}"
    return 1
  fi
  if [ -n "${POST_COMMAND}" ]; then
    eval "${POST_COMMAND}"
  fi
  log INFO "Removed service ${SERVICE_NAME}."
  return 0
}

# Works with the service started (e.g. via docker_global_job) with --detach.
docker_service_follow_logs_wait_complete() {
  local SERVICE_NAME="${1}"
  local PID=
  docker_service_logs_follow "${SERVICE_NAME}" &
  PID="${!}"
  wait_service_state "${SERVICE_NAME}" "Complete"
  docker_service_remove "${SERVICE_NAME}" "wait ${PID}"
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
    wait_service_state "${SERVICE_NAME}" "Complete" || return $?
  fi
  return 0
}

docker_version() {
  local cver capi sver sapi
  if ! cver=$(docker version --format '{{.Client.Version}}' 2>&1);    then log ERROR "${cver}"; cver="error"; fi
  if ! capi=$(docker version --format '{{.Client.APIVersion}}' 2>&1); then log ERROR "${capi}"; capi="error"; fi
  if ! sver=$(docker version --format '{{.Server.Version}}' 2>&1);    then log ERROR "${sver}"; sver="error"; fi
  if ! sapi=$(docker version --format '{{.Server.APIVersion}}' 2>&1); then log ERROR "${sapi}"; sapi="error"; fi
  echo "Docker version client ${cver} (API ${capi}) server ${sver} (API ${sapi})"
}

# echo the name of the current container.
# echo nothing if unable to find the name.
# return 1 when there is an error.
docker_current_container_name() {
  local ALL_NETWORKS=
  ALL_NETWORKS=$(docker network ls --format '{{.ID}}') || return 1;
  [ -z "${ALL_NETWORKS}" ] && return 0;
  local IPS=;
  IPS=$(ip route | grep src | sed -n "s/.* src \(\S*\).*$/\1/p");
  [ -z "${IPS}" ] && return 0;
  local GWBRIDGE_NETWORK HOST_NETWORK;
  GWBRIDGE_NETWORK=$(docker network ls --format '{{.ID}}' --filter 'name=^docker_gwbridge$') || return 1;
  HOST_NETWORK=$(docker network ls --format '{{.ID}}' --filter 'name=^host$') || return 1;
  local NID=;
  for NID in ${ALL_NETWORKS}; do
    # The output of gwbridge does not contain the container name. It looks like gateway_8f55496ce4f1/172.18.0.5/16.
    [ "${NID}" = "${GWBRIDGE_NETWORK}" ] && continue;
    # The output of host does not contain an IP.
    [ "${NID}" = "${HOST_NETWORK}" ] && continue;
    local ALL_LOCAL_NAME_AND_IP=;
    ALL_LOCAL_NAME_AND_IP=$(docker network inspect "${NID}" --format "{{range .Containers}}{{.Name}}/{{println .IPv4Address}}{{end}}") || return 1;
    local NAME_AND_IP=;
    for NAME_AND_IP in ${ALL_LOCAL_NAME_AND_IP}; do
      [ -z "${NAME_AND_IP}" ] && continue;
      # NAME_AND_IP will be in one of the following formats:
      # '<container name>/<ip>/<mask>'
      # '<container name>/' (when network mode is host)
      local CNAME CIP
      CNAME=$(extract_string "${NAME_AND_IP}" '/' 1);
      CIP=$(extract_string "${NAME_AND_IP}" '/' 2);
      # Unable to find the container IP when network mode is host.
      [ -z "${CIP}" ] && continue;
      local IP=;
      for IP in ${IPS}; do
        [ "${IP}" != "${CIP}" ] && continue;
        echo "${CNAME}";
        return 0;
      done
    done
  done
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
  local MSG=
  while ! MSG=$(docker run "${@}" 2>&1); do
    if [ ${RETRIES} -ge ${MAX_RETRIES} ]; then
      log ERROR "Failed to run docker. Reached the max retries ${MAX_RETRIES}. ${MSG}"
      return 1
    fi
    RETRIES=$((RETRIES + 1))
    sleep ${SLEEP_SECONDS}
    log WARN "Retry docker run (${RETRIES}). ${MSG}"
  done
  echo "${MSG}"
}
