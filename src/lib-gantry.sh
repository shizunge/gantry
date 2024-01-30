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

_login_registry() {
  local USER="${1}"
  local PASSWORD="${2}"
  local HOST="${3}"
  local CONFIG="${4}"
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
  else
    log INFO "Logged into registry${CONFIG_MESSAGE}. ${LOGIN_MSG}"
  fi
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
  local CONFIG HOST PASSWORD USER
  if ! CONFIG=$(read_config GANTRY_REGISTRY_CONFIG 2>&1); then
    log ERROR "Failed to set CONFIG: ${CONFIG}" && return 1;
  fi
  if ! HOST=$(gantry_read_registry_host 2>&1); then
    log ERROR "Failed to set HOST: ${HOST}" && return 1;
  fi
  if ! PASSWORD=$(gantry_read_registry_password 2>&1); then
    log ERROR "Failed to set PASSWORD: ${PASSWORD}" && return 1;
  fi
  if ! USER=$(gantry_read_registry_username 2>&1); then
    log ERROR "Failed to set USER: ${USER}" && return 1;
  fi
  if [ -n "${USER}" ]; then
    _login_registry "${USER}" "${PASSWORD}" "${HOST}" "${CONFIG}"
  fi
  [ -z "${CONFIGS_FILE}" ] && return 0
  [ ! -r "${CONFIGS_FILE}" ] && log ERROR "Failed to read ${CONFIGS_FILE}." && return 1
  local LINE=
  while read -r LINE; do
    # skip comments
    [ -z "${LINE}" ] && continue
    [ "${LINE:0:1}" = "#" ] && continue
    LINE=$(echo "${LINE}" | tr '\t' ' ')
    local OTHERS=
    CONFIG=$(echo "${LINE}" | cut -d ' ' -f 1)
    HOST=$(echo "${LINE}" | cut -d ' ' -f 2)
    USER=$(echo "${LINE}" | cut -d ' ' -f 3)
    PASSWORD=$(echo "${LINE}" | cut -d ' ' -f 4)
    OTHERS=$(echo "${LINE}" | cut -d ' ' -f 5-)
    if [ -n "${OTHERS}" ] || [ -z "${CONFIG}" ] || \
       [ -z "${HOST}" ] || [ -z "${USER}" ] || [ -z "${PASSWORD}" ]; then
      log ERROR "CONFIGS_FILE ${CONFIGS_FILE} format error. A line should contains only \"<CONFIG> <HOST> <USER> <PASSWORD>\"."
      log DEBUG "CONFIGS_FILE ${CONFIGS_FILE} format error. Got \"${LINE}\"."
      return 1
    fi
    _login_registry "${USER}" "${PASSWORD}" "${HOST}" "${CONFIG}"
  done <"${CONFIGS_FILE}"
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

_static_variable_read_list() {
  local LIST_NAME="${1}"
  [ -z "${LIST_NAME}" ] && log ERROR "LIST_NAME is empty." && return 1
  local FILE_NAME="${STATIC_VARIABLES_FOLDER}/${LIST_NAME}"
  [ ! -e "${FILE_NAME}" ] && touch "${FILE_NAME}"
  cat "${FILE_NAME}"
}

# Add unique value to a static variable which holds a list.
_static_variable_add_unique_to_list() {
  local LIST_NAME="${1}"
  local VALUE="${2}"
  [ -z "${LIST_NAME}" ] && log ERROR "LIST_NAME is empty." && return 1
  local FILE_NAME="${STATIC_VARIABLES_FOLDER}/${LIST_NAME}"
  local OLD_LIST NEW_LIST
  OLD_LIST=$(_static_variable_read_list "${LIST_NAME}")
  NEW_LIST=$(add_unique_to_list "${OLD_LIST}" "${VALUE}")
  echo "${NEW_LIST}" > "${FILE_NAME}"
}

_add_image_to_remove() {
  local IMAGE="${1}"
  _static_variable_add_unique_to_list STATIC_VAR_IMAGES_TO_REMOVE "${IMAGE}"
}

_remove_container() {
  local IMAGE="${1}";
  local STATUS="${2}";
  local CIDS=
  if ! CIDS=$(docker container ls --all --filter "ancestor=${IMAGE}" --filter "status=${STATUS}" --format '{{.ID}}' 2>&1); then
    log ERROR "Failed to list ${STATUS} containers with image ${IMAGE}.";
    echo "${CIDS}" | log_lines ERROR
    return 1;
  fi;
  local CID CNAME CRM_MSG
  for CID in ${CIDS}; do
    CNAME=$(docker container inspect --format '{{.Name}}' "${CID}");
    if ! CRM_MSG=$(docker container rm "${CID}" 2>&1); then
      log ERROR "Failed to remove ${STATUS} container ${CNAME}, which is using image ${IMAGE}.";
      echo "${CRM_MSG}" | log_lines ERROR
      continue;
    fi
    log INFO "Removed ${STATUS} container ${CNAME}. It was using image ${IMAGE}.";
  done;
};

gantry_remove_images() {
  local IMAGES_TO_REMOVE="${1}"
  local IMAGE RMI_MSG
  for IMAGE in ${IMAGES_TO_REMOVE}; do
    if ! docker image inspect "${IMAGE}" 1>/dev/null 2>&1 ; then
      log DEBUG "There is no image ${IMAGE} on the node.";
      continue;
    fi;
    _remove_container "${IMAGE}" exited;
    _remove_container "${IMAGE}" dead;
    if ! RMI_MSG=$(docker rmi "${IMAGE}" 2>&1); then
      log ERROR "Failed to remove image ${IMAGE}.";
      echo "${RMI_MSG}" | log_lines ERROR
      continue;
    fi;
    log INFO "Removed image ${IMAGE}.";
  done;
  log INFO "Done removing images.";
}

_remove_images() {
  local CLEANUP_IMAGES="${GANTRY_CLEANUP_IMAGES:-"true"}"
  local CLEANUP_IMAGES_OPTIONS="${GANTRY_CLEANUP_IMAGES_OPTIONS:-""}"
  if ! is_true "${CLEANUP_IMAGES}"; then
    log INFO "Skip removing images."
    return 0
  fi
  local SERVICE_NAME="${1:-"gantry-image-remover"}"
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
  local IMAGE_OF_THIS_CONTAINER=
  IMAGE_OF_THIS_CONTAINER=$(_get_service_image "$(_current_service_name)")
  [ -z "${IMAGE_OF_THIS_CONTAINER}" ] && IMAGE_OF_THIS_CONTAINER="ghcr.io/shizunge/gantry-development"
  local IMAGES_TO_REMOVE_LIST=
  IMAGES_TO_REMOVE_LIST=$(echo "${IMAGES_TO_REMOVE}" | tr '\n' ' ')
  [ -n "${CLEANUP_IMAGES_OPTIONS}" ] && log DEBUG "Adding options \"${CLEANUP_IMAGES_OPTIONS}\" to the global job ${SERVICE_NAME}."
  local RMI_MSG=
  # SC2086: Double quote to prevent globbing and word splitting.
  # shellcheck disable=SC2086
  if ! RMI_MSG=$(docker_global_job --name "${SERVICE_NAME}" \
    --restart-condition on-failure \
    --restart-max-attempts 1 \
    --mount type=bind,source=/var/run/docker.sock,destination=/var/run/docker.sock \
    --env "GANTRY_IMAGES_TO_REMOVE=${IMAGES_TO_REMOVE_LIST}" \
    ${CLEANUP_IMAGES_OPTIONS} \
    "${IMAGE_OF_THIS_CONTAINER}" 2>&1); then
    log ERROR "Failed to remove images: ${RMI_MSG}"
  fi
  wait_service_state "${SERVICE_NAME}" --complete;
  docker_service_logs "${SERVICE_NAME}"
  docker_service_remove "${SERVICE_NAME}"
}

_add_service_updated() {
  local SERVICE_NAME="${1}"
  _static_variable_add_unique_to_list STATIC_VAR_SERVICES_UPDATED "${SERVICE_NAME}"
}

_report_services_updated() {
  local SERVICES_UPDATED
  SERVICES_UPDATED=$(_static_variable_read_list STATIC_VAR_SERVICES_UPDATED)
  if [ -z "${SERVICES_UPDATED}" ]; then
    echo "No services updated."
    return 0
  fi
  local UPDATED_NUM=
  UPDATED_NUM=$(_get_number_of_elements "${SERVICES_UPDATED}")
  echo "${UPDATED_NUM} service(s) updated:"
  for S in ${SERVICES_UPDATED}; do
    echo "- ${S}"
  done
}

_add_service_update_failed() {
  local SERVICE_NAME="${1}"
  _static_variable_add_unique_to_list STATIC_VAR_SERVICES_UPDATE_FAILED "${SERVICE_NAME}"
}

_report_services_update_failed() {
  local SERVICES_UPDATE_FAILED
  SERVICES_UPDATE_FAILED=$(_static_variable_read_list STATIC_VAR_SERVICES_UPDATE_FAILED)
  if [ -z "${SERVICES_UPDATE_FAILED}" ]; then
    return 0
  fi
  local FAILED_NUM=
  FAILED_NUM=$(_get_number_of_elements "${SERVICES_UPDATE_FAILED}")
  echo "${FAILED_NUM} service(s) update failed:"
  for S in ${SERVICES_UPDATE_FAILED}; do
    echo "- ${S}"
  done
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

_report_services() {
  local UPDATED_MSG=
  local FAILED_MSG=
  UPDATED_MSG=$(_report_services_updated)
  echo "${UPDATED_MSG}" | log_lines INFO
  FAILED_MSG=$(_report_services_update_failed)
  echo "${FAILED_MSG}" | log_lines INFO
  # Send notification
  local UPDATED_NUM FAILED_NUM TITLE BODY
  local SERVICES_UPDATED SERVICES_UPDATE_FAILED
  SERVICES_UPDATED=$(_static_variable_read_list STATIC_VAR_SERVICES_UPDATED)
  SERVICES_UPDATE_FAILED=$(_static_variable_read_list STATIC_VAR_SERVICES_UPDATE_FAILED)
  UPDATED_NUM=$(_get_number_of_elements "${SERVICES_UPDATED}")
  FAILED_NUM=$(_get_number_of_elements "${SERVICES_UPDATE_FAILED}")
  local TYPE="success"
  [ "${FAILED_NUM}" -ne "0" ] && TYPE="failure"
  TITLE="[gantry] ${UPDATED_NUM} services updated ${FAILED_NUM} failed"
  BODY=$(echo -e "${UPDATED_MSG}\n${FAILED_MSG}")
  _send_notification "${TYPE}" "${TITLE}" "${BODY}"
}

_in_list() {
  local LIST="${1}"
  local SEARCHED_ITEM="${2}"
  for ITEM in ${LIST}; do
    if [ "${ITEM}" = "${SEARCHED_ITEM}" ]; then
      return 0
    fi
  done
  return 1
}

_current_container_name() {
  local CURRENT_CONTAINER_NAME=
  CURRENT_CONTAINER_NAME=$(_static_variable_read_list STATIC_VAR_CURRENT_CONTAINER_NAME)
  [ -n "${CURRENT_CONTAINER_NAME}" ] && echo "${CURRENT_CONTAINER_NAME}" && return 0
  local ALL_NETWORKS GWBRIDGE_NETWORK IPS;
  ALL_NETWORKS=$(docker network ls --format '{{.ID}}') || return 1;
  [ -z "${ALL_NETWORKS}" ] && return 0;
  GWBRIDGE_NETWORK=$(docker network ls --format '{{.ID}}' --filter 'name=docker_gwbridge') || return 1;
  IPS=$(ip route | grep src | sed -n "s/.* src \(\S*\).*$/\1/p");
  [ -z "${IPS}" ] && return 0;
  local NID;
  for NID in ${ALL_NETWORKS}; do
    [ "${NID}" = "${GWBRIDGE_NETWORK}" ] && continue;
    local ALL_LOCAL_NAME_AND_IP;
    ALL_LOCAL_NAME_AND_IP=$(docker network inspect "${NID}" --format "{{range .Containers}}{{.Name}}={{println .IPv4Address}}{{end}}") || return 1;
    for NAME_AND_IP in ${ALL_LOCAL_NAME_AND_IP}; do
      [ -z "${NAME_AND_IP}" ] && continue;
      for IP in ${IPS}; do
        echo "${NAME_AND_IP}" | grep -q "${IP}" || continue;
        local NAME;
        NAME=$(echo "${NAME_AND_IP}" | sed "s/\(.*\)=${IP}.*$/\1/");
        _static_variable_add_unique_to_list STATIC_VAR_CURRENT_CONTAINER_NAME "${NAME}"
        echo "${NAME}";
        return 0;
      done;
    done;
  done;
  return 0;
}

_current_service_name() {
  local CURRENT_SERVICE_NAME=
  CURRENT_SERVICE_NAME=$(_static_variable_read_list STATIC_VAR_CURRENT_SERVICE_NAME)
  [ -n "${CURRENT_SERVICE_NAME}" ] && echo "${CURRENT_SERVICE_NAME}" && return 0
  local CNAME=
  CNAME=$(_current_container_name) || return 1
  [ -z "${CNAME}" ] && return 0
  local SNAME=
  SNAME=$(docker container inspect "${CNAME}" --format '{{range $key,$value := .Config.Labels}}{{$key}}={{println $value}}{{end}}' | grep "com.docker.swarm.service.name" | sed "s/com.docker.swarm.service.name=\(.*\)$/\1/") || return 1
  _static_variable_add_unique_to_list STATIC_VAR_CURRENT_SERVICE_NAME "${SNAME}"
  echo "${SNAME}"
}

_service_is_self() {
  if [ -z "${GANTRY_SERVICES_SELF}" ]; then
    GANTRY_SERVICES_SELF=$(_current_service_name)
    export GANTRY_SERVICES_SELF
    [ -n "${GANTRY_SERVICES_SELF}" ] && log INFO "Set GANTRY_SERVICES_SELF to ${GANTRY_SERVICES_SELF}."
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
  if ! MODE=$(docker service ls --filter "name=${SERVICE_NAME}" --format '{{.Mode}}' 2>&1); then
    log ERROR "Failed to obtain the mode of the service ${SERVICE_NAME}: ${MODE}"
    return 1
  fi
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
  if ! AUTH_CONFIG=$(docker service inspect -f "{{index .Spec.Labels \"${AUTH_CONFIG_LABEL}\"}}" "${SERVICE_NAME}" 2>&1); then
    log ERROR "Failed to obtain authentication config from service ${SERVICE_NAME}. ${AUTH_CONFIG}"
    AUTH_CONFIG=
  fi
  [ -z "${AUTH_CONFIG}" ] && return 0
  echo "--config ${AUTH_CONFIG}"
}

_get_image_info() {
  local MANIFEST_OPTIONS="${GANTRY_MANIFEST_OPTIONS:-""}"
  local MANIFEST_CMD="${1}"
  local IMAGE="${2}"
  local DOCKER_CONFIG="${3}"
  local MSG RETURN_VALUE
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
    log ERROR "Image ${IMAGE} does not exist or it is not available. ${MSG}"
    return 1
  fi
  echo "${MSG}"
  return 0
}

# echo nothing if we found no new images.
# echo the image if we found a new image.
# return the number of errors.
_inspect_image() {
  local MANIFEST_CMD="${GANTRY_MANIFEST_CMD:-"buildx"}"
  local SERVICE_NAME="${1}"
  local DOCKER_CONFIG="${2}"
  local IMAGE_WITH_DIGEST=
  if ! IMAGE_WITH_DIGEST=$(_get_service_image "${SERVICE_NAME}" 2>&1); then
    log ERROR "Failed to obtain image from service ${SERVICE_NAME}. ${IMAGE_WITH_DIGEST}"
    return 1
  fi
  local IMAGE=
  local DIGEST=
  IMAGE=$(echo "${IMAGE_WITH_DIGEST}" | cut -d@ -f1)
  DIGEST=$(echo "${IMAGE_WITH_DIGEST}" | cut -d@ -f2)
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
  local IMAGE_INFO=
  if ! IMAGE_INFO=$(_get_image_info "${MANIFEST_CMD}" "${IMAGE}" "${DOCKER_CONFIG}"); then
    log DEBUG "Skip updating ${SERVICE_NAME} because there is a failure to obtain the manifest from the registry of image ${IMAGE}."
    return 1
  fi
  [ -z "${IMAGE_INFO}" ] && log DEBUG "IMAGE_INFO is empty."
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

_get_number_of_running_tasks() {
  local SERVICE_NAME="${1}"
  local REPLICAS=
  if ! REPLICAS=$(docker service ls --filter "name=${SERVICE_NAME}" --format '{{.Replicas}}' 2>&1); then
    log ERROR "Failed to obtain task states of service ${SERVICE_NAME}: ${REPLICAS}"
    return 1
  fi
  # https://docs.docker.com/engine/reference/commandline/service_ls/#examples
  # The REPLICAS is like "5/5" or "1/1 (3/5 completed)"
  # Get the number before the first "/".
  local NUM_RUNS=
  NUM_RUNS=$(echo "${REPLICAS}" | cut -d '/' -f 1)
  echo "${NUM_RUNS}"
}

_get_service_update_additional_options() {
  local SERVICE_NAME="${1}"
  local NUM_RUNS=
  NUM_RUNS=$(_get_number_of_running_tasks "${SERVICE_NAME}")
  if ! is_number "${NUM_RUNS}"; then
    return 1
  fi
  local OPTIONS=
  if [ "${NUM_RUNS}" -eq 0 ]; then
    # Add "--detach=true" when there is no running tasks.
    # https://github.com/docker/cli/issues/627
    OPTIONS="${OPTIONS} --detach=true"
    local MODE=
    # Do not start a new task. Only works for replicated, not global.
    if MODE=$(_service_is_replicated "${SERVICE_NAME}"); then
      OPTIONS="${OPTIONS} --replicas=0"
    fi
  fi
  echo "${OPTIONS}"
}

_rollback_service() {
  local ROLLBACK_ON_FAILURE="${GANTRY_ROLLBACK_ON_FAILURE:-"true"}"
  local ROLLBACK_OPTIONS="${GANTRY_ROLLBACK_OPTIONS:-""}"
  local SERVICE_NAME="${1}"
  local DOCKER_CONFIG="${2}"
  local ADDITIONAL_OPTIONS="${3}"
  if ! is_true "${ROLLBACK_ON_FAILURE}"; then
    return 0
  fi
  log INFO "Rolling back ${SERVICE_NAME}."
  [ -n "${ADDITIONAL_OPTIONS}" ] && log DEBUG "Adding options \"${ADDITIONAL_OPTIONS}\" to the command \"docker service update --rollback\"."
  [ -n "${ROLLBACK_OPTIONS}" ] && log DEBUG "Adding options \"${ROLLBACK_OPTIONS}\" to the command \"docker service update --rollback\"."
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

_update_single_service() {
  local UPDATE_JOBS="${GANTRY_UPDATE_JOBS:-"false"}"
  local UPDATE_TIMEOUT_SECONDS="${GANTRY_UPDATE_TIMEOUT_SECONDS:-300}"
  local UPDATE_OPTIONS="${GANTRY_UPDATE_OPTIONS:-""}"
  if ! is_number "${UPDATE_TIMEOUT_SECONDS}"; then
    log ERROR "GANTRY_UPDATE_TIMEOUT_SECONDS must be a number. Got \"${GANTRY_UPDATE_TIMEOUT_SECONDS}\"."
    return 1;
  fi
  local SERVICE_NAME="${1}"
  local MODE=
  if ! is_true "${UPDATE_JOBS}" && MODE=$(_service_is_job "${SERVICE_NAME}"); then
    log DEBUG "Skip updating service in ${MODE} mode: ${SERVICE_NAME}."
    return 0;
  fi
  local DOCKER_CONFIG=
  DOCKER_CONFIG=$(_get_config_from_service "${SERVICE_NAME}")
  [ -n "${DOCKER_CONFIG}" ] && log DEBUG "Adding options \"${DOCKER_CONFIG}\" to docker commands."
  local IMAGE=
  if ! IMAGE=$(_inspect_image "${SERVICE_NAME}" "${DOCKER_CONFIG}"); then
    _add_service_update_failed "${SERVICE_NAME}"
    return 1
  fi
  if [ -z "${IMAGE}" ]; then
    log INFO "No new images for ${SERVICE_NAME}."
    return 0
  fi
  log INFO "Updating ${SERVICE_NAME} with image ${IMAGE}"
  local ADDITIONAL_OPTIONS=
  ADDITIONAL_OPTIONS=$(_get_service_update_additional_options "${SERVICE_NAME}")
  [ -n "${ADDITIONAL_OPTIONS}" ] && log DEBUG "Adding options \"${ADDITIONAL_OPTIONS}\" to the command \"docker service update\"."
  [ -n "${UPDATE_OPTIONS}" ] && log DEBUG "Adding options \"${UPDATE_OPTIONS}\" to the command \"docker service update\"."
  local UPDATE_MSG=
  # Add "-quiet" to suppress progress output.
  # SC2086: Double quote to prevent globbing and word splitting.
  # shellcheck disable=SC2086
  if ! UPDATE_MSG=$(timeout "${UPDATE_TIMEOUT_SECONDS}" docker ${DOCKER_CONFIG} service update --quiet ${ADDITIONAL_OPTIONS} ${UPDATE_OPTIONS} --image="${IMAGE}" "${SERVICE_NAME}" 2>&1); then
    log ERROR "docker service update failed or timeout. ${UPDATE_MSG}"
    # "service update --rollback" needs to take different options from "service update"
    # Today no options are added based on services label/status. This is just a placeholder now.
    local ROLLBACK_ADDITIONAL_OPTIONS=
    _rollback_service "${SERVICE_NAME}" "${DOCKER_CONFIG}" "${ROLLBACK_ADDITIONAL_OPTIONS}"
    _add_service_update_failed "${SERVICE_NAME}"
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
  _add_service_updated "${SERVICE_NAME}"
  _add_image_to_remove "${PREVIOUS_IMAGE}"
  log INFO "UPDATED ${SERVICE_NAME}."
  return 0
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
    log ERROR "Failed to obtain services list with \"${FILTERS}\"."
    return 1
  fi
  echo -e "${SERVICES}"
  return 0
}

gantry_initialize() {
  local STACK="${1:-gantry}"
  # We want the static variables live longer than a function.
  # However if we call the function in a subprocess, which could be casued by
  # 1. pipe, e.g. echo "message" | my_function
  # 2. assign to a variable, e.g. MY_VAR=$(my_function)
  # and changing the static variables, the value won't go back to the parent process.
  # So here we use the file system to pass value between multiple processes.
  STATIC_VARIABLES_FOLDER=$(mktemp -d)
  export STATIC_VARIABLES_FOLDER
  log DEBUG "Created ${STATIC_VARIABLES_FOLDER} to store static variables."
  _authenticate_to_registries
}

gantry_get_services_list() {
  local SERVICES_EXCLUDED="${GANTRY_SERVICES_EXCLUDED:-""}"
  local SERVICES_EXCLUDED_FILTERS="${GANTRY_SERVICES_EXCLUDED_FILTERS:-""}"
  local SERVICES_FILTERS="${GANTRY_SERVICES_FILTERS:-""}"
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
      continue
    fi
    # Add self to the first of the list.
    if _service_is_self "${S}"; then
      HAS_SELF=${S}
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
  local LIST="${*}"
  local ACCUMULATED_ERRORS=0
  local LOG_SCOPE_SAVED="${LOG_SCOPE}"
  for SERVICE in ${LIST}; do
    LOG_SCOPE="Updating ${SERVICE}"
    _update_single_service "${SERVICE}"
    ACCUMULATED_ERRORS=$((ACCUMULATED_ERRORS + $?))
  done
  LOG_SCOPE=${LOG_SCOPE_SAVED}
  return ${ACCUMULATED_ERRORS}
}

gantry_finalize() {
  local STACK="${1:-gantry}"
  _remove_images "${STACK}_image-remover"
  _report_services;
  [ -n "${STATIC_VARIABLES_FOLDER}" ] && log DEBUG "Removing STATIC_VARIABLES_FOLDER ${STATIC_VARIABLES_FOLDER}" && rm -r "${STATIC_VARIABLES_FOLDER}"
}
