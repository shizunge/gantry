#!/bin/sh
# Copyright (C) 2023-2025 Shizun Ge
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
  local PID=$$
  local TIMESTAMP=
  TIMESTAMP=$(date +%s)
  local RANDOM_STR=
  RANDOM_STR=$(_random_string)
  local PIPE_NAME="/tmp/${BASE_NAME}-${PID}-${TIMESTAMP}-${RANDOM_STR}"
  echo "${PIPE_NAME}"
}

# Usage: echo "multiple-line string" | _remove_newline
_remove_newline() {
  # sed to remove \n
  # :a - Creates a label a for looping.
  # N - Appends the next line to the pattern space.
  # $!ba - Loops back to the label a if not the last line ($! means "not last line").
  # s/\n/ /g - Substitutes all newline characters with a space.
  sed ':a;N;$!ba;s/\n/ /g'
  # Here are a few alternatives to "sed"
  # "echo without quotes" remove carriage returns, tabs and multiple spaces.
  # "echo" is faster than "tr", but it does not preserve the leading space.
  # That is why we don't use "echo" here.
  # "tr '\n' ' '" is slow and adds a space to the end of the string.
}

_get_first_word() {
  echo "${*}" | _remove_newline | sed -n -E "s/^(\S+).*/\1/p";
}

# Run "grep -q" and avoid broken pipe errors.
grep_q() {
  # "grep -q" will exit immediately when the first line of data matches, and leading to broken pipe errors.
  grep -q -- "${@}";
  local GREP_RETURN=$?;
  # Add "cat 1>/dev/null" to avoid broken pipe errors.
  cat 1>/dev/null;
  return "${GREP_RETURN}"
}

# Similar to grep_q.
# grep case insensitively.
grep_q_i() {
  grep -q -i -- "${@}";
  local GREP_RETURN=$?;
  cat 1>/dev/null;
  return "${GREP_RETURN}"
}

# Extract ${POSITION}th part of the string from a single line ${SINGLE_LINE}, separated by ${DELIMITER}.
extract_string() {
  local LINE="${1}"
  local DELIMITER="${2}"
  local POSITION="${3}"
  local SINGLE_LINE=
  SINGLE_LINE=$(echo "${LINE}" | _remove_newline)
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

# All lower or all upper. No mix.
_log_level_to_upper() {
  local LEVEL="${1}";
  # tr is slow.
  case "${LEVEL}" in
    "debug") echo "DEBUG"; ;;
    "info")  echo "INFO";  ;;
    "warn")  echo "WARN";  ;;
    "error") echo "ERROR"; ;;
    "none")  echo "NONE";  ;;
    *) echo "${LEVEL}"; ;;
  esac
}

# Return 0 if the first work is a supported level.
# Return 1 else.
_first_word_is_level() {
  local MSG="${1}"
  local LEN="${#MSG}"
  local LEVEL=
  [ "${LEN}" -lt 4 ] && return 1
  if [ "${LEN}" = 4 ] || [ "${MSG:4:1}" = " " ]; then
    LEVEL="${MSG:0:4}"
  elif [ "${LEN}" = 5 ] || [ "${MSG:5:1}" = " " ]; then
    LEVEL="${MSG:0:5}"
  else
    return 1
  fi
  LEVEL=$(_log_level_to_upper "${LEVEL}")
  case "${LEVEL}" in
    "DEBUG") return 0; ;;
    "INFO")  return 0; ;;
    "WARN")  return 0; ;;
    "ERROR") return 0; ;;
    "NONE")  return 0; ;;
    *) return 1; ;;
  esac
}

_log_skip_level_echo_color() {
  local LEVEL="${1}";
  # Ideally, one function should do one thing.
  # But by merging two functions "_log_skip" and "log_color" into one, we reduce the number of "case" to improve performance.
  # local BLUE='\033[0;34m'
  # local GREEN='\033[0;32m'
  # local ORANGE='\033[0;33m'
  # local RED='\033[0;31m'
  # local NO_COLOR='\033[0m'
  # SC2028 (info): echo may not expand escape sequences. Use printf.
  # shellcheck disable=SC2028
  case "${LEVEL}" in
    "DEBUG")   echo "\033[0;34m"; return "${2}"; ;;
    "INFO"|"") echo "\033[0;32m"; return "${3}"; ;;
    "WARN")    echo "\033[0;33m"; return "${4}"; ;;
    "ERROR")   echo "\033[0;31m"; return "${5}"; ;;
    "NONE"|*)  echo "\033[0m";    return "${6}"; ;;
  esac
}

# Echo the color for the given LEVEL.
# return 0 to skip logging.
# return 1 otherwise.
_log_skip_echo_color() {
  local TARGET_LEVEL="${1}";
  local LEVEL="${2}";
  # This is 10% faster than the following command:
  # _log_level() {
  #   local LEVEL="${1}";
  #   case "${LEVEL}" in
  #     "DEBUG") echo 0; ;;
  #     "INFO"|"") echo 1; ;;
  #     "WARN") echo 2; ;;
  #     "ERROR") echo 3; ;;
  #     "NONE"|*) echo 4; ;;
  #   esac
  # }
  # test "$(_log_level "${LEVEL}")" -lt "$(_log_level "${TARGET_LEVEL}")"; return $?
  case "${TARGET_LEVEL}" in
    "DEBUG")   _log_skip_level_echo_color "${LEVEL}" 1 1 1 1 1; ;;
    "INFO"|"") _log_skip_level_echo_color "${LEVEL}" 0 1 1 1 1; ;;
    "WARN")    _log_skip_level_echo_color "${LEVEL}" 0 0 1 1 1; ;;
    "ERROR")   _log_skip_level_echo_color "${LEVEL}" 0 0 0 1 1; ;;
    "NONE"|*)  _log_skip_level_echo_color "${LEVEL}" 0 0 0 0 1; ;;
  esac
}

_log_formatter() {
  local TARGET_LEVEL="${LOG_LEVEL:-}";
  local FORMAT="${LOG_FORMAT:-}";
  local LEVEL="${1}";
  local EPOCH="${2}";
  local LOCATION="${3}";
  local SCOPE="${4}";
  TARGET_LEVEL=$(_log_level_to_upper "${TARGET_LEVEL}")
  LEVEL=$(_log_level_to_upper "${LEVEL}")
  local LEVEL_COLOR=
  LEVEL_COLOR=$(_log_skip_echo_color "${TARGET_LEVEL}" "${LEVEL}") && return 0;
  shift 4;
  local MSG_LINE
  if [ "${FORMAT}" = "json" ]; then
    [ -z "${*}" ] && return 0
    local TIME_STR LEVEL_STR LOC_STR SCOPE_STR MSG_STR
    LEVEL_STR="\"level\":\"${LEVEL}\","
    [ -n "${LOCATION}" ] && LOC_STR="\"location\":\"${LOCATION}\","
    [ -n "${SCOPE}" ] && SCOPE_STR="\"scope\":\"${SCOPE}\","
    MSG_STR="\"message\":\"$(echo "${*}" | sed -E 's/"/\\"/g')\","
    TIME_STR="\"time\":\"$(date -d "@${EPOCH}" -Isecond)\""
    MSG_LINE="{${LEVEL_STR}${LOC_STR}${MSG_STR}${SCOPE_STR}${TIME_STR}}"
  else
    local TIME_WITH_COLOR TIME_STR LEVEL_STR LOC_STR SCOPE_STR
    TIME_WITH_COLOR=$(date -d "@${EPOCH}" +"$(_time_format)")
    # Faster for not using local variables. (tested in a micro benchmark)
    # local DGRAY='\033[1;30m'
    # local NO_COLOR='\033[0m'
    # Formatting time logically should be done inside this function.
    # But we let caller do it to reduce the number of calls of "date" to increase performance.
    TIME_STR="\033[1;30m[${TIME_WITH_COLOR}\033[1;30m]\033[0m"
    LEVEL_STR="${LEVEL_COLOR}[${LEVEL}]\033[0m "
    [ -n "${LOCATION}" ] && LOC_STR="\033[1;30m[${LOCATION}]\033[0m"
    [ -n "${SCOPE}" ] && SCOPE_STR="\033[1;30m${SCOPE}:\033[0m "
    MSG_LINE="${TIME_STR}${LOC_STR}${LEVEL_STR}${SCOPE_STR}${*}"
  fi
  echo -e "${MSG_LINE}" | _remove_newline >&2
}

_time_format() {
  # To mimik format from "date -Isecond".
  # Highlight time within the day in ISO-8601 (2024-11-23T21:50:13-08:00)
  # local DGRAY="\033[1;30m"
  # local LGRAY="\033[0;37m"
  # local NO_COLOR='\033[0m'
  # echo "${DGRAY}%Y-%m-%dT${LGRAY}%H:%M:%S${DGRAY}%z${NO_COLOR}"
  # The following is faster than the above for not using local variables. (tested in a micro benchmark)
  # Busybox date does not support %:z, only %z. So the time zone will be -0800.
  # SC2028 (info): echo may not expand escape sequences. Use printf.
  # shellcheck disable=SC2028
  echo "\033[1;30m%Y-%m-%dT\033[0;37m%H:%M:%S\033[1;30m%z\033[0m"
}

# We want to print an empty line for log without an argument. Thus we do not run the following check.
# [ -z "${1}" ] && return 0
log() {
  local LOCAL_NODE="${NODE_NAME:-}"
  local LOCAL_SCOPE="${LOG_SCOPE:-}"
  local LEVEL="INFO";
  local MESSAGE="${*}"
  if _first_word_is_level "${1}"; then
    LEVEL=$(_get_first_word "${MESSAGE}");
    MESSAGE=$(extract_string "${MESSAGE}" ' ' 2-);
  fi
  local EPOCH=
  EPOCH=$(date +%s)
  _log_formatter "${LEVEL}" "${EPOCH}" "${LOCAL_NODE}" "${LOCAL_SCOPE}" "${MESSAGE}";
}

_log_docker_time() {
  # Convert timestamps from `docker service logs`.
  # The timestamps is in UTC.
  # docker service logs --timestamps --no-task-ids <service>
  # 2023-06-22T01:20:54.535860111Z <task>@<node>    | <msg with spaces>
  local TIME_INPUT="${1}"
  # We are expecting most inputs are correct.
  # coreutils date can do the conversion in one command, thus faster.
  # busybox date does not read timezone via "-d".
  # date -d "${TIME_INPUT}" +"$(_time_format)" 2>/dev/null && return 0
  local EPOCH=
  if EPOCH=$(busybox date -d "${TIME_INPUT}" -D "%Y-%m-%dT%H:%M:%S" -u +%s 2>/dev/null); then
    echo "${EPOCH}"
    return 0
  fi
  if [ -n "${TIME_INPUT}" ]; then
    echo "${TIME_INPUT}"
  else
    date +%s
  fi
  return 1
}

# Convert logs from `docker service logs` to `log` format.
# docker service logs --timestamps --no-task-ids <service>
# 2023-06-22T01:20:54.535860111Z <task>@<node>    | <msg with spaces>
_log_docker_line() {
  local NODE="${NODE_NAME:-}"
  local SCOPE="${LOG_SCOPE:-}"
  local LEVEL="INFO";
  # Using the same regexp for all 4 parts:
  local TIME_DOCKER TASK_DOCKER NODE_DOCKER MESSAGE
  # Add a "+" before the last part to ensure we preserve the leading spaces in the message.
  read -r TIME_DOCKER TASK_DOCKER NODE_DOCKER MESSAGE < <(echo "${*}" | sed -n -E "s/^(\S+) +(\S+)@(\S+) +\| ?/\1 \2 \3 +/p");
  local EPOCH=
  EPOCH=$(_log_docker_time "${TIME_DOCKER}");
  if [ -n "${TASK_DOCKER}" ] || [ -n "${NODE_DOCKER}" ] || [ -n "${MESSAGE}" ]; then
    NODE="${NODE_DOCKER}"
    SCOPE="${TASK_DOCKER}"
    # Remove the extra "+" we added above for preserving the leading spaces.
    MESSAGE="${MESSAGE:1}"
    if _first_word_is_level "${MESSAGE}"; then
      LEVEL=$(_get_first_word "${MESSAGE}");
      MESSAGE=$(extract_string "${MESSAGE}" ' ' 2-);
    fi
  else
    # All three are empty, sed failure indicates errors.
    # format error, imply that we receive an error message from the "docker service logs" command.
    LEVEL="ERROR"
    MESSAGE="${*}"
  fi
  _log_formatter "${LEVEL}" "${EPOCH}" "${NODE}" "${SCOPE}" "${MESSAGE}";
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
  if [ -z "${LEVEL}" ]; then
    while read -r LINE; do
      [ -z "${LINE}" ] && continue;
      log "${LINE}";
    done
  else
    while read -r LINE; do
      [ -z "${LINE}" ] && continue;
      log "${LEVEL}" "${LINE}";
    done
  fi
}

is_number() {
  [ "${1}" -eq "${1}" ] 2>/dev/null;
}

is_true() {
  local CONFIG="${1}"
  echo "${CONFIG}" | grep_q_i "^true$"
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

# Return 0 if not timeout
# Return 1 if timeout
# Return 2 if error
_check_timeout() {
  local TIMEOUT_SECONDS="${1}"
  local START_TIME="${2}"
  local MESSAGE="${3}"
  ! is_number "${TIMEOUT_SECONDS}" && log ERROR "TIMEOUT_SECONDS must be a number." && return 2
  ! is_number "${START_TIME}" && log ERROR "START_TIME must be a number." && return 2
  local SECONDS_ELAPSED=
  SECONDS_ELAPSED=$(first_minus_second "$(date +%s)" "${START_TIME}")
  if [ "${SECONDS_ELAPSED}" -ge "${TIMEOUT_SECONDS}" ]; then
    [ -n "${MESSAGE}" ] && log ERROR "${MESSAGE} timeout after ${SECONDS_ELAPSED} seconds."
    return 1
  fi
  return 0
}

add_unique_to_list() {
  local OLD_LIST="${1}"
  local NEW_ITEM="${2}"
  [ -z "${OLD_LIST}" ] && echo "${NEW_ITEM}" && return 0
  echo -e "${OLD_LIST}\n${NEW_ITEM}" | sort | uniq
}

# For a given variable name <VAR>, try to read content of <VAR>_FILE if file exists.
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
    echo "Failed to read file ${CONFIG_FILE}" >&2
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
  local OLD_LOG_SCOPE="${LOG_SCOPE:-}"
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

# When the command returns 0:
# Echo stdout and log stderr as a warning. Return 0.
# When the command returns non-zero:
# Echo stdout + stderr. Return the same value from the docker command.
run_cmd() {
  local STDERR_STR=
  local RETURN_VALUE=
  # Use "3>&2 2>&1 1>&3" to swap stdout and stderr
  { STDERR_STR=$("${@}" 3>&2 2>&1 1>&3); } 2>&1
  RETURN_VALUE=$?

  if [ -n "${STDERR_STR}" ]; then
    if [ "${RETURN_VALUE}" = 0 ]; then
      log WARN "${STDERR_STR} (From command: ${*})"
    else
      echo "${STDERR_STR}"
    fi
  fi
  return "${RETURN_VALUE}"
}

swarm_network_arguments() {
  if [ -z "${NETWORK_NAME}" ]; then
    echo ""
    return 0
  fi
  local RETURN_VALUE=
  NETWORK_NAME=$(run_cmd docker network ls --filter "name=${NETWORK_NAME}" --format '{{.Name}}')
  RETURN_VALUE=$?
  if [ "${RETURN_VALUE}" != "0" ] || [ -z "${NETWORK_NAME}" ]; then
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
  echo "${@}" | tr '\n' ' ' | sed -n -E 's/.*--name[ =](\S*).*/\1/p'
}

_get_docker_command_detach() {
  echo "${@}" | grep_q "--detach=false" && return 1;
  # assume we find --detach or --detach=true.
  echo "${@}" | grep_q "--detach" && return 0;
  return 1;
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
  docker service inspect --format '{{.ID}}' "${SERVICE_NAME}" 1>/dev/null 2>/dev/null
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
  _docker_service_exists "${SERVICE_NAME}" || return 1;
  local PID=
  docker service logs --timestamps --no-task-ids --follow "${SERVICE_NAME}" 2>&1 &
  PID="${!}"
  _docker_wait_until_service_removed "${SERVICE_NAME}"
  # Use kill signal to avoid an additional "context canceled" message from the Term or Int signal.
  kill -kill "${PID}" 2>&1
}

docker_service_logs_follow() {
  local SERVICE_NAME="${1}"
  _docker_service_logs_follow_and_stop "${SERVICE_NAME}" | _log_docker_multiple_lines
}

_docker_service_task_states() {
  local SERVICE_NAME="${1}"
  # We won't get the return value of the command via $? if we use "local STATES=$(command)".
  local STATES=
  if ! STATES=$(run_cmd docker service ps --no-trunc --format '[{{.Name}}][{{.Node}}] {{.CurrentState}} {{.Error}}' "${SERVICE_NAME}"); then
    log ERROR "${STATES}"
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
  TASK_RETURN_VALUE=$(echo "${STATES}" | grep "Failed" | sed -n -E 's/.*task: non-zero exit \(([0-9]+)\).*/\1/p')
  # Get the first error code.
  local RETURN_VALUE=
  RETURN_VALUE=$(_get_first_word "${TASK_RETURN_VALUE:-1}")
  # break
  echo "${RETURN_VALUE}"
  return 0
}

# Usage: wait_service_state <SERVICE_NAME> [WANT_STATE] [timeout in seconds]
# Wait for the service, usually a global job or a replicated job, to reach either running or complete state.
# Valid WANT_STATE includes "Running" and "Complete"
# When the WANT_STATE is complete, the function returns immediately when any of the tasks of the service fails.
# In case of task failing, the function returns the first failing task's return value.
# When the WANT_STATE is empty, this function reports the status of all tasks and then returns.
wait_service_state() {
  local SERVICE_NAME="${1}";
  local WANT_STATE="${2}";
  local TIMEOUT_SECONDS="${3}";
  local CHECK_FAILURES=false
  [ "${WANT_STATE}" = "Complete" ] && CHECK_FAILURES=true
  local SLEEP_SECONDS=1
  local START_TIME=
  START_TIME=$(date +%s)
  local RETURN_VALUE=0
  local DOCKER_CMD_ERROR=1
  local STATES=
  while STATES=$(_docker_service_task_states "${SERVICE_NAME}"); do
    DOCKER_CMD_ERROR=0
    RETURN_VALUE=$(_all_tasks_reach_state "${WANT_STATE}" "${CHECK_FAILURES}" "${STATES}") && break
    local TIMEOUT_MESSAGE="wait_service_state ${SERVICE_NAME} ${WANT_STATE}"
    [ -n "${TIMEOUT_SECONDS}" ] && ! _check_timeout "${TIMEOUT_SECONDS}" "${START_TIME}" "${TIMEOUT_MESSAGE}" && RETURN_VALUE=2 && break;
    sleep "${SLEEP_SECONDS}"
    DOCKER_CMD_ERROR=1
  done
  if [ "${DOCKER_CMD_ERROR}" != "0" ]; then
    log ERROR "Failed to obtain task states of service ${SERVICE_NAME}."
    return 1
  fi
  local LINE=
  echo "${STATES}" | while read -r LINE; do
    log INFO "Service ${SERVICE_NAME}: ${LINE}."
  done
  return "${RETURN_VALUE}"
}

sanitize_service_name() {
  local SERVICE_NAME="${1}"
  [ "${#SERVICE_NAME}" -gt 63 ] && SERVICE_NAME=${SERVICE_NAME:0:63}
  echo "${SERVICE_NAME}" | sed -E 's/[^0-9a-zA-Z]/_/g' | sed -E 's/^[0-9]/A/' | sed -E 's/^_/B/'
}

docker_service_remove() {
  local SERVICE_NAME="${1}"
  local POST_COMMAND="${2}"
  _docker_service_exists "${SERVICE_NAME}" || return 0
  log DEBUG "Removing service ${SERVICE_NAME}."
  local LOG=
  if ! LOG=$(run_cmd docker service rm "${SERVICE_NAME}"); then
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
# It is better to be used together with wait_service_state.
docker_global_job() {
  local SERVICE_NAME=
  SERVICE_NAME=$(_get_docker_command_name_arg "${@}")
  log INFO "Starting global-job ${SERVICE_NAME}."
  local LOG=
  if ! LOG=$(run_cmd docker service create --mode global-job "${@}"); then
    log ERROR "Failed to create global-job ${SERVICE_NAME}: ${LOG}"
    return 1
  fi
  return 0
}

# A job could fail when using docker_replicated_job.
docker_replicated_job() {
  local SERVICE_NAME=
  SERVICE_NAME=$(_get_docker_command_name_arg "${@}")
  # Add "--detach" to work around https://github.com/docker/cli/issues/2979
  # The Docker CLI does not exit on failures.
  log INFO "Starting replicated-job ${SERVICE_NAME}."
  local LOG=
  if ! LOG=$(run_cmd docker service create --mode replicated-job --detach "${@}"); then
    log ERROR "Failed to create replicated-job ${SERVICE_NAME}: ${LOG}"
    return 1
  fi
  # If the command line does not contain '--detach', the function returns til the replicated job is complete.
  if ! _get_docker_command_detach "${@}"; then
    wait_service_state "${SERVICE_NAME}" "Complete" || return $?
  fi
  return 0
}

docker_version() {
  local cver capi sver sapi
  if ! cver=$(run_cmd docker version --format '{{.Client.Version}}');    then log ERROR "${cver}"; cver="error"; fi
  if ! capi=$(run_cmd docker version --format '{{.Client.APIVersion}}'); then log ERROR "${capi}"; capi="error"; fi
  if ! sver=$(run_cmd docker version --format '{{.Server.Version}}');    then log ERROR "${sver}"; sver="error"; fi
  if ! sapi=$(run_cmd docker version --format '{{.Server.APIVersion}}'); then log ERROR "${sapi}"; sapi="error"; fi
  echo "Docker version client ${cver} (API ${capi}) server ${sver} (API ${sapi})"
}

# echo the name of the current container.
# echo nothing if unable to find the name.
# return 1 when there is an error.
docker_current_container_name() {
  local ALL_NETWORKS=
  ALL_NETWORKS=$(run_cmd docker network ls --format '{{.ID}}') || return 1;
  [ -z "${ALL_NETWORKS}" ] && return 0;
  local IPS=;
  # Get the string after "src":
  # 172.17.0.0/16 dev docker0 proto kernel scope link src 172.17.0.1 linkdown
  IPS=$(ip route | grep src | sed -n -E "s/.* src (\S+).*$/\1/p");
  [ -z "${IPS}" ] && return 0;
  local GWBRIDGE_NETWORK HOST_NETWORK;
  GWBRIDGE_NETWORK=$(run_cmd docker network ls --format '{{.ID}}' --filter 'name=^docker_gwbridge$') || return 1;
  HOST_NETWORK=$(run_cmd docker network ls --format '{{.ID}}' --filter 'name=^host$') || return 1;
  local NID=;
  for NID in ${ALL_NETWORKS}; do
    # The output of gwbridge does not contain the container name. It looks like gateway_8f55496ce4f1/172.18.0.5/16.
    [ "${NID}" = "${GWBRIDGE_NETWORK}" ] && continue;
    # The output of host does not contain an IP.
    [ "${NID}" = "${HOST_NETWORK}" ] && continue;
    local ALL_LOCAL_NAME_AND_IP=;
    ALL_LOCAL_NAME_AND_IP=$(run_cmd docker network inspect "${NID}" --format "{{range .Containers}}{{.Name}}/{{println .IPv4Address}}{{end}}") || return 1;
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
  log DEBUG "Removing container ${CNAME}."
  if [ "${STATUS}" = "running" ]; then
    docker container stop "${CNAME}" 1>/dev/null 2>/dev/null
  fi
  # If the container is created with "--rm", it will be removed automatically when being stopped.
  docker container rm -f "${CNAME}" 1>/dev/null;
  log INFO "Removed container ${CNAME}."
}

docker_run() {
  local TIMEOUT_SECONDS=10
  local SLEEP_SECONDS=1
  local START_TIME=
  START_TIME=$(date +%s)
  local LOG=
  while ! LOG=$(run_cmd docker container run "${@}"); do
    _check_timeout "${TIMEOUT_SECONDS}" "${START_TIME}" "docker_run" || return 1
    sleep ${SLEEP_SECONDS}
    log WARN "Retry docker container run (${SECONDS_ELAPSED}s). ${LOG}"
  done
  echo "${LOG}"
}
