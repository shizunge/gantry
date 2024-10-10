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

# read_env returns empty string if ENV_VALUE is set to empty, in which case we want to use the DEFAULT_VALUE.
_read_env_default() {
  local ENV_NAME="${1}"
  local DEFAULT_VALUE="${2}"
  local READ_VALUE=
  READ_VALUE=$(read_env "${ENV_NAME}" "${DEFAULT_VALUE}")
  local VALUE="${READ_VALUE}"
  [ -z "${VALUE}" ] && VALUE="${DEFAULT_VALUE}"
  echo "${VALUE}"
}

# Read a number from an environment variable. Log an error when it is not a number.
gantry_read_number() {
  local ENV_NAME="${1}"
  local DEFAULT_VALUE="${2}"
  if ! is_number "${DEFAULT_VALUE}"; then
    log ERROR "DEFAULT_VALUE must be a number. Got \"${DEFAULT_VALUE}\"."
    return 1
  fi
  local VALUE=
  VALUE=$(_read_env_default "${ENV_NAME}" "${DEFAULT_VALUE}")
  if ! is_number "${VALUE}"; then
    local READ_VALUE=
    READ_VALUE=$(read_env "${ENV_NAME}" "${DEFAULT_VALUE}")
    log ERROR "${ENV_NAME} must be a number. Got \"${READ_VALUE}\"."
    return 1;
  fi
  echo "${VALUE}"
}

_get_label_from_service() {
  local SERVICE_NAME="${1}"
  local LABEL="${2}"
  local VALUE=
  if ! VALUE=$(docker service inspect -f "{{index .Spec.Labels \"${LABEL}\"}}" "${SERVICE_NAME}" 2>&1); then
    log ERROR "Failed to obtain the value of label ${LABEL} from service ${SERVICE_NAME}. ${VALUE}"
    return 1
  fi
  echo "${VALUE}"
}

# Read a number from an environment variable. Log an error when it is not a number.
_read_env_or_label() {
  local SERVICE_NAME="${1}"
  local ENV_NAME="${2}"
  local LABEL="${3}"
  local DEFAULT_VALUE="${4}"
  local LABEL_VALUE=
  LABEL_VALUE=$(_get_label_from_service "${SERVICE_NAME}" "${LABEL}")
  if [ -n "${LABEL_VALUE}" ]; then
    log DEBUG "Use value \"${LABEL_VALUE}\" from label ${LABEL} on the service ${SERVICE_NAME}."
    echo "${LABEL_VALUE}"
    return 0
  fi
  local VALUE=
  VALUE=$(_read_env_default "${ENV_NAME}" "${DEFAULT_VALUE}")
  echo "${VALUE}"
}


_login_registry() {
  local USER="${1}"
  local PASSWORD="${2}"
  local HOST="${3}"
  local CONFIG="${4}"
  if [ -z "${USER}" ] && [ -z "${PASSWORD}" ] && [ -z "${HOST}" ] && [ -z "${CONFIG}" ]; then
    return 0
  fi
  [ -z "${USER}" ] && log ERROR "USER is empty." && return 1
  [ -z "${PASSWORD}" ] && log ERROR "PASSWORD is empty." && return 1
  local DOCKER_CONFIG=
  local CONFIG_MESSAGE=" ${HOST}"
  if [ -z "${HOST}" ]; then
   log WARN "HOST is empty. Will login to the default registry."
   CONFIG_MESSAGE=""
  fi
  if [ -n "${CONFIG}" ]; then
    DOCKER_CONFIG="--config ${CONFIG}"
    CONFIG_MESSAGE="${CONFIG_MESSAGE} for config ${CONFIG}"
  fi
  local LOGIN_MSG=
  # SC2086: Double quote to prevent globbing and word splitting.
  # shellcheck disable=SC2086
  if ! LOGIN_MSG=$(echo "${PASSWORD}" | docker ${DOCKER_CONFIG} login --username="${USER}" --password-stdin "${HOST}" 2>&1); then
    log ERROR "Failed to login to registry${CONFIG_MESSAGE}. ${LOGIN_MSG}"
    return 1
  fi
  log INFO "Logged into registry${CONFIG_MESSAGE}. ${LOGIN_MSG}"
  return 0
}

gantry_read_registry_username() {
  read_config GANTRY_REGISTRY_USER
}

gantry_read_registry_password() {
  read_config GANTRY_REGISTRY_PASSWORD
}

gantry_read_registry_host() {
  read_config GANTRY_REGISTRY_HOST
}

_authenticate_to_registries() {
  local CONFIGS_FILE="${GANTRY_REGISTRY_CONFIGS_FILE:-""}"
  local ACCUMULATED_ERRORS=0
  local CONFIG HOST PASSWORD USER
  if ! CONFIG=$(read_config GANTRY_REGISTRY_CONFIG 2>&1); then
    log ERROR "Failed to read registry CONFIG: ${CONFIG}"
    ACCUMULATED_ERRORS=$((ACCUMULATED_ERRORS + 1))
    CONFIG=
  fi
  if ! HOST=$(gantry_read_registry_host 2>&1); then
    log ERROR "Failed to read registry HOST: ${HOST}"
    ACCUMULATED_ERRORS=$((ACCUMULATED_ERRORS + 1))
    HOST=
  fi
  if ! PASSWORD=$(gantry_read_registry_password 2>&1); then
    log ERROR "Failed to read registry PASSWORD: ${PASSWORD}"
    ACCUMULATED_ERRORS=$((ACCUMULATED_ERRORS + 1))
    PASSWORD=
  fi
  if ! USER=$(gantry_read_registry_username 2>&1); then
    log ERROR "Failed to read registry USER: ${USER}"
    ACCUMULATED_ERRORS=$((ACCUMULATED_ERRORS + 1))
    USER=
  fi
  if [ "${ACCUMULATED_ERRORS}" -gt 0 ]; then
    log ERROR "Skip logging in due to previous error(s)."
  else
    _login_registry "${USER}" "${PASSWORD}" "${HOST}" "${CONFIG}"
    ACCUMULATED_ERRORS=$((ACCUMULATED_ERRORS + $?))
  fi
  if [ -z "${CONFIGS_FILE}" ]; then
    [ "${ACCUMULATED_ERRORS}" -gt 0 ] && return 1
    return 0
  fi
  if [ ! -r "${CONFIGS_FILE}" ]; then
    log ERROR "Failed to read CONFIGS_FILE ${CONFIGS_FILE}."
    return 1
  fi
  local LINE_NUM=0
  local LINE=
  while read -r LINE; do
    LINE_NUM=$((LINE_NUM+1))
    # skip comments
    [ -z "${LINE}" ] && continue
    [ "${LINE:0:1}" = "#" ] && continue
    LINE=$(echo "${LINE}" | tr '\t' ' ')
    local OTHERS=
    CONFIG=$(echo "${LINE} " | cut -d ' ' -f 1)
    HOST=$(echo "${LINE} " | cut -d ' ' -f 2)
    USER=$(echo "${LINE} " | cut -d ' ' -f 3)
    PASSWORD=$(echo "${LINE} " | cut -d ' ' -f 4)
    OTHERS=$(echo "${LINE} " | cut -d ' ' -f 5-)
    local ERROR_MSG=
    if [ -n "${OTHERS}" ]; then
      ERROR_MSG="Found extra item(s)."
    fi
    if [ -z "${CONFIG}" ] || [ -z "${HOST}" ] || [ -z "${USER}" ] || [ -z "${PASSWORD}" ]; then
      ERROR_MSG="Missing item(s)."
    fi
    if [ -n "${ERROR_MSG}" ]; then
      log ERROR "CONFIGS_FILE ${CONFIGS_FILE} line ${LINE_NUM} format error. ${ERROR_MSG} A line should contains exactly \"<CONFIG> <HOST> <USER> <PASSWORD>\"."
      ACCUMULATED_ERRORS=$((ACCUMULATED_ERRORS + 1))
      continue
    fi
    _login_registry "${USER}" "${PASSWORD}" "${HOST}" "${CONFIG}"
    ACCUMULATED_ERRORS=$((ACCUMULATED_ERRORS + $?))
  done < <(cat "${CONFIGS_FILE}"; echo;)
  [ "${ACCUMULATED_ERRORS}" -gt 0 ] && return 1
  return 0
}

_send_notification() {
  local TYPE="${1}"
  local TITLE="${2}"
  local BODY="${3}"
  if ! type notify_summary >/dev/null 2>&1; then
    return 0
  fi
  notify_summary "${TYPE}" "${TITLE}" "${BODY}"
}

# We want the static variables live longer than a function.
# However if we call the function in a subprocess, which could be casued by
# 1. pipe, e.g. echo "message" | my_function
# 2. assign to a variable, e.g. MY_VAR=$(my_function)
# and changing the static variables, the value won't go back to the parent process.
# So here we use the file system to pass value between multiple processes.
_get_static_variables_folder() {
  local INDIRECT_FILE="/tmp/gantry-STATIC_VARIABLES_FOLDER"
  if [ -z "${STATIC_VARIABLES_FOLDER}" ]; then
    if [ -e "${INDIRECT_FILE}" ]; then
      STATIC_VARIABLES_FOLDER=$(head -1 "${INDIRECT_FILE}")
    fi
  fi
  if [ -d "${STATIC_VARIABLES_FOLDER}" ]; then
    echo "${STATIC_VARIABLES_FOLDER}"
    return 0
  fi
  while ! STATIC_VARIABLES_FOLDER=$(mktemp -d); do log ERROR "\"mktemp -d\" failed"; done
  log DEBUG "Created STATIC_VARIABLES_FOLDER ${STATIC_VARIABLES_FOLDER}"
  echo "${STATIC_VARIABLES_FOLDER}" > "${INDIRECT_FILE}"
  export STATIC_VARIABLES_FOLDER
  echo "${STATIC_VARIABLES_FOLDER}"
}

_remove_static_variables_folder() {
  local INDIRECT_FILE="/tmp/gantry-STATIC_VARIABLES_FOLDER"
  rm "${INDIRECT_FILE}" >/dev/null 2>&1
  [ -z "${STATIC_VARIABLES_FOLDER}" ] && return 0
  local TO_REMOVE_STATIC_VARIABLES_FOLDER=
  TO_REMOVE_STATIC_VARIABLES_FOLDER="$(_get_static_variables_folder)"
  log DEBUG "Removing STATIC_VARIABLES_FOLDER ${TO_REMOVE_STATIC_VARIABLES_FOLDER}"
  export STATIC_VARIABLES_FOLDER=
  rm -r "${TO_REMOVE_STATIC_VARIABLES_FOLDER}"
}

_create_static_variables_folder() {
  # In case previous run did not finish gracefully.
  # We need a refresh folder to store the lists of updated services and errors.
  _remove_static_variables_folder
  STATIC_VARIABLES_FOLDER=$(_get_static_variables_folder)
  export STATIC_VARIABLES_FOLDER
}

_lock() {
  local NAME="${1}"
  local LOCK_NAME=
  LOCK_NAME="$(_get_static_variables_folder)/${NAME}-LOCK"
  while ! mkdir "${LOCK_NAME}" >/dev/null 2>&1; do sleep 0.001; done
}

_unlock() {
  local NAME="${1}"
  local LOCK_NAME=
  LOCK_NAME="$(_get_static_variables_folder)/${NAME}-LOCK"
  rm -r "${LOCK_NAME}" >/dev/null 2>&1
}

_static_variable_read_list_core() {
  local LIST_NAME="${1}"
  [ -z "${LIST_NAME}" ] && log ERROR "LIST_NAME is empty." && return 1
  local FILE_NAME=
  FILE_NAME="$(_get_static_variables_folder)/${LIST_NAME}"
  [ ! -e "${FILE_NAME}" ] && touch "${FILE_NAME}"
  cat "${FILE_NAME}"
}

_static_variable_add_unique_to_list_core() {
  local LIST_NAME="${1}"
  local VALUE="${2}"
  [ -z "${LIST_NAME}" ] && log ERROR "LIST_NAME is empty." && return 1
  local FILE_NAME=
  FILE_NAME="$(_get_static_variables_folder)/${LIST_NAME}"
  local OLD_LIST NEW_LIST
  OLD_LIST=$(_static_variable_read_list_core "${LIST_NAME}")
  NEW_LIST=$(add_unique_to_list "${OLD_LIST}" "${VALUE}")
  echo "${NEW_LIST}" > "${FILE_NAME}"
}

_static_variable_pop_list_core() {
  local LIST_NAME="${1}"
  [ -z "${LIST_NAME}" ] && log ERROR "LIST_NAME is empty." && return 1
  local FILE_NAME=
  FILE_NAME="$(_get_static_variables_folder)/${LIST_NAME}"
  [ ! -e "${FILE_NAME}" ] && touch "${FILE_NAME}"
  local ITEM=
  ITEM=$(head -1 "${FILE_NAME}")
  local NEW_LIST=
  NEW_LIST=$(tail -n+2 "${FILE_NAME}")
  echo "${NEW_LIST}" > "${FILE_NAME}"
  echo "${ITEM}"
}

_static_variable_read_list() {
  local LIST_NAME="${1}"
  _lock "${LIST_NAME}"
  _static_variable_read_list_core "${@}"
  local RETURN_VALUE=$?
  _unlock "${LIST_NAME}"
  return "${RETURN_VALUE}"
}

# Add unique value to a static variable which holds a list.
_static_variable_add_unique_to_list() {
  local LIST_NAME="${1}"
  _lock "${LIST_NAME}"
  _static_variable_add_unique_to_list_core "${@}"
  local RETURN_VALUE=$?
  _unlock "${LIST_NAME}"
  return "${RETURN_VALUE}"
}

# echo the first item in the list and remove the first item from the list.
_static_variable_pop_list() {
  local LIST_NAME="${1}"
  _lock "${LIST_NAME}"
  _static_variable_pop_list_core "${@}"
  local RETURN_VALUE=$?
  _unlock "${LIST_NAME}"
  return "${RETURN_VALUE}"
}

_remove_container() {
  local IMAGE="${1}";
  local STATUS="${2}";
  local CIDS=
  if ! CIDS=$(docker container ls --all --filter "ancestor=${IMAGE}" --filter "status=${STATUS}" --format '{{.ID}}' 2>&1); then
    log ERROR "Failed to list ${STATUS} containers with image ${IMAGE}.";
    echo "${CIDS}" | log_lines ERROR
    return 1;
  fi
  local CID CNAME CRM_MSG
  for CID in ${CIDS}; do
    CNAME=$(docker container inspect --format '{{.Name}}' "${CID}");
    if ! CRM_MSG=$(docker container rm "${CID}" 2>&1); then
      log ERROR "Failed to remove ${STATUS} container ${CNAME}, which is using image ${IMAGE}.";
      echo "${CRM_MSG}" | log_lines ERROR
      continue;
    fi
    log INFO "Removed ${STATUS} container ${CNAME}. It was using image ${IMAGE}.";
  done
}

gantry_remove_images() {
  local IMAGES_TO_REMOVE="${1}"
  local IMAGE RMI_MSG
  log DEBUG "$(docker_version)"
  for IMAGE in ${IMAGES_TO_REMOVE}; do
    if ! docker image inspect "${IMAGE}" 1>/dev/null 2>&1 ; then
      log DEBUG "There is no image ${IMAGE} on the node.";
      continue;
    fi
    _remove_container "${IMAGE}" exited;
    _remove_container "${IMAGE}" dead;
    if ! RMI_MSG=$(docker rmi "${IMAGE}" 2>&1); then
      log ERROR "Failed to remove image ${IMAGE}.";
      echo "${RMI_MSG}" | log_lines ERROR
      continue;
    fi
    log INFO "Removed image ${IMAGE}.";
  done
  log INFO "Done removing images.";
}

_remove_images() {
  local CLEANUP_IMAGES="${GANTRY_CLEANUP_IMAGES:-"true"}"
  local CLEANUP_IMAGES_OPTIONS="${GANTRY_CLEANUP_IMAGES_OPTIONS:-""}"
  # Use this image when not running gantry as a docker swarm service.
  local DEFAULT_IMAGES_REMOVER="${GANTRY_CLEANUP_IMAGES_REMOVER:="ghcr.io/shizunge/gantry"}"
  if ! is_true "${CLEANUP_IMAGES}"; then
    log INFO "Skip removing images."
    return 0
  fi
  local SERVICE_NAME="${1:-"gantry-image-remover"}"
  SERVICE_NAME=$(echo "${SERVICE_NAME}" | tr ' ' '-')
  docker_service_remove "${SERVICE_NAME}"
  local IMAGES_TO_REMOVE=
  IMAGES_TO_REMOVE=$(_static_variable_read_list STATIC_VAR_IMAGES_TO_REMOVE)
  if [ -z "${IMAGES_TO_REMOVE}" ]; then
    log INFO "No images to remove."
    return 0
  fi
  local IMAGE_NUM=
  IMAGE_NUM=$(_get_number_of_elements "${IMAGES_TO_REMOVE}")
  log INFO "Removing ${IMAGE_NUM} image(s):"
  for I in $(echo "${IMAGES_TO_REMOVE}" | tr '\n' ' '); do
    log INFO "- ${I}"
  done
  local IMAGES_REMOVER=
  IMAGES_REMOVER=$(_get_service_image "$(gantry_current_service_name)")
  [ -z "${IMAGES_REMOVER}" ] && IMAGES_REMOVER="${DEFAULT_IMAGES_REMOVER}"
  log DEBUG "Set IMAGES_REMOVER=${IMAGES_REMOVER}"
  local IMAGES_TO_REMOVE_LIST=
  IMAGES_TO_REMOVE_LIST=$(echo "${IMAGES_TO_REMOVE}" | tr '\n' ' ')
  [ -n "${CLEANUP_IMAGES_OPTIONS}" ] && log DEBUG "Adding options \"${CLEANUP_IMAGES_OPTIONS}\" to the global job ${SERVICE_NAME}."
  # SC2086: Double quote to prevent globbing and word splitting.
  # shellcheck disable=SC2086
  docker_global_job --name "${SERVICE_NAME}" \
    --restart-condition on-failure \
    --restart-max-attempts 1 \
    --mount type=bind,source=/var/run/docker.sock,destination=/var/run/docker.sock \
    --env "GANTRY_IMAGES_TO_REMOVE=${IMAGES_TO_REMOVE_LIST}" \
    ${CLEANUP_IMAGES_OPTIONS} \
    "${IMAGES_REMOVER}";
  wait_service_state "${SERVICE_NAME}"
  docker_service_logs "${SERVICE_NAME}"
  docker_service_remove "${SERVICE_NAME}"
}

_report_services_list() {
  local PRE="${1}"; shift
  local POST="${1}"; shift
  local LIST="${*}"
  local NUM=
  NUM=$(_get_number_of_elements "${LIST}")
  local TITLE=
  [ -n "${PRE}" ] && TITLE="${PRE} "
  TITLE="${TITLE}${NUM} service(s)"
  [ -n "${POST}" ] && TITLE="${TITLE} ${POST}"
  echo "${TITLE}:"
  local ITEM=
  for ITEM in ${LIST}; do
    echo "- ${ITEM}"
  done
}

_report_services_from_static_variable() {
  local VARIABLE_NAME="${1}"
  local PRE="${2}"
  local POST="${3}"
  local EMPTY="${4}"
  local LIST=
  LIST=$(_static_variable_read_list "${VARIABLE_NAME}")
  if [ -z "${LIST}" ]; then
    echo "${EMPTY}"
    return 0
  fi
  _report_services_list "${PRE}" "${POST}" "${LIST}"
}

_get_number_of_elements() {
  local LIST="${*}"
  [ -z "${LIST}" ] && echo 0 && return 0
  # SC2086: Double quote to prevent globbing and word splitting.
  # shellcheck disable=SC2086
  set ${LIST}
  local NUM=$#
  echo "${NUM}"
}

_get_number_of_elements_in_static_variable() {
  local VARIABLE_NAME="${1}"
  local LIST=
  LIST=$(_static_variable_read_list "${VARIABLE_NAME}")
  NUM=$(_get_number_of_elements "${LIST}")
  echo "${NUM}"
}

_report_services() {
  local CONDITION="${GANTRY_NOTIFICATION_CONDITION:-"all"}"
  local STACK="${1:-gantry}"
  # ACCUMULATED_ERRORS is the number of errors that are not caused by updating.
  local ACCUMULATED_ERRORS="${2:-0}"
  if ! is_number "${ACCUMULATED_ERRORS}"; then log WARN "ACCUMULATED_ERRORS \"${ACCUMULATED_ERRORS}\" is not a number." && ACCUMULATED_ERRORS=0; fi

  local UPDATED_MSG=
  UPDATED_MSG=$(_report_services_from_static_variable STATIC_VAR_SERVICES_UPDATED "" "updated" "No services updated.")
  echo "${UPDATED_MSG}" | log_lines INFO

  local FAILED_MSG=
  FAILED_MSG=$(_report_services_from_static_variable STATIC_VAR_SERVICES_UPDATE_FAILED "" "update failed")
  echo "${FAILED_MSG}" | log_lines ERROR

  local ERROR_MSG=
  ERROR_MSG=$(_report_services_from_static_variable STATIC_VAR_SERVICES_UPDATE_INPUT_ERROR "Skip updating" "due to error(s)")
  echo "${ERROR_MSG}" | log_lines ERROR

  # Send notification
  local NUM_UPDATED NUM_FAILED NUM_ERRORS
  NUM_UPDATED=$(_get_number_of_elements_in_static_variable STATIC_VAR_SERVICES_UPDATED)
  NUM_FAILED=$(_get_number_of_elements_in_static_variable STATIC_VAR_SERVICES_UPDATE_FAILED)
  NUM_ERRORS=$(_get_number_of_elements_in_static_variable STATIC_VAR_SERVICES_UPDATE_INPUT_ERROR)
  if [ "${NUM_FAILED}" = "0" ] && [ "${NUM_ERRORS}" = "0" ]; then
    NUM_ERRORS="${ACCUMULATED_ERRORS}"
  fi
  local NUM_TOTAL_ERRORS=$((NUM_FAILED+NUM_ERRORS))
  local TYPE="success"
  [ "${NUM_TOTAL_ERRORS}" != "0" ] && TYPE="failure"
  local ERROR_STRING=
  [ "${NUM_ERRORS}" != "0" ] && ERROR_STRING=" ${NUM_TOTAL_ERRORS} error(s)"
  local TITLE BODY SEND_NOTIFICATION
  TITLE="[${STACK}] ${NUM_UPDATED} services updated ${NUM_FAILED} failed${ERROR_STRING}"
  BODY=$(echo -e "${UPDATED_MSG}\n${FAILED_MSG}\n${ERROR_MSG}")
  SEND_NOTIFICATION="true"
  case "${CONDITION}" in
    "on-change")
      if [ "${NUM_UPDATED}" = "0" ] && [ "${NUM_TOTAL_ERRORS}" = "0" ]; then
        log DEBUG "Skip sending notification because there are no updates or errors."
        SEND_NOTIFICATION="false"
      fi
      ;;
    "all"|*)
      ;;
  esac
  if is_true "${SEND_NOTIFICATION}"; then
    _send_notification "${TYPE}" "${TITLE}" "${BODY}"
  fi
}

_in_list() {
  local LIST="${1}"
  local SEARCHED_ITEM="${2}"
  [ -z "${SEARCHED_ITEM}" ] && return 1
  for ITEM in ${LIST}; do
    if [ "${ITEM}" = "${SEARCHED_ITEM}" ]; then
      return 0
    fi
  done
  return 1
}

# echo the name of the current container.
# echo nothing if unable to find the name.
# return 1 when there is an error.
_current_container_name() {
  local CURRENT_CONTAINER_NAME=
  CURRENT_CONTAINER_NAME=$(_static_variable_read_list STATIC_VAR_CURRENT_CONTAINER_NAME)
  [ -n "${CURRENT_CONTAINER_NAME}" ] && echo "${CURRENT_CONTAINER_NAME}" && return 0
  local NO_CURRENT_CONTAINER_NAME=
  NO_CURRENT_CONTAINER_NAME=$(_static_variable_read_list STATIC_VAR_NO_CURRENT_CONTAINER_NAME)
  [ -n "${NO_CURRENT_CONTAINER_NAME}" ] && return 0
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
    for NAME_AND_IP in ${ALL_LOCAL_NAME_AND_IP}; do
      [ -z "${NAME_AND_IP}" ] && continue;
      # NAME_AND_IP will be in one of the following formats:
      # '<container name>/<ip>/<mask>'
      # '<container name>/' (when network mode is host)
      local CNAME CIP
      CNAME=$(echo "${NAME_AND_IP}/" | cut -d/ -f1);
      CIP=$(echo "${NAME_AND_IP}/" | cut -d/ -f2);
      # Unable to find the container IP when network mode is host.
      [ -z "${CIP}" ] && continue;
      for IP in ${IPS}; do
        [ "${IP}" != "${CIP}" ] && continue;
        _static_variable_add_unique_to_list STATIC_VAR_CURRENT_CONTAINER_NAME "${CNAME}"
        echo "${CNAME}";
        return 0;
      done
    done
  done
  # Explicitly set that we cannot find the name of current container.
  _static_variable_add_unique_to_list STATIC_VAR_NO_CURRENT_CONTAINER_NAME "NO_CURRENT_CONTAINER_NAME"
  return 0;
}

gantry_current_service_name() {
  local CURRENT_SERVICE_NAME=
  CURRENT_SERVICE_NAME=$(_static_variable_read_list STATIC_VAR_CURRENT_SERVICE_NAME)
  [ -n "${CURRENT_SERVICE_NAME}" ] && echo "${CURRENT_SERVICE_NAME}" && return 0
  local CNAME=
  CNAME=$(_current_container_name) || return 1
  [ -z "${CNAME}" ] && return 0
  local SNAME=
  SNAME=$(docker container inspect "${CNAME}" --format '{{range $key,$value := .Config.Labels}}{{$key}}={{println $value}}{{end}}' \
    | grep "com.docker.swarm.service.name" \
    | sed -n "s/com.docker.swarm.service.name=\(.*\)$/\1/p") || return 1
  _static_variable_add_unique_to_list STATIC_VAR_CURRENT_SERVICE_NAME "${SNAME}"
  echo "${SNAME}"
}

_service_is_self() {
  if [ -z "${GANTRY_SERVICES_SELF}" ]; then
    # If _service_is_self is called inside a subprocess, export won't affect the parent process.
    # Use a static variable to preserve the value between processes. And we only want to log the value is set once.
    GANTRY_SERVICES_SELF=$(_static_variable_read_list STATIC_VAR_SERVICES_SELF)
    if [ -z "${GANTRY_SERVICES_SELF}" ]; then
      GANTRY_SERVICES_SELF=$(gantry_current_service_name)
      export GANTRY_SERVICES_SELF
      _static_variable_add_unique_to_list STATIC_VAR_SERVICES_SELF "${GANTRY_SERVICES_SELF}"
      [ -n "${GANTRY_SERVICES_SELF}" ] && log INFO "Set GANTRY_SERVICES_SELF to ${GANTRY_SERVICES_SELF}."
    fi
  fi
  local SELF="${GANTRY_SERVICES_SELF}"
  local SERVICE_NAME="${1}"
  [ "${SERVICE_NAME}" = "${SELF}" ]
}

_get_service_image() {
  local SERVICE_NAME="${1}"
  [ -z "${SERVICE_NAME}" ] && return 1
  docker service inspect -f '{{.Spec.TaskTemplate.ContainerSpec.Image}}' "${SERVICE_NAME}"
}

_get_service_previous_image() {
  local SERVICE_NAME="${1}"
  [ -z "${SERVICE_NAME}" ] && return 1
  docker service inspect -f '{{.PreviousSpec.TaskTemplate.ContainerSpec.Image}}' "${SERVICE_NAME}"
}

_get_service_mode() {
  local SERVICE_NAME="${1}"
  local MODE=
  if ! MODE=$(docker service ls --filter "name=${SERVICE_NAME}" --format '{{.Mode}} {{.Name}}' 2>&1); then
    log ERROR "Failed to obtain the mode of the service ${SERVICE_NAME}: ${MODE}"
    return 1
  fi
  # For `docker service ls --filter`, the name filter matches on all or the prefix of a service's name
  # See https://docs.docker.com/engine/reference/commandline/service_ls/#name
  # It does not do the exact match of the name. See https://github.com/moby/moby/issues/32985
  # We do an extra step to to perform the exact match.
  MODE=$(echo "${MODE}" | sed -n "s/\(.*\) ${SERVICE_NAME}$/\1/p")
  echo "${MODE}"
}

# echo the mode when the service is replicated job or global job
# return whether a service is replicated job or global job
_service_is_job() {
  local SERVICE_NAME="${1}"
  local MODE=
  if ! MODE=$(_get_service_mode "${SERVICE_NAME}"); then
    return 1
  fi
  # Looking for replicated-job or global-job
  echo "${MODE}" | grep "job"
}

_service_is_replicated() {
  local SERVICE_NAME="${1}"
  local MODE=
  if ! MODE=$(_get_service_mode "${SERVICE_NAME}"); then
    return 1
  fi
  # Looking for replicated, not replicated-job
  if [ "${MODE}" != "replicated" ]; then
    return 1
  fi
  echo "${MODE}"
}

_get_config_from_service() {
  local SERVICE_NAME="${1}"
  local AUTH_CONFIG_LABEL="gantry.auth.config"
  local AUTH_CONFIG=
  AUTH_CONFIG=$(_get_label_from_service "${SERVICE_NAME}" "${AUTH_CONFIG_LABEL}")
  [ -z "${AUTH_CONFIG}" ] && return 0
  echo "--config ${AUTH_CONFIG}"
}

_skip_jobs() {
  local SERVICE_NAME="${1}"
  local UPDATE_JOBS=
  UPDATE_JOBS=$(_read_env_or_label "${SERVICE_NAME}" "GANTRY_UPDATE_JOBS" "gantry.update.jobs" "false")
  if is_true "${UPDATE_JOBS}"; then
    return 1
  fi
  local MODE=
  if MODE=$(_service_is_job "${SERVICE_NAME}"); then
    log DEBUG "Skip updating ${SERVICE_NAME} because it is in ${MODE} mode."
    return 0
  fi
  return 1
}

_get_image_info() {
  local SERVICE_NAME="${1}"
  local MANIFEST_OPTIONS=
  MANIFEST_OPTIONS=$(_read_env_or_label "${SERVICE_NAME}" "GANTRY_MANIFEST_OPTIONS" "gantry.manifest.options" "")
  local MANIFEST_CMD="${2}"
  local IMAGE="${3}"
  local DOCKER_CONFIG="${4}"
  local MSG=
  local RETURN_VALUE=0
  if echo "${MANIFEST_CMD}" | grep -q -i "buildx"; then
    # https://github.com/orgs/community/discussions/45779
    [ -n "${MANIFEST_OPTIONS}" ] && log DEBUG "Adding options \"${MANIFEST_OPTIONS}\" to the command \"docker buildx imagetools inspect\"."
    # SC2086: Double quote to prevent globbing and word splitting.
    # shellcheck disable=SC2086
    MSG=$(docker ${DOCKER_CONFIG} buildx imagetools inspect ${MANIFEST_OPTIONS} "${IMAGE}" 2>&1);
    RETURN_VALUE=$?
  elif echo "${MANIFEST_CMD}" | grep -q -i "manifest"; then
    [ -n "${MANIFEST_OPTIONS}" ] && log DEBUG "Adding options \"${MANIFEST_OPTIONS}\" to the command \"docker manifest inspect\"."
    # SC2086: Double quote to prevent globbing and word splitting.
    # shellcheck disable=SC2086
    MSG=$(docker ${DOCKER_CONFIG} manifest inspect ${MANIFEST_OPTIONS} "${IMAGE}" 2>&1);
    RETURN_VALUE=$?
  elif echo "${MANIFEST_CMD}" | grep -q -i "none"; then
    # We should never reach here, the "none" command is already checked inside the function _inspect_image.
    log DEBUG "MANIFEST_CMD is \"none\"."
    return 0
  else
    log ERROR "Unknown MANIFEST_CMD \"${MANIFEST_CMD}\"."
    return 1
  fi
  if [ "${RETURN_VALUE}" != "0" ];  then
    log ERROR "Image ${IMAGE} does not exist or it is not available. Docker ${MANIFEST_CMD} returns: ${MSG}"
    return 1
  fi
  echo "${MSG}"
}

# echo nothing if we found no new images.
# echo the image if we found a new image.
# return the number of errors.
_inspect_image() {
  local SERVICE_NAME="${1}"
  local MANIFEST_CMD=
  MANIFEST_CMD=$(_read_env_or_label "${SERVICE_NAME}" "GANTRY_MANIFEST_CMD" "gantry.manifest.cmd" "buildx")
  local IMAGE_WITH_DIGEST=
  if ! IMAGE_WITH_DIGEST=$(_get_service_image "${SERVICE_NAME}" 2>&1); then
    log ERROR "Failed to obtain image from service ${SERVICE_NAME}. ${IMAGE_WITH_DIGEST}"
    return 1
  fi
  local IMAGE=
  local DIGEST=
  # If IMAGE_WITH_DIGEST contains no "@", then "cut -d@ -f2" will also return the entire string.
  # Adding a "@" to ensure the string contains at least one "@". Thus DIGEST will be empty when original IMAGE_WITH_DIGEST contains no "@"
  IMAGE=$(echo "${IMAGE_WITH_DIGEST}@" | cut -d@ -f1)
  DIGEST=$(echo "${IMAGE_WITH_DIGEST}@" | cut -d@ -f2)
  if echo "${MANIFEST_CMD}" | grep -q -i "none"; then
    if _service_is_self "${SERVICE_NAME}"; then
      # Always inspecting self, never skipping.
      MANIFEST_CMD="buildx"
    else
      log DEBUG "Perform updating ${SERVICE_NAME} because MANIFEST_CMD is \"none\"."
      echo "${IMAGE}"
      return 0
    fi
  fi
  local NO_NEW_IMAGES=
  NO_NEW_IMAGES=$(_static_variable_read_list STATIC_VAR_NO_NEW_IMAGES)
  if _in_list "${NO_NEW_IMAGES}" "${DIGEST}"; then
    log DEBUG "Skip updating ${SERVICE_NAME} because there is no known newer version of image ${IMAGE_WITH_DIGEST}."
    return 0
  fi
  local HAS_NEW_IMAGES=
  HAS_NEW_IMAGES=$(_static_variable_read_list STATIC_VAR_NEW_IMAGES)
  if _in_list "${HAS_NEW_IMAGES}" "${DIGEST}"; then
    log DEBUG "Perform updating ${SERVICE_NAME} because there is a known newer version of image ${IMAGE_WITH_DIGEST}."
    echo "${IMAGE}"
    return 0
  fi
  local DOCKER_CONFIG=
  DOCKER_CONFIG=$(_get_config_from_service "${SERVICE}")
  [ -n "${DOCKER_CONFIG}" ] && log DEBUG "Adding options \"${DOCKER_CONFIG}\" to docker commands for ${SERVICE_NAME}."
  local IMAGE_INFO=
  if ! IMAGE_INFO=$(_get_image_info "${SERVICE_NAME}" "${MANIFEST_CMD}" "${IMAGE}" "${DOCKER_CONFIG}"); then
    log DEBUG "Skip updating ${SERVICE_NAME} because there is a failure to obtain the manifest from the registry of image ${IMAGE}."
    return 1
  fi
  [ -z "${IMAGE_INFO}" ] && log DEBUG "IMAGE_INFO is empty."
  if [ -z "${DIGEST}" ]; then
    # The image may not contain the digest for the following reasons:
    # 1. The image has not been push to or pulled from a V2 registry
    # 2. The image has been pulled from a V1 registry
    # 3. The service has not been updated via Docker CLI, but via Docker API, i.e. via 3rd party tools.
    log DEBUG "Perform updating ${SERVICE_NAME} because DIGEST is empty in ${IMAGE_WITH_DIGEST}, assume there is a new image."
    echo "${IMAGE}"
    return 0
  fi
  if [ -n "${DIGEST}" ] && echo "${IMAGE_INFO}" | grep -q "${DIGEST}"; then
    _static_variable_add_unique_to_list STATIC_VAR_NO_NEW_IMAGES "${DIGEST}"
    log DEBUG "Skip updating ${SERVICE_NAME} because the current version is the latest of image ${IMAGE_WITH_DIGEST}."
    return 0
  fi
  _static_variable_add_unique_to_list STATIC_VAR_NEW_IMAGES "${DIGEST}"
  log DEBUG "Perform updating ${SERVICE_NAME} because there is a newer version of image ${IMAGE_WITH_DIGEST}."
  echo "${IMAGE}"
  return 0
}

# return 0 if need to update the service
# return 1 if no need to update the service
_inspect_service() {
  local SERVICE_NAME="${1}"
  local RUN_UPDATE="${2:-false}"
  if _skip_jobs "${SERVICE_NAME}"; then
    _static_variable_add_unique_to_list STATIC_VAR_SERVICES_SKIP_JOB "${SERVICE_NAME}"
    return 1
  fi
  local IMAGE=
  if ! IMAGE=$(_inspect_image "${SERVICE_NAME}"); then
    _static_variable_add_unique_to_list STATIC_VAR_SERVICES_UPDATE_FAILED "${SERVICE_NAME}"
    return 1
  fi
  if [ -z "${IMAGE}" ]; then
    _static_variable_add_unique_to_list STATIC_VAR_SERVICES_NO_NEW_IMAGE "${SERVICE_NAME}"
    return 1
  fi
  if is_true "${RUN_UPDATE}"; then
    _update_single_service "${SERVICE_NAME}" "${IMAGE}"
    return 1
  fi
  _static_variable_add_unique_to_list STATIC_VAR_SERVICES_TO_UPDATE "${SERVICE_NAME}"
  _static_variable_add_unique_to_list STATIC_VAR_SERVICES_AND_IMAGES_TO_UPDATE "${SERVICE_NAME} ${IMAGE}"
  return 0
}

_get_number_of_running_tasks() {
  local SERVICE_NAME="${1}"
  local REPLICAS=
  if ! REPLICAS=$(docker service ls --filter "name=${SERVICE_NAME}" --format '{{.Replicas}} {{.Name}}' 2>&1); then
    log ERROR "Failed to obtain task states of service ${SERVICE_NAME}: ${REPLICAS}"
    return 1
  fi
  # For `docker service ls --filter`, the name filter matches on all or the prefix of a service's name
  # See https://docs.docker.com/engine/reference/commandline/service_ls/#name
  # It does not do the exact match of the name. See https://github.com/moby/moby/issues/32985
  # We do an extra step to to perform the exact match.
  REPLICAS=$(echo "${REPLICAS}" | sed -n "s/\(.*\) ${SERVICE_NAME}$/\1/p")
  # https://docs.docker.com/engine/reference/commandline/service_ls/#examples
  # The REPLICAS is like "5/5" or "1/1 (3/5 completed)"
  # Get the number before the first "/".
  local NUM_RUNS=
  NUM_RUNS=$(echo "${REPLICAS}/" | cut -d '/' -f 1)
  echo "${NUM_RUNS}"
}

_get_with_registry_auth() {
  local DOCKER_CONFIG="${1}"
  # DOCKER_CONFIG is currently only used by Authentication.
  # When login is required, we must add `--with-registry-auth`. Otherwise the service will get an image without digest.
  # See https://github.com/shizunge/gantry/issues/53#issuecomment-2348376336
  [ -n "${DOCKER_CONFIG}" ] && echo "--with-registry-auth";
}

_get_service_update_additional_options() {
  local SERVICE_NAME="${1}"
  local DOCKER_CONFIG="${2}"
  local NUM_RUNS=
  NUM_RUNS=$(_get_number_of_running_tasks "${SERVICE_NAME}")
  if ! is_number "${NUM_RUNS}"; then
    log WARN "NUM_RUNS \"${NUM_RUNS}\" is not a number."
    return 1
  fi
  local OPTIONS=
  if [ "${NUM_RUNS}" = "0" ]; then
    # Add "--detach=true" when there is no running tasks.
    # https://github.com/docker/cli/issues/627
    OPTIONS="${OPTIONS} --detach=true"
    local MODE=
    # Do not start a new task. Only works for replicated, not global.
    if MODE=$(_service_is_replicated "${SERVICE_NAME}"); then
      OPTIONS="${OPTIONS} --replicas=0"
    fi
  fi
  # Add `--with-registry-auth` if needed.
  local WITH_REGISTRY_AUTH=
  WITH_REGISTRY_AUTH="$(_get_with_registry_auth "${DOCKER_CONFIG}")"
  [ -n "${WITH_REGISTRY_AUTH}" ] && OPTIONS="${OPTIONS} ${WITH_REGISTRY_AUTH}"
  echo "${OPTIONS}"
}

_get_service_rollback_additional_options() {
  local SERVICE_NAME="${1}"
  local DOCKER_CONFIG="${2}"
  local OPTIONS=
  # Place holder function. Nothing to do here yet.
  # --with-registry-auth cannot be combined with --rollback.
  echo "${OPTIONS}"
}

_rollback_service() {
  local SERVICE_NAME="${1}"
  local ROLLBACK_ON_FAILURE=
  ROLLBACK_ON_FAILURE=$(_read_env_or_label "${SERVICE_NAME}" "GANTRY_ROLLBACK_ON_FAILURE" "gantry.rollback.on_failure" "true")
  local ROLLBACK_OPTIONS=
  ROLLBACK_OPTIONS=$(_read_env_or_label "${SERVICE_NAME}" "GANTRY_ROLLBACK_OPTIONS" "gantry.rollback.options" "")
  local DOCKER_CONFIG="${2}"
  if ! is_true "${ROLLBACK_ON_FAILURE}"; then
    return 0
  fi
  log INFO "Rolling back ${SERVICE_NAME}."
  # "service update --rollback" needs to take different options from "service update"
  local ADDITIONAL_OPTIONS=
  ADDITIONAL_OPTIONS=$(_get_service_rollback_additional_options "${SERVICE_NAME}" "${DOCKER_CONFIG}")
  [ -n "${ADDITIONAL_OPTIONS}" ] && log DEBUG "Adding options \"${ADDITIONAL_OPTIONS}\" to the command \"docker service update --rollback\" for ${SERVICE_NAME}."
  [ -n "${ROLLBACK_OPTIONS}" ] && log DEBUG "Adding options \"${ROLLBACK_OPTIONS}\" to the command \"docker service update --rollback\" for ${SERVICE_NAME}."
  local ROLLBACK_MSG=
  # Add "-quiet" to suppress progress output.
  # SC2086: Double quote to prevent globbing and word splitting.
  # shellcheck disable=SC2086
  if ! ROLLBACK_MSG=$(docker ${DOCKER_CONFIG} service update --quiet ${ADDITIONAL_OPTIONS} ${ROLLBACK_OPTIONS} --rollback "${SERVICE_NAME}" 2>&1); then
    log ERROR "Failed to roll back ${SERVICE_NAME}. ${ROLLBACK_MSG}"
    return 1
  fi
  log INFO "Rolled back ${SERVICE_NAME}."
}

# return 0 when there is no error or failure.
# return 1 when there are error(s) or failure(s).
_update_single_service() {
  local SERVICE_NAME="${1}"
  local UPDATE_TIMEOUT_SECONDS=
  UPDATE_TIMEOUT_SECONDS=$(_read_env_or_label "${SERVICE_NAME}" "GANTRY_UPDATE_TIMEOUT_SECONDS" "gantry.update.timeout_seconds" "300")
  if ! is_number "${UPDATE_TIMEOUT_SECONDS}"; then
    log ERROR "UPDATE_TIMEOUT_SECONDS must be a number. Got \"${UPDATE_TIMEOUT_SECONDS}\"."
    local ERROR_SERVICE="GANTRY_UPDATE_TIMEOUT_SECONDS-is-not-a-number"
    _static_variable_add_unique_to_list STATIC_VAR_SERVICES_UPDATE_INPUT_ERROR "${ERROR_SERVICE}"
    return 1
  fi
  local UPDATE_OPTIONS=
  UPDATE_OPTIONS=$(_read_env_or_label "${SERVICE_NAME}" "GANTRY_UPDATE_OPTIONS" "gantry.update.options" "")
  local IMAGE="${2}"
  local INPUT_ERROR=0
  [ -z "${SERVICE_NAME}" ] && log ERROR "Updating service: SERVICE_NAME must not be empty." && INPUT_ERROR=1 && SERVICE_NAME="unknown-service-name"
  [ -z "${IMAGE}" ] && log ERROR "Updating ${SERVICE_NAME}: IMAGE must not be empty." && INPUT_ERROR=1
  if [ "${INPUT_ERROR}" != "0" ]; then
    _static_variable_add_unique_to_list STATIC_VAR_SERVICES_UPDATE_INPUT_ERROR "${SERVICE_NAME}"
    return 1;
  fi
  log INFO "Updating ${SERVICE_NAME} with image ${IMAGE}"
  local DOCKER_CONFIG=
  local ADDITIONAL_OPTIONS=
  DOCKER_CONFIG=$(_get_config_from_service "${SERVICE}")
  ADDITIONAL_OPTIONS=$(_get_service_update_additional_options "${SERVICE_NAME}" "${DOCKER_CONFIG}")
  [ -n "${DOCKER_CONFIG}" ] && log DEBUG "Adding options \"${DOCKER_CONFIG}\" to docker commands for ${SERVICE_NAME}."
  [ -n "${ADDITIONAL_OPTIONS}" ] && log DEBUG "Adding options \"${ADDITIONAL_OPTIONS}\" to the command \"docker service update\" for ${SERVICE_NAME}."
  [ -n "${UPDATE_OPTIONS}" ] && log DEBUG "Adding options \"${UPDATE_OPTIONS}\" to the command \"docker service update\" for ${SERVICE_NAME}."
  local UPDATE_MSG=
  # Add "-quiet" to suppress progress output.
  # SC2086: Double quote to prevent globbing and word splitting.
  # shellcheck disable=SC2086
  if ! UPDATE_MSG=$(timeout "${UPDATE_TIMEOUT_SECONDS}" docker ${DOCKER_CONFIG} service update --quiet ${ADDITIONAL_OPTIONS} ${UPDATE_OPTIONS} --image="${IMAGE}" "${SERVICE_NAME}" 2>&1); then
    log ERROR "docker service update failed or timeout. ${UPDATE_MSG}"
    _rollback_service "${SERVICE_NAME}" "${DOCKER_CONFIG}"
    _static_variable_add_unique_to_list STATIC_VAR_SERVICES_UPDATE_FAILED "${SERVICE_NAME}"
    return 1
  fi
  local PREVIOUS_IMAGE=
  local CURRENT_IMAGE=
  PREVIOUS_IMAGE=$(_get_service_previous_image "${SERVICE_NAME}")
  CURRENT_IMAGE=$(_get_service_image "${SERVICE_NAME}")
  if [ "${PREVIOUS_IMAGE}" = "${CURRENT_IMAGE}" ]; then
    log INFO "No updates for ${SERVICE_NAME}."
    return 0
  fi
  _static_variable_add_unique_to_list STATIC_VAR_SERVICES_UPDATED "${SERVICE_NAME}"
  _static_variable_add_unique_to_list STATIC_VAR_IMAGES_TO_REMOVE "${PREVIOUS_IMAGE}"
  log INFO "UPDATED ${SERVICE_NAME}."
  return 0
}

_parallel_worker() {
  local FUNCTION="${1}"
  local INDEX="${2}"
  local STATIC_VAR_LIST_NAME="${3}"
  local OLD_LOG_SCOPE="${LOG_SCOPE}"
  LOG_SCOPE=$(attach_tag_to_log_scope "worker${INDEX}")
  export LOG_SCOPE
  local ARGUMENTS=
  while true; do
    ARGUMENTS=$(_static_variable_pop_list "${STATIC_VAR_LIST_NAME}")
    [ -z "${ARGUMENTS}" ] && break;
    # SC2086 (info): Double quote to prevent globbing and word splitting.
    # shellcheck disable=SC2086
    ${FUNCTION} ${ARGUMENTS}
  done
  export LOG_SCOPE="${OLD_LOG_SCOPE}"
}

_run_parallel() {
  local FUNCTION="${1}"
  local NUM_WORKERS="${2}"
  local STATIC_VAR_LIST_NAME="${3}"
  log DEBUG "Run ${NUM_WORKERS} ${FUNCTION} in parallel."
  local PIDS=
  for INDEX in $(seq 0 $((NUM_WORKERS-1)) ); do
    # All workers subscribe to the same list now.
    _parallel_worker "${FUNCTION}" "${INDEX}" "${STATIC_VAR_LIST_NAME}" &
    PIDS="${!} ${PIDS}"
  done
  # SC2086 (info): Double quote to prevent globbing and word splitting.
  # shellcheck disable=SC2086
  wait ${PIDS}
}

_get_services_filted() {
  local SERVICES_FILTERS="${1}"
  local SERVICES=
  local FILTERS=
  for F in ${SERVICES_FILTERS}; do
    FILTERS="${FILTERS} --filter ${F}"
  done
  # SC2086: Double quote to prevent globbing and word splitting.
  # shellcheck disable=SC2086
  if ! SERVICES=$(docker service ls --quiet ${FILTERS} --format '{{.Name}}' 2>&1); then
    log ERROR "Failed to obtain services list with \"${FILTERS}\". ${SERVICES}"
    return 1
  fi
  echo -e "${SERVICES}"
  return 0
}

gantry_initialize() {
  local STACK="${1:-gantry}"
  _create_static_variables_folder
  _authenticate_to_registries
}

gantry_get_services_list() {
  local SERVICES_EXCLUDED="${GANTRY_SERVICES_EXCLUDED:-""}"
  local SERVICES_EXCLUDED_FILTERS="${GANTRY_SERVICES_EXCLUDED_FILTERS:-"label=gantry.services.excluded=true"}"
  local SERVICES_FILTERS="${GANTRY_SERVICES_FILTERS:-""}"
  [ -n "${SERVICES_EXCLUDED}" ] && log DEBUG "SERVICES_EXCLUDED=${SERVICES_EXCLUDED}"
  [ -n "${SERVICES_EXCLUDED_FILTERS}" ] && log DEBUG "SERVICES_EXCLUDED_FILTERS=${SERVICES_EXCLUDED_FILTERS}"
  [ -n "${SERVICES_FILTERS}" ] && log DEBUG "SERVICES_FILTERS=${SERVICES_FILTERS}"
  local SERVICES=
  if ! SERVICES=$(_get_services_filted "${SERVICES_FILTERS}"); then
    return 1
  fi
  if [ -n "${SERVICES_EXCLUDED_FILTERS}" ]; then
    local SERVICES_FROM_EXCLUDED_FILTERS=
    if ! SERVICES_FROM_EXCLUDED_FILTERS=$(_get_services_filted "${SERVICES_EXCLUDED_FILTERS}"); then
      return 1
    fi
    SERVICES_EXCLUDED="${SERVICES_EXCLUDED} ${SERVICES_FROM_EXCLUDED_FILTERS}"
  fi
  local LIST=
  local HAS_SELF=
  for S in ${SERVICES} ; do
    if _in_list "${SERVICES_EXCLUDED}" "${S}" ; then
      log DEBUG "Exclude service ${S} from updating."
      continue
    fi
    # Add self to the first of the list.
    if [ -z "${HAS_SELF}" ] && _service_is_self "${S}"; then
      HAS_SELF="${S}"
      continue
    fi
    LIST="${LIST} ${S}"
  done
  # Add self to the first of the list.
  if [ -n "${HAS_SELF}" ]; then
    LIST="${HAS_SELF} ${LIST}"
  fi
  echo "${LIST}"
}

gantry_update_services_list() {
  local UPDATE_NUM_WORKERS=
  if ! UPDATE_NUM_WORKERS=$(gantry_read_number GANTRY_UPDATE_NUM_WORKERS 1); then
    local ERROR_SERVICE="GANTRY_UPDATE_NUM_WORKERS-is-not-a-number"
    _static_variable_add_unique_to_list STATIC_VAR_SERVICES_UPDATE_INPUT_ERROR "${ERROR_SERVICE}"
    return 1
  fi
  local MANIFEST_NUM_WORKERS=
  if ! MANIFEST_NUM_WORKERS=$(gantry_read_number GANTRY_MANIFEST_NUM_WORKERS 1); then
    local ERROR_SERVICE="GANTRY_MANIFEST_NUM_WORKERS-is-not-a-number"
    _static_variable_add_unique_to_list STATIC_VAR_SERVICES_UPDATE_INPUT_ERROR "${ERROR_SERVICE}"
    return 1
  fi
  local LIST="${*}"
  local NUM=
  NUM=$(_get_number_of_elements "${LIST}")
  log INFO "Inspecting ${NUM} service(s)."
  for SERVICE in ${LIST}; do
    if _service_is_self "${SERVICE}"; then
      # Immediately update self service after inspection, do not wait for other inspections to finish.
      # This avoids running inspection on the same service twice, due to interruption from updating self, when running as a service.
      # The self service is usually the first of the list.
      local RUN_UPDATE=true
      _inspect_service "${SERVICE}" "${RUN_UPDATE}"
      continue
    fi
    _static_variable_add_unique_to_list STATIC_VAR_SERVICES_TO_INSPECT "${SERVICE}"
  done
  _run_parallel _inspect_service "${MANIFEST_NUM_WORKERS}" STATIC_VAR_SERVICES_TO_INSPECT

  _report_services_from_static_variable STATIC_VAR_SERVICES_SKIP_JOB "Skip updating" "due to they are job(s)" | log_lines INFO
  _report_services_from_static_variable STATIC_VAR_SERVICES_UPDATE_FAILED "Failed to inspect" | log_lines ERROR
  _report_services_from_static_variable STATIC_VAR_SERVICES_NO_NEW_IMAGE "No new images for" | log_lines INFO
  _report_services_from_static_variable STATIC_VAR_SERVICES_TO_UPDATE "Updating" | log_lines INFO

  _run_parallel _update_single_service "${UPDATE_NUM_WORKERS}" STATIC_VAR_SERVICES_AND_IMAGES_TO_UPDATE

  local RETURN_VALUE=0
  local FAILED_NUM=
  FAILED_NUM=$(_get_number_of_elements_in_static_variable STATIC_VAR_SERVICES_UPDATE_FAILED)
  [ "${FAILED_NUM}" != "0" ] && RETURN_VALUE=1
  local ERROR_NUM=
  ERROR_NUM=$(_get_number_of_elements_in_static_variable STATIC_VAR_SERVICES_UPDATE_INPUT_ERROR)
  [ "${ERROR_NUM}" != "0" ] && RETURN_VALUE=1
  return "${RETURN_VALUE}"
}

gantry_finalize() {
  local STACK="${1:-gantry}"
  local NUM_ERRORS="${2:-0}"
  local RETURN_VALUE=0
  if ! _remove_images "${STACK}_image-remover"; then
    RETURN_VALUE=1
  fi
  if ! _report_services "${STACK}" "${NUM_ERRORS}"; then
    RETURN_VALUE=1
  fi
  _remove_static_variables_folder
  return "${RETURN_VALUE}"
}
