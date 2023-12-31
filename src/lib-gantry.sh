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

login_registry() {
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

authenticate_to_registries() {
  local CONFIGS_FILE="${GANTRY_REGISTRY_CONFIGS_FILE:-""}"
  local CONFIG HOST PASSWORD USER
  if ! CONFIG=$(read_config GANTRY_REGISTRY_CONFIG 2>&1); then
    log ERROR "Failed to set CONFIG: ${CONFIG}" && return 1;
  fi
  if ! HOST=$(read_config GANTRY_REGISTRY_HOST 2>&1); then
    log ERROR "Failed to set HOST: ${HOST}" && return 1;
  fi
  if ! PASSWORD=$(read_config GANTRY_REGISTRY_PASSWORD 2>&1); then
    log ERROR "Failed to set PASSWORD: ${PASSWORD}" && return 1;
  fi
  if ! USER=$(read_config GANTRY_REGISTRY_USER 2>&1); then
    log ERROR "Failed to set USER: ${USER}" && return 1;
  fi
  if [ -n "${USER}" ]; then
    login_registry "${USER}" "${PASSWORD}" "${HOST}" "${CONFIG}"
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
      log ERROR "${CONFIGS_FILE} format error. A line should contains only \"<CONFIG> <HOST> <USER> <PASSWORD>\". Got \"${LINE}\"."
      continue
    fi
    login_registry "${USER}" "${PASSWORD}" "${HOST}" "${CONFIG}"
  done <"${CONFIGS_FILE}"
}

send_notification() {
  local TITLE="${1}"
  local BODY="${2}"
  if ! type notify_summary >/dev/null 2>&1; then
    return 0
  fi
  notify_summary "${TITLE}" "${BODY}"
}

add_image_to_remove() {
  local IMAGE="${1}"
  if [ -z "${GLOBAL_IMAGES_TO_REMOVE}" ]; then
    GLOBAL_IMAGES_TO_REMOVE=${IMAGE}
    return 0
  fi
  GLOBAL_IMAGES_TO_REMOVE=$(add_uniq_to_list "${GLOBAL_IMAGES_TO_REMOVE}" "${IMAGE}")
}

remove_images() {
  local CLEANUP_IMAGES="${GANTRY_CLEANUP_IMAGES:-"true"}"
  if ! is_true "${CLEANUP_IMAGES}"; then
    log INFO "Skip removing images."
    return 0
  fi
  local SERVICE_NAME="${1:-"docker-image-remover"}"
  docker_service_remove "${SERVICE_NAME}"
  if [ -z "${GLOBAL_IMAGES_TO_REMOVE}" ]; then
    log INFO "No images to remove."
    return 0
  fi
  local IMAGE_NUM=
  IMAGE_NUM=$(get_number_of_elements "${GLOBAL_IMAGES_TO_REMOVE}")
  log INFO "Removing ${IMAGE_NUM} image(s):"
  for I in $(echo "${GLOBAL_IMAGES_TO_REMOVE}" | tr '\n' ' '); do
    log INFO "- ${I}"
  done
  docker_global_job --name "${SERVICE_NAME}" \
    --restart-condition on-failure \
    --restart-max-attempts 1 \
    --mount type=bind,source=/var/run/docker.sock,destination=/var/run/docker.sock \
    --env "IMAGES_TO_REMOVE=$(echo "${GLOBAL_IMAGES_TO_REMOVE}" | tr '\n' ' ')" \
    --entrypoint sh \
    alpinelinux/docker-cli \
    -c "
      log() {
        echo \"\${@}\";
      };
      remove_container() {
        local IMAGE=\${1};
        local STATUS=\${2};
        if ! CIDS=\$(docker container ls --all --filter \"ancestor=\${IMAGE}\" --filter \"status=\${STATUS}\" --format '{{.ID}}' 2>&1); then
          log ERROR \"Failed to list \${STATUS} containers with image \${IMAGE}. \$(echo \${CIDS})\";
          return 1;
        fi;
        for CID in \${CIDS}; do
          CNAME=\$(docker container inspect --format '{{.Name}}' \"\${CID}\");
          if ! CRM_MSG=\$(docker container rm \${CID} 2>&1); then
            log ERROR \"Failed to remove \${STATUS} container \${CNAME}, which is using image \${IMAGE}. \$(echo \${CRM_MSG})\";
            continue;
          fi
          log INFO \"Removed \${STATUS} container \${CNAME}. It was using image \${IMAGE}.\";
        done;
      };
      for IMAGE in \${IMAGES_TO_REMOVE}; do
        if ! docker image inspect \${IMAGE} 1>/dev/null 2>&1 ; then
          log DEBUG \"There is no image \${IMAGE} on the node.\";
          continue;
        fi;
        remove_container \${IMAGE} exited;
        remove_container \${IMAGE} dead;
        if ! RMI_MSG=\$(docker rmi \${IMAGE} 2>&1); then
          log ERROR \"Failed to remove image \${IMAGE}. \$(echo \${RMI_MSG})\";
          continue;
        fi;
        log INFO \"Removed image \${IMAGE}.\";
      done;
      log INFO \"Done.\";
      "
  wait_service_state "${SERVICE_NAME}" "false" "true";
  docker_service_logs "${SERVICE_NAME}"
  docker_service_remove "${SERVICE_NAME}"
}

add_service_updated() {
  local SERVICE_NAME="${1}"
  if [ -z "${GLOBAL_SERVICES_UPDATED}" ]; then
    GLOBAL_SERVICES_UPDATED=${SERVICE_NAME}
    return 0
  fi
  GLOBAL_SERVICES_UPDATED=$(add_uniq_to_list "${GLOBAL_SERVICES_UPDATED}" "${SERVICE_NAME}")
}

report_services_updated() {
  if [ -z "${GLOBAL_SERVICES_UPDATED}" ]; then
    echo "No services updated."
    return 0
  fi
  local UPDATED_NUM=
  UPDATED_NUM=$(get_number_of_elements "${GLOBAL_SERVICES_UPDATED}")
  echo "${UPDATED_NUM} service(s) updated:"
  for S in ${GLOBAL_SERVICES_UPDATED}; do
    echo "- ${S}"
  done
}

add_service_update_failed() {
  local SERVICE_NAME="${1}"
  if [ -z "${GLOBAL_SERVICES_UPDATE_FAILED}" ]; then
    GLOBAL_SERVICES_UPDATE_FAILED=${SERVICE_NAME}
    return 0
  fi
  GLOBAL_SERVICES_UPDATE_FAILED=$(add_uniq_to_list "${GLOBAL_SERVICES_UPDATE_FAILED}" "${SERVICE_NAME}")
}

report_services_update_failed() {
  if [ -z "${GLOBAL_SERVICES_UPDATE_FAILED}" ]; then
    return 0
  fi
  local FAILED_NUM=
  FAILED_NUM=$(get_number_of_elements "${GLOBAL_SERVICES_UPDATE_FAILED}")
  echo "${FAILED_NUM} service(s) update failed:"
  for S in ${GLOBAL_SERVICES_UPDATE_FAILED}; do
    echo "- ${S}"
  done
}

get_number_of_elements() {
  local LIST="${*}"
  [ -z "${LIST}" ] && echo 0 && return 0
  # SC2086: Double quote to prevent globbing and word splitting.
  # shellcheck disable=SC2086
  set ${LIST}
  local NUM=$#
  echo "${NUM}"
}

report_services() {
  local UPDATED_MSG=
  local FAILED_MSG=
  UPDATED_MSG=$(report_services_updated)
  echo "${UPDATED_MSG}" | log_lines INFO
  FAILED_MSG=$(report_services_update_failed)
  echo "${FAILED_MSG}" | log_lines INFO
  # Send notification
  local UPDATED_NUM FAILED_NUM TITLE BODY
  UPDATED_NUM=$(get_number_of_elements "${GLOBAL_SERVICES_UPDATED}")
  FAILED_NUM=$(get_number_of_elements "${GLOBAL_SERVICES_UPDATE_FAILED}")
  TITLE="[gantry] ${UPDATED_NUM} services updated ${FAILED_NUM} failed"
  BODY=$(echo -e "${UPDATED_MSG}\n${FAILED_MSG}")
  send_notification "${TITLE}" "${BODY}"
}

in_list() {
  local LIST="${1}"
  local SEARCHED_ITEM="${2}"
  for ITEM in ${LIST}; do
    if [ "${ITEM}" = "${SEARCHED_ITEM}" ]; then
      return 0
    fi
  done
  return 1
}

service_is_self() {
  local SELF="${GANTRY_SERVICES_SELF:-""}"
  local SERVICE_NAME="${1}"
  [ "${SERVICE_NAME}" = "${SELF}" ]
}

get_service_mode() {
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
service_is_job() {
  local SERVICE_NAME="${1}"
  local MODE=
  if ! MODE=$(get_service_mode "${SERVICE_NAME}"); then
    return 1
  fi
  # Looking for replicated-job or global-job
  echo "${MODE}" | grep "job"
}

service_is_replicated() {
  local SERVICE_NAME="${1}"
  local MODE=
  if ! MODE=$(get_service_mode "${SERVICE_NAME}"); then
    return 1
  fi
  # Looking for replicated, not replicated-job
  if [ "${MODE}" != "replicated" ]; then
    return 1
  fi
  echo "${MODE}"
}

get_config_from_service() {
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

get_image_info() {
  local MANIFEST_OPTIONS="${GANTRY_MANIFEST_OPTIONS:-""}"
  local MANIFEST_CMD="${1}"
  local IMAGE="${2}"
  local DOCKER_CONFIG="${3}"
  if echo "${MANIFEST_CMD}" | grep -q -i "manifest"; then
    # SC2086: Double quote to prevent globbing and word splitting.
    # shellcheck disable=SC2086
    docker ${DOCKER_CONFIG} manifest inspect ${MANIFEST_OPTIONS} "${IMAGE}"
    return $?
  fi
  # https://github.com/orgs/community/discussions/45779
  # SC2086: Double quote to prevent globbing and word splitting.
  # shellcheck disable=SC2086
  docker ${DOCKER_CONFIG} buildx imagetools inspect ${MANIFEST_OPTIONS} "${IMAGE}"
}

# echo nothing if we found no new images.
# echo the image if we found a new image.
# return the number of errors.
inspect_image() {
  local MANIFEST_CMD="${GANTRY_MANIFEST_CMD:-"buildx"}"
  local SERVICE_NAME="${1}"
  local DOCKER_CONFIG="${2}"
  local IMAGE_WITH_DIGEST=
  if ! IMAGE_WITH_DIGEST=$(docker service inspect -f '{{.Spec.TaskTemplate.ContainerSpec.Image}}' "${SERVICE_NAME}" 2>&1); then
    log ERROR "Failed to obtain image from service ${SERVICE_NAME}. ${IMAGE_WITH_DIGEST}"
    return 1
  fi
  local IMAGE=
  local DIGEST=
  IMAGE=$(echo "${IMAGE_WITH_DIGEST}" | cut -d@ -f1)
  DIGEST=$(echo "${IMAGE_WITH_DIGEST}" | cut -d@ -f2)
  # Never skip inspecting self
  if echo "${MANIFEST_CMD}" | grep -q -i "none" && ! service_is_self "${SERVICE_NAME}"; then
    echo "${IMAGE}"
    return 0
  fi
  if in_list "${GLOBAL_NO_NEW_IMAGES}" "${DIGEST}"; then
    return 0
  fi
  if in_list "${GLOBAL_NEW_IMAGES}" "${DIGEST}"; then
    echo "${IMAGE}"
    return 0
  fi
  local IMAGE_INFO=
  if ! IMAGE_INFO=$(get_image_info "${MANIFEST_CMD}" "${IMAGE}" "${DOCKER_CONFIG}" 2>&1); then
    log ERROR "Image ${IMAGE} does not exist or it is not available. ${IMAGE_INFO}"
    return 1
  fi
  if [ -n "${DIGEST}" ] && echo "${IMAGE_INFO}" | grep -q "${DIGEST}"; then
    GLOBAL_NO_NEW_IMAGES=$(add_uniq_to_list "${GLOBAL_NO_NEW_IMAGES}" "${DIGEST}")
    return 0
  fi
  GLOBAL_NEW_IMAGES=$(add_uniq_to_list "${GLOBAL_NEW_IMAGES}" "${DIGEST}")
  echo "${IMAGE}"
  return 0
}

get_number_of_running_tasks() {
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

get_service_update_additional_options() {
  local SERVICE_NAME="${1}"
  local NUM_RUNS=
  NUM_RUNS=$(get_number_of_running_tasks "${SERVICE_NAME}")
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
    if MODE=$(service_is_replicated "${SERVICE_NAME}"); then
      OPTIONS="${OPTIONS} --replicas=0"
    fi
  fi
  echo "${OPTIONS}"
}

rollback_service() {
  local ROLLBACK_ON_FAILURE="${GANTRY_ROLLBACK_ON_FAILURE:-"true"}"
  local ROLLBACK_OPTIONS="${GANTRY_ROLLBACK_OPTIONS:-""}"
  local SERVICE_NAME="${1}"
  local DOCKER_CONFIG="${2}"
  local ADDITIONAL_OPTIONS="${3}"
  if ! is_true "${ROLLBACK_ON_FAILURE}"; then
    return 0
  fi
  log INFO "Rolling back ${SERVICE_NAME}."
  local ROLLBACK_MSG=
  # Add "-quiet" to suppress progress output.
  # SC2086: Double quote to prevent globbing and word splitting.
  # shellcheck disable=SC2086
  ROLLBACK_MSG=$(docker ${DOCKER_CONFIG} service update --quiet ${ADDITIONAL_OPTIONS} ${ROLLBACK_OPTIONS} --rollback "${SERVICE_NAME}" 2>&1)
  local RETURN_VALUE=$?
  if [ ${RETURN_VALUE} -ne 0 ]; then
    log ERROR "Failed to roll back ${SERVICE_NAME}. ${ROLLBACK_MSG}"
  else
    log INFO "Rolled back ${SERVICE_NAME}."
  fi
  return ${RETURN_VALUE}
}

update_single_service() {
  local UPDATE_JOBS="${GANTRY_UPDATE_JOBS:-"false"}"
  local UPDATE_TIMEOUT_SECONDS="${GANTRY_UPDATE_TIMEOUT_SECONDS:-300}"
  local UPDATE_OPTIONS="${GANTRY_UPDATE_OPTIONS:-""}"
  if ! is_number "${UPDATE_TIMEOUT_SECONDS}"; then
    log ERROR "GANTRY_UPDATE_TIMEOUT_SECONDS must be a number. Got \"${GANTRY_UPDATE_TIMEOUT_SECONDS}\"."
    return 1;
  fi
  local SERVICE_NAME="${1}"
  local MODE=
  if ! is_true "${UPDATE_JOBS}" && MODE=$(service_is_job "${SERVICE_NAME}"); then
    log DEBUG "Skip updating service in ${MODE} mode: ${SERVICE_NAME}."
    return 0;
  fi
  local DOCKER_CONFIG=
  DOCKER_CONFIG=$(get_config_from_service "${SERVICE_NAME}")
  [ -n "${DOCKER_CONFIG}" ] && log DEBUG "Add option \"${DOCKER_CONFIG}\" to docker commands."
  local IMAGE=
  IMAGE=$(inspect_image "${SERVICE_NAME}" "${DOCKER_CONFIG}")
  local RETURN_VALUE=$?
  [ ${RETURN_VALUE} -ne 0 ] && return ${RETURN_VALUE}
  [ -z "${IMAGE}" ] && log INFO "No new images." && return 0
  log INFO "Updating with image ${IMAGE}"
  local ADDITIONAL_OPTIONS=
  ADDITIONAL_OPTIONS=$(get_service_update_additional_options "${SERVICE_NAME}")
  [ -n "${ADDITIONAL_OPTIONS}" ] && log DEBUG "Add option \"${ADDITIONAL_OPTIONS}\" to the docker service update command."
  # Add "-quiet" to suppress progress output.
  # SC2086: Double quote to prevent globbing and word splitting.
  # shellcheck disable=SC2086
  if ! UPDATE_MSG=$(timeout "${UPDATE_TIMEOUT_SECONDS}" docker ${DOCKER_CONFIG} service update --quiet ${ADDITIONAL_OPTIONS} ${UPDATE_OPTIONS} --image="${IMAGE}" "${SERVICE_NAME}" 2>&1); then
    log ERROR "docker service update failed or timeout. ${UPDATE_MSG}"
    # "service update --rollback" needs to take different options from "service update"
    # Today no options are added based on services label/status. This is just a placeholder now.
    local ROLLBACK_ADDITIONAL_OPTIONS=
    rollback_service "${SERVICE_NAME}" "${DOCKER_CONFIG}" "${ROLLBACK_ADDITIONAL_OPTIONS}"
    add_service_update_failed "${SERVICE_NAME}"
    return 1
  fi
  local PREVIOUS_IMAGE=
  local CURRENT_IMAGE=
  PREVIOUS_IMAGE=$(docker service inspect -f '{{.PreviousSpec.TaskTemplate.ContainerSpec.Image}}' "${SERVICE_NAME}")
  CURRENT_IMAGE=$(docker service inspect -f '{{.Spec.TaskTemplate.ContainerSpec.Image}}' "${SERVICE_NAME}")
  if [ "${PREVIOUS_IMAGE}" = "${CURRENT_IMAGE}" ]; then
    log INFO "No updates."
    return 0
  fi
  add_service_updated "${SERVICE_NAME}"
  add_image_to_remove "${PREVIOUS_IMAGE}"
  log INFO "UPDATED."
  return 0
}

get_services_filted() {
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
  GLOBAL_IMAGES_TO_REMOVE=
  GLOBAL_SERVICES_UPDATED=
  GLOBAL_SERVICES_UPDATE_FAILED=
  GLOBAL_NO_NEW_IMAGES=
  GLOBAL_NEW_IMAGES=
  authenticate_to_registries
}

gantry_get_services_list() {
  local SERVICES_EXCLUDED="${GANTRY_SERVICES_EXCLUDED:-""}"
  local SERVICES_EXCLUDED_FILTERS="${GANTRY_SERVICES_EXCLUDED_FILTERS:-""}"
  local SERVICES_FILTERS="${GANTRY_SERVICES_FILTERS:-""}"
  local SERVICES=
  if ! SERVICES=$(get_services_filted "${SERVICES_FILTERS}"); then
    return 1
  fi
  if [ -n "${SERVICES_EXCLUDED_FILTERS}" ]; then
    local SERVICES_FROM_EXCLUDED_FILTERS=
    if ! SERVICES_FROM_EXCLUDED_FILTERS=$(get_services_filted "${SERVICES_EXCLUDED_FILTERS}"); then
      return 1
    fi
    SERVICES_EXCLUDED="${SERVICES_EXCLUDED} ${SERVICES_FROM_EXCLUDED_FILTERS}"
  fi
  local LIST=
  local HAS_SELF=
  for S in ${SERVICES} ; do
    if in_list "${SERVICES_EXCLUDED}" "${S}" ; then
      continue
    fi
    # Add self to the first of the list.
    if service_is_self "${S}"; then
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
    LOG_SCOPE="Updating service ${SERVICE}"
    update_single_service "${SERVICE}"
    ACCUMULATED_ERRORS=$((ACCUMULATED_ERRORS + $?))
  done
  LOG_SCOPE=${LOG_SCOPE_SAVED}
  return ${ACCUMULATED_ERRORS}
}

gantry_finalize() {
  local STACK="${1:-gantry}"
  report_services;
  remove_images "${STACK}_image-remover"
}
