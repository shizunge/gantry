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

# This function calls read_env() underneath.
# read_env() returns an empty string if ENV_VALUE is set to empty,
# in which case we want to use the DEFAULT_VALUE.
_read_env_default() {
  local ENV_NAME="${1}"
  local DEFAULT_VALUE="${2}"
  local READ_VALUE=
  READ_VALUE=$(read_env "${ENV_NAME}" "${DEFAULT_VALUE}")
  local VALUE="${READ_VALUE}"
  [ -z "${VALUE}" ] && VALUE="${DEFAULT_VALUE}"
  echo "${VALUE}"
}

# Read a number from an environment variable.
# Log an error when it is not a number.
gantry_read_number() {
  local ENV_NAME="${1}"
  local DEFAULT_VALUE="${2}"
  ! is_number "${DEFAULT_VALUE}" && log ERROR "DEFAULT_VALUE must be a number. Got \"${DEFAULT_VALUE}\"." && return 1
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

# Read a value from label on the service firstly.
# Read the value from the environment varible, if the label is not set.
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

_get_docker_default_config() {
  local LOCAL_DOCKER_CONFIG="${DOCKER_CONFIG:-""}"
  local DEFAULT_LOCATION="${LOCAL_DOCKER_CONFIG}"
  [ -z "${DEFAULT_LOCATION}" ] && DEFAULT_LOCATION="${HOME}/.docker"
  readlink -f "${DEFAULT_LOCATION}"
}

# Record that the default config is used when the input is either
# 1. an empty string.
# 2. same as _get_docker_default_config().
_check_if_it_is_docker_default_config() {
  local CONFIG_TO_CHECK="${1}"
  local DEFAULT_LOCATION=
  DEFAULT_LOCATION=$(_get_docker_default_config)
  if [ -z "${CONFIG_TO_CHECK}" ]; then
    CONFIG_TO_CHECK="${DEFAULT_LOCATION}"
  else
    CONFIG_TO_CHECK="$(readlink -f "${CONFIG_TO_CHECK}")"
  fi
  if [ "${CONFIG_TO_CHECK}" = "${DEFAULT_LOCATION}" ]; then
    _static_variable_add_unique_to_list STATIC_VAR_DOCKER_CONFIG_DEFAULT "${DEFAULT_LOCATION}"
  fi
}

# Echo the default docker config if it is used.
# Return 0 when the default config is used
# Return 1 when the default config is not used
_docker_default_config_is_used() {
  local DOCKER_CONFIG_DEFAULT=
  DOCKER_CONFIG_DEFAULT=$(_static_variable_read_list STATIC_VAR_DOCKER_CONFIG_DEFAULT)
  [ -z "${DOCKER_CONFIG_DEFAULT}" ] && return 1
  echo "${DOCKER_CONFIG_DEFAULT}"
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
  local REGISTRY_MESSAGE="registry ${HOST}"
  if [ -z "${HOST}" ]; then
    log WARN "HOST is empty. Will login to the default registry."
    REGISTRY_MESSAGE="default registry"
  fi
  local AUTH_CONFIG=
  local CONFIG_MESSAGE="with default configuration"
  if [ -n "${CONFIG}" ]; then
    AUTH_CONFIG="--config ${CONFIG}"
    CONFIG_MESSAGE="with configuration ${CONFIG}"
  fi
  local REGISTRY_CONFIG_MESSAGE="${REGISTRY_MESSAGE} ${CONFIG_MESSAGE}"
  local LOGIN_MSG=
  # SC2086: Double quote to prevent globbing and word splitting.
  # shellcheck disable=SC2086
  if ! LOGIN_MSG=$(echo "${PASSWORD}" | docker ${AUTH_CONFIG} login --username="${USER}" --password-stdin "${HOST}" 2>&1); then
    log ERROR "Failed to login to ${REGISTRY_CONFIG_MESSAGE}. ${LOGIN_MSG}"
    return 1
  fi
  log INFO "Logged into ${REGISTRY_CONFIG_MESSAGE}. ${LOGIN_MSG}"
  if [ -n "${CONFIG}" ]; then
    _static_variable_add_unique_to_list STATIC_VAR_DOCKER_CONFIGS "${CONFIG}"
  fi
  _check_if_it_is_docker_default_config "${CONFIG}"
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
    CONFIG=$(extract_string "${LINE}" ' ' 1)
    HOST=$(extract_string "${LINE}" ' ' 2)
    USER=$(extract_string "${LINE}" ' ' 3)
    PASSWORD=$(extract_string "${LINE}" ' ' 4)
    OTHERS=$(extract_string "${LINE}" ' ' 5-)
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
  # Do not simple return ACCUMULATED_ERRORS, in case it is larger than 255.
  test "${ACCUMULATED_ERRORS}" = "0"
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

_get_static_variables_folder_name() {
  local PID=$$
  echo "/tmp/gantry-static-variables-folder-${PID}"
}

_make_static_variables_folder() {
  STATIC_VARIABLES_FOLDER=$(_get_static_variables_folder_name)
  local OUTPUT=
  ! OUTPUT=$(mkdir -p "${STATIC_VARIABLES_FOLDER}" 2>&1) && log ERROR "failed: mkdir -p ${STATIC_VARIABLES_FOLDER}: ${OUTPUT}" && return 1
  echo "${STATIC_VARIABLES_FOLDER}"
}

# We want the static variables live longer than a function.
# However if we call the function in a subprocess, which could be casued by
# 1. pipe, e.g. echo "message" | my_function
# 2. assign to a variable, e.g. MY_VAR=$(my_function)
# and changing the static variables, the value won't go back to the parent process.
# So here we use the file system to pass value between multiple processes.
_get_static_variables_folder() {
  if [ -d "${STATIC_VARIABLES_FOLDER}" ]; then
    echo "${STATIC_VARIABLES_FOLDER}"
    return 0
  fi
  log DEBUG "Creating STATIC_VARIABLES_FOLDER"
  STATIC_VARIABLES_FOLDER=$(_make_static_variables_folder)
  log DEBUG "Created STATIC_VARIABLES_FOLDER \"${STATIC_VARIABLES_FOLDER}\""
  export STATIC_VARIABLES_FOLDER
  echo "${STATIC_VARIABLES_FOLDER}"
}

_remove_static_variables_folder() {
  [ -z "${STATIC_VARIABLES_FOLDER}" ] && return 0
  local TO_REMOVE_STATIC_VARIABLES_FOLDER=
  TO_REMOVE_STATIC_VARIABLES_FOLDER="$(_get_static_variables_folder_name)"
  log DEBUG "Removing STATIC_VARIABLES_FOLDER ${TO_REMOVE_STATIC_VARIABLES_FOLDER}"
  unset STATIC_VARIABLES_FOLDER
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
  local IMAGE=
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

_correct_service_name() {
  local SERVICE_NAME="${1}"
  SERVICE_NAME=$(echo "${SERVICE_NAME}" | tr ' ' '-')
  [ "${#SERVICE_NAME}" -gt 63 ] && SERVICE_NAME="${SERVICE_NAME:0:63}"
  echo "${SERVICE_NAME}"
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
  SERVICE_NAME=$(_correct_service_name "${SERVICE_NAME}")
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
  local I=
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
    --detach=true \
    --restart-condition on-failure \
    --restart-max-attempts 1 \
    --mount type=bind,source=/var/run/docker.sock,destination=/var/run/docker.sock \
    --env "GANTRY_IMAGES_TO_REMOVE=${IMAGES_TO_REMOVE_LIST}" \
    ${CLEANUP_IMAGES_OPTIONS} \
    "${IMAGES_REMOVER}";
  docker_service_follow_logs_wait_complete "${SERVICE_NAME}"
}

_report_list() {
  local PRE="${1}"; shift
  local POST="${1}"; shift
  local LIST="${*}"
  local NUM=
  NUM=$(_get_number_of_elements "${LIST}")
  local TITLE=
  [ -n "${PRE}" ] && TITLE="${PRE} "
  TITLE="${TITLE}${NUM}"
  [ -n "${POST}" ] && TITLE="${TITLE} ${POST}"
  echo "${TITLE}:"
  local ITEM=
  for ITEM in ${LIST}; do
    echo "- ${ITEM}"
  done
}

_report_from_static_variable() {
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
  _report_list "${PRE}" "${POST}" "${LIST}"
}

_report_services_from_static_variable() {
  local VARIABLE_NAME="${1}"
  local PRE="${2}"
  local POST="${3}"
  local EMPTY="${4}"
  if [ -z "${POST}" ]; then
    POST="service(s)"
  else
    POST="service(s) ${POST}"
  fi
  _report_from_static_variable "${VARIABLE_NAME}" "${PRE}" "${POST}" "${EMPTY}"
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
  ! is_number "${ACCUMULATED_ERRORS}" && log WARN "ACCUMULATED_ERRORS \"${ACCUMULATED_ERRORS}\" is not a number." && ACCUMULATED_ERRORS=0;

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
  local NUM_FAILED_PLUS_ERRORS=$((NUM_FAILED+NUM_ERRORS))
  local SEND_NOTIFICATION="true"
  case "${CONDITION}" in
    "on-change")
      if [ "${NUM_UPDATED}" = "0" ] && [ "${NUM_FAILED_PLUS_ERRORS}" = "0" ]; then
        log DEBUG "There are no updates or errors for notification."
        SEND_NOTIFICATION="false"
      fi
      ;;
    "all"|*)
      ;;
  esac
  if ! is_true "${SEND_NOTIFICATION}"; then
    log DEBUG "Skip sending notification."
    return 0
  fi
  local TYPE="success"
  [ "${NUM_FAILED_PLUS_ERRORS}" != "0" ] && TYPE="failure"
  local ERROR_STRING=
  [ "${NUM_ERRORS}" != "0" ] && ERROR_STRING=" ${NUM_ERRORS} error(s)"
  local TITLE BODY
  TITLE="[${STACK}] ${NUM_UPDATED} services updated ${NUM_FAILED} failed${ERROR_STRING}"
  BODY=$(echo -e "${UPDATED_MSG}\n${FAILED_MSG}\n${ERROR_MSG}")
  _send_notification "${TYPE}" "${TITLE}" "${BODY}"
}

# Return 0 if the item is in the list.
# Return 1 if the item is not in the list.
_in_list() {
  local LIST="${1}"
  local SEARCHED_ITEM="${2}"
  [ -z "${SEARCHED_ITEM}" ] && return 1
  local ITEM=
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
  local CNAME=
  CNAME=$(docker_current_container_name) || return 1;
  if [ -n "${CNAME}" ]; then
    _static_variable_add_unique_to_list STATIC_VAR_CURRENT_CONTAINER_NAME "${CNAME}"
  else
    # Explicitly set that we cannot find the name of current container.
    _static_variable_add_unique_to_list STATIC_VAR_NO_CURRENT_CONTAINER_NAME "NO_CURRENT_CONTAINER_NAME"
  fi
  echo "${CNAME}"
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

# Return 0 if AUTH_CONFIG is a directory that contains Docker configuration files
# Return 1 if AUTH_CONFIG is not a directory that contains Docker configuration files
_check_auth_config_folder() {
  local AUTH_CONFIG="${1}"
  # We only check whether it is a folder, thus it is not a complete check whether the folder contains valid Docker configuration files.
  if [ -d "${AUTH_CONFIG}" ]; then
    return 0
  fi
  log WARN "${AUTH_CONFIG} is not a directory that contains Docker configuration files."
  local MSG="configuration(s) set via GANTRY_REGISTRY_CONFIG or GANTRY_REGISTRY_CONFIGS_FILE"
  _report_from_static_variable STATIC_VAR_DOCKER_CONFIGS "There are" "${MSG}" "There are no ${MSG}." | log_lines WARN
  local DOCKER_CONFIG_DEFAULT=
  if DOCKER_CONFIG_DEFAULT=$(_docker_default_config_is_used); then
    log WARN "User logged in using the default Docker configuration ${DOCKER_CONFIG_DEFAULT}."
  fi
  return 1
}

_get_auth_config_from_service() {
  local SERVICE_NAME="${1}"
  local AUTH_CONFIG_LABEL="gantry.auth.config"
  local AUTH_CONFIG=
  AUTH_CONFIG=$(_get_label_from_service "${SERVICE_NAME}" "${AUTH_CONFIG_LABEL}")
  [ -z "${AUTH_CONFIG}" ] && return 0
  _check_auth_config_folder "${AUTH_CONFIG}"
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
  local AUTH_CONFIG=
  AUTH_CONFIG=$(_get_auth_config_from_service "${SERVICE_NAME}")
  [ -n "${AUTH_CONFIG}" ] && log DEBUG "Adding options \"${AUTH_CONFIG}\" to docker commands for ${SERVICE_NAME}."
  local MSG=
  local RETURN_VALUE=0
  if echo "${MANIFEST_CMD}" | grep_q_i "buildx"; then
    # https://github.com/orgs/community/discussions/45779
    [ -n "${MANIFEST_OPTIONS}" ] && log DEBUG "Adding options \"${MANIFEST_OPTIONS}\" to the command \"docker buildx imagetools inspect\"."
    # SC2086: Double quote to prevent globbing and word splitting.
    # shellcheck disable=SC2086
    MSG=$(docker ${AUTH_CONFIG} buildx imagetools inspect ${MANIFEST_OPTIONS} "${IMAGE}" 2>&1);
    RETURN_VALUE=$?
  elif echo "${MANIFEST_CMD}" | grep_q_i "manifest"; then
    [ -n "${MANIFEST_OPTIONS}" ] && log DEBUG "Adding options \"${MANIFEST_OPTIONS}\" to the command \"docker manifest inspect\"."
    # SC2086: Double quote to prevent globbing and word splitting.
    # shellcheck disable=SC2086
    MSG=$(docker ${AUTH_CONFIG} manifest inspect ${MANIFEST_OPTIONS} "${IMAGE}" 2>&1);
    RETURN_VALUE=$?
  elif echo "${MANIFEST_CMD}" | grep_q_i "none"; then
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
  IMAGE=$(extract_string "${IMAGE_WITH_DIGEST}" '@' 1)
  DIGEST=$(extract_string "${IMAGE_WITH_DIGEST}" '@' 2)
  if echo "${MANIFEST_CMD}" | grep_q_i "none"; then
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
  local IMAGE_INFO=
  if ! IMAGE_INFO=$(_get_image_info "${SERVICE_NAME}" "${MANIFEST_CMD}" "${IMAGE}"); then
    log DEBUG "Skip updating ${SERVICE_NAME} because there is a failure to obtain the manifest from the registry of image ${IMAGE}."
    return 1
  fi
  [ -z "${IMAGE_INFO}" ] && log DEBUG "IMAGE_INFO is empty."
  if [ -z "${DIGEST}" ]; then
    # The image may not contain the digest for the following reasons:
    # 1. The image has not been push to or pulled from a V2 registry
    # 2. The image has been pulled from a V1 registry
    # 3. The service is updated without --with-registry-auth when registry requests authentication.
    log DEBUG "Perform updating ${SERVICE_NAME} because DIGEST is empty in ${IMAGE_WITH_DIGEST}, assume there is a new image."
    echo "${IMAGE}"
    return 0
  fi
  if [ -n "${DIGEST}" ] && echo "${IMAGE_INFO}" | grep_q "${DIGEST}"; then
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
  NUM_RUNS=$(extract_string "${REPLICAS}" '/' 1)
  echo "${NUM_RUNS}"
}

_get_with_registry_auth() {
  local AUTH_CONFIG="${1}"
  # AUTH_CONFIG is currently (2024.11) only used by Authentication.
  # When login is required, we must add `--with-registry-auth`. Otherwise the service will get an image without digest.
  # See https://github.com/shizunge/gantry/issues/53#issuecomment-2348376336
  local DOCKER_CONFIG_DEFAULT=
  if [ -n "${AUTH_CONFIG}" ] || DOCKER_CONFIG_DEFAULT=$(_docker_default_config_is_used); then
    echo "--with-registry-auth";
  fi
}

_get_service_update_additional_options() {
  local SERVICE_NAME="${1}"
  local AUTH_CONFIG="${2}"
  local NUM_RUNS=
  NUM_RUNS=$(_get_number_of_running_tasks "${SERVICE_NAME}")
  ! is_number "${NUM_RUNS}" && log WARN "NUM_RUNS \"${NUM_RUNS}\" is not a number." && return 1
  local OPTIONS=""
  local SPACE=""
  if [ "${NUM_RUNS}" = "0" ]; then
    # Add "--detach=true" when there is no running tasks.
    # https://github.com/docker/cli/issues/627
    OPTIONS="${OPTIONS}${SPACE}--detach=true"
    SPACE=" "
    local MODE=
    # Do not start a new task. Only works for replicated, not global.
    if MODE=$(_service_is_replicated "${SERVICE_NAME}"); then
      OPTIONS="${OPTIONS}${SPACE}--replicas=0"
      SPACE=" "
    fi
  fi
  # Add `--with-registry-auth` if needed.
  local WITH_REGISTRY_AUTH=
  WITH_REGISTRY_AUTH="$(_get_with_registry_auth "${AUTH_CONFIG}")"
  if [ -n "${WITH_REGISTRY_AUTH}" ]; then
    OPTIONS="${OPTIONS}${SPACE}${WITH_REGISTRY_AUTH}"
    SPACE=" "
  fi
  echo "${OPTIONS}"
}

_get_service_rollback_additional_options() {
  local SERVICE_NAME="${1}"
  local AUTH_CONFIG="${2}"
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
  local AUTH_CONFIG="${2}"
  if ! is_true "${ROLLBACK_ON_FAILURE}"; then
    return 0
  fi
  log INFO "Rolling back ${SERVICE_NAME}."
  # "service update --rollback" needs to take different options from "service update"
  local AUTOMATIC_OPTIONS=
  AUTOMATIC_OPTIONS=$(_get_service_rollback_additional_options "${SERVICE_NAME}" "${AUTH_CONFIG}")
  [ -n "${AUTOMATIC_OPTIONS}" ] && log DEBUG "Adding options \"${AUTOMATIC_OPTIONS}\" automatically to the command \"docker service update --rollback\" for ${SERVICE_NAME}."
  [ -n "${ROLLBACK_OPTIONS}" ] && log DEBUG "Adding options \"${ROLLBACK_OPTIONS}\" specified by user to the command \"docker service update --rollback\" for ${SERVICE_NAME}."
  local ROLLBACK_MSG=
  # Add "-quiet" to suppress progress output.
  # SC2086: Double quote to prevent globbing and word splitting.
  # shellcheck disable=SC2086
  if ! ROLLBACK_MSG=$(docker ${AUTH_CONFIG} service update --quiet ${AUTOMATIC_OPTIONS} ${ROLLBACK_OPTIONS} --rollback "${SERVICE_NAME}" 2>&1); then
    log ERROR "Failed to roll back ${SERVICE_NAME}. ${ROLLBACK_MSG}"
    return 1
  fi
  # Usually the ROLLBACK_MSG is same as the SERVICE_NAME.
  [ "${ROLLBACK_MSG}" != "${SERVICE_NAME}" ] && log WARN "There are additional messages from rolling back ${SERVICE_NAME}: ${ROLLBACK_MSG}"
  log INFO "Rolled back ${SERVICE_NAME}."
}

# return 0 when there is no error or failure.
# return 1 when there are error(s) or failure(s).
_get_timeout_command() {
  local SERVICE_NAME="${1}"
  local UPDATE_TIMEOUT_SECONDS=
  UPDATE_TIMEOUT_SECONDS=$(_read_env_or_label "${SERVICE_NAME}" "GANTRY_UPDATE_TIMEOUT_SECONDS" "gantry.update.timeout_seconds" "0")
  if ! is_number "${UPDATE_TIMEOUT_SECONDS}"; then
    log ERROR "Updating ${SERVICE_NAME}: UPDATE_TIMEOUT_SECONDS must be a number. Got \"${UPDATE_TIMEOUT_SECONDS}\"."
    _static_variable_add_unique_to_list STATIC_VAR_SERVICES_UPDATE_INPUT_ERROR "${SERVICE_NAME}"
    return 1
  fi
  local TIMEOUT_COMMAND=""
  if [ "${UPDATE_TIMEOUT_SECONDS}" != "0" ]; then
    TIMEOUT_COMMAND="timeout ${UPDATE_TIMEOUT_SECONDS}"
    log DEBUG "Set timeout to ${UPDATE_TIMEOUT_SECONDS} for updating ${SERVICE_NAME}."
  fi
  echo "${TIMEOUT_COMMAND}"
}

# return 0 when there is no error or failure.
# return 1 when there are error(s) or failure(s).
_update_single_service() {
  local SERVICE_NAME="${1}"
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
  local START_TIME=
  START_TIME=$(date +%s)
  log INFO "Updating ${SERVICE_NAME} with image ${IMAGE}"
  local AUTH_CONFIG=
  local AUTOMATIC_OPTIONS=
  AUTH_CONFIG=$(_get_auth_config_from_service "${SERVICE_NAME}")
  AUTOMATIC_OPTIONS=$(_get_service_update_additional_options "${SERVICE_NAME}" "${AUTH_CONFIG}")
  [ -n "${AUTH_CONFIG}" ] && log DEBUG "Adding options \"${AUTH_CONFIG}\" to docker commands for ${SERVICE_NAME}."
  [ -n "${AUTOMATIC_OPTIONS}" ] && log DEBUG "Adding options \"${AUTOMATIC_OPTIONS}\" automatically to the command \"docker service update\" for ${SERVICE_NAME}."
  [ -n "${UPDATE_OPTIONS}" ] && log DEBUG "Adding options \"${UPDATE_OPTIONS}\" specified by user to the command \"docker service update\" for ${SERVICE_NAME}."
  local TIMEOUT_COMMAND=""
  TIMEOUT_COMMAND=$(_get_timeout_command "${SERVICE_NAME}") || return 1
  local UPDATE_COMMAND="${TIMEOUT_COMMAND} docker ${AUTH_CONFIG} service update"
  local UPDATE_RETURN_VALUE=0
  local UPDATE_MSG=
  # Add "-quiet" to suppress progress output.
  # SC2086: Double quote to prevent globbing and word splitting.
  # shellcheck disable=SC2086
  UPDATE_MSG=$(${UPDATE_COMMAND} --quiet ${AUTOMATIC_OPTIONS} ${UPDATE_OPTIONS} --image="${IMAGE}" "${SERVICE_NAME}" 2>&1);
  UPDATE_RETURN_VALUE=$?
  if [ "${UPDATE_RETURN_VALUE}" != 0 ]; then
    # https://git.savannah.gnu.org/cgit/coreutils.git/tree/src/timeout.c
    local TIMEOUT_RETURN_CODE=124
    local TIMEOUT_MSG=""
    if [ -n "${TIMEOUT_COMMAND}" ] && [ "${UPDATE_RETURN_VALUE}" = "${TIMEOUT_RETURN_CODE}" ]; then
      TIMEOUT_MSG="The return value ${UPDATE_RETURN_VALUE} indicates the job timed out."
    fi
    log ERROR "Command \"${UPDATE_COMMAND}\" returns ${UPDATE_RETURN_VALUE}. ${TIMEOUT_MSG}"
    log ERROR "docker service update failed. ${UPDATE_MSG}"
    _rollback_service "${SERVICE_NAME}" "${AUTH_CONFIG}"
    _static_variable_add_unique_to_list STATIC_VAR_SERVICES_UPDATE_FAILED "${SERVICE_NAME}"
    return 1
  fi
  # Usually the UPDATE_MSG is same as the SERVICE_NAME.
  [ "${UPDATE_MSG}" != "${SERVICE_NAME}" ] && log WARN "There are additional messages from updating ${SERVICE_NAME}: ${UPDATE_MSG}"
  local TIME_ELAPSED=
  TIME_ELAPSED=$(time_elapsed_since "${START_TIME}")
  local PREVIOUS_IMAGE=
  local CURRENT_IMAGE=
  PREVIOUS_IMAGE=$(_get_service_previous_image "${SERVICE_NAME}")
  CURRENT_IMAGE=$(_get_service_image "${SERVICE_NAME}")
  if [ "${PREVIOUS_IMAGE}" = "${CURRENT_IMAGE}" ]; then
    log INFO "No updates for ${SERVICE_NAME}. Use ${TIME_ELAPSED}."
    return 0
  fi
  _static_variable_add_unique_to_list STATIC_VAR_SERVICES_UPDATED "${SERVICE_NAME}"
  _static_variable_add_unique_to_list STATIC_VAR_IMAGES_TO_REMOVE "${PREVIOUS_IMAGE}"
  log INFO "UPDATED ${SERVICE_NAME}. Use ${TIME_ELAPSED}."
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
  local INDEX=
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
  local F=
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
  local S=
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
  local S=
  for S in ${LIST}; do
    if _service_is_self "${S}"; then
      # Immediately update self service after inspection, do not wait for other inspections to finish.
      # This avoids running inspection on the same service twice, due to interruption from updating self, when running as a service.
      # The self service is usually the first of the list.
      local RUN_UPDATE=true
      _inspect_service "${S}" "${RUN_UPDATE}"
      continue
    fi
    _static_variable_add_unique_to_list STATIC_VAR_SERVICES_TO_INSPECT "${S}"
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
  ! _remove_images "${STACK}-image-remover" && RETURN_VALUE=1
  ! _report_services "${STACK}" "${NUM_ERRORS}" && RETURN_VALUE=1
  _remove_static_variables_folder
  return "${RETURN_VALUE}"
}
