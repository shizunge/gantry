# shellcheck shell=sh
# Copyright (C) 2024 Shizun Ge
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

set -a

# Constant strings for checks.
export MUST_BE_A_NUMBER="must be a number"
export SKIP_UPDATING_ALL="Skip updating all services"
export SKIP_REASON_NOT_SWARM_MANAGER="is not a swarm manager"
export SKIP_REASON_PREVIOUS_ERRORS="due to previous error\(s\)"
export EXCLUDE_SERVICE="Exclude service"
export SKIP_UPDATING="Skip updating"
export SKIP_REASON_IS_JOB="because it is in .*job mode"
export SKIP_REASON_NO_KNOWN_NEWER_IMAGE="because there is no known newer version of image"
export SKIP_REASON_MANIFEST_FAILURE="because there is a failure to obtain the manifest from the registry"
export SKIP_REASON_CURRENT_IS_LATEST="because the current version is the latest"
export PERFORM_UPDATING="Perform updating"
export PERFORM_REASON_MANIFEST_CMD_IS_NONE="because MANIFEST_CMD is \"none\""
export PERFORM_REASON_KNOWN_NEWER_IMAGE="because there is a known newer version of image"
export PERFORM_REASON_DIGEST_IS_EMPTY="because DIGEST is empty"
export PERFORM_REASON_HAS_NEWER_IMAGE="because there is a newer version"
export IMAGE_NOT_EXIST="does not exist or it is not available"
export ADDING_OPTIONS="Adding options"
export NUM_SERVICES_SKIP_JOBS="Skip updating [0-9]+ service\(s\) due to they are job\(s\)"
export NUM_SERVICES_INSPECT_FAILURE="Failed to inspect [0-9]+ service\(s\)"
export NUM_SERVICES_NO_NEW_IMAGES="No new images for [0-9]+ service\(s\)"
export NUM_SERVICES_UPDATING="Updating [0-9]+ service\(s\)"
export NO_UPDATES="No updates"
export UPDATED="UPDATED"
export ROLLING_BACK="Rolling back"
export FAILED_TO_ROLLBACK="Failed to roll back"
export ROLLED_BACK="Rolled back"
export NO_SERVICES_UPDATED="No services updated"
export NUM_SERVICES_UPDATED="[0-9]+ service\(s\) updated"
export SERVICES_UPDATED="service\(s\) updated"
export NUM_SERVICES_UPDATE_FAILED="[0-9]+ service\(s\) update failed"
export NUM_SERVICES_ERRORS="Skip updating [0-9]+ service\(s\) due to error\(s\)"
export NO_IMAGES_TO_REMOVE="No images to remove"
export REMOVING_NUM_IMAGES="Removing [0-9]+ image\(s\)"
export SKIP_REMOVING_IMAGES="Skip removing images"
export REMOVED_IMAGE="Removed image"
export FAILED_TO_REMOVE_IMAGE="Failed to remove image"
export SCHEDULE_NEXT_UPDATE_AT="Schedule next update at"
export SLEEP_SECONDS_BEFORE_NEXT_UPDATE="Sleep [0-9]+ seconds before next update"

display_output() {
  echo "${display_output:-""}"
}

common_setup_new_image() {
  local TEST_NAME="${1}"
  local IMAGE_WITH_TAG="${2}"
  local SERVICE_NAME="${3}"
  initialize_test "${TEST_NAME}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_replicated_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
}

common_setup_new_image_multiple() {
  local TEST_NAME="${1}"
  local IMAGE_WITH_TAG="${2}"
  local SERVICE_NAME="${3}"
  local MAX_SERVICES_NUM="${4}"
  initialize_test "${TEST_NAME}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  local NUM=
  local PIDS=
  for NUM in $(seq 0 "${MAX_SERVICES_NUM}"); do
    local SERVICE_NAME_NUM="${SERVICE_NAME}-${NUM}"
    start_replicated_service "${SERVICE_NAME_NUM}" "${IMAGE_WITH_TAG}" &
    PIDS="${!} ${PIDS}"
  done
  # SC2086 (info): Double quote to prevent globbing and word splitting.
  # shellcheck disable=SC2086
  wait ${PIDS}
  build_and_push_test_image "${IMAGE_WITH_TAG}"
}

common_setup_no_new_image() {
  local TEST_NAME="${1}"
  local IMAGE_WITH_TAG="${2}"
  local SERVICE_NAME="${3}"
  initialize_test "${TEST_NAME}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_replicated_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
  # No image updates after service started.
}

common_setup_job() {
  local TEST_NAME="${1}"
  local IMAGE_WITH_TAG="${2}"
  local SERVICE_NAME="${3}"
  local TASK_SECONDS="${4}"
  initialize_test "${TEST_NAME}"
  # The task will finish in ${TASK_SECONDS} seconds, when ${TASK_SECONDS} is not empty
  build_and_push_test_image "${IMAGE_WITH_TAG}" "${TASK_SECONDS}"
  _start_replicated_job "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
}

common_setup_timeout() {
  local TEST_NAME="${1}"
  local IMAGE_WITH_TAG="${2}"
  local SERVICE_NAME="${3}"
  local TIMEOUT="${4}"
  local DOUBLE_TIMEOUT=$((TIMEOUT+TIMEOUT))
  initialize_test "${TEST_NAME}"
  # -1 thus the task runs forever.
  # exit will take double of the timeout.
  build_and_push_test_image "${IMAGE_WITH_TAG}" "-1" "${DOUBLE_TIMEOUT}"
  start_replicated_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
}

common_cleanup() {
  local TEST_NAME="${1}"
  local IMAGE_WITH_TAG="${2}"
  local SERVICE_NAME="${3}"
  stop_service "${SERVICE_NAME}"
  prune_local_test_image "${IMAGE_WITH_TAG}"
  finalize_test "${TEST_NAME}"
}

common_cleanup_multiple() {
  local TEST_NAME="${1}"
  local IMAGE_WITH_TAG="${2}"
  local SERVICE_NAME="${3}"
  local MAX_SERVICES_NUM="${4}"
  local NUM=
  local PIDS=
  for NUM in $(seq 0 "${MAX_SERVICES_NUM}"); do
    local SERVICE_NAME_NUM="${SERVICE_NAME}-${NUM}"
    stop_service "${SERVICE_NAME_NUM}" &
    PIDS="${!} ${PIDS}"
  done
  # SC2086 (info): Double quote to prevent globbing and word splitting.
  # shellcheck disable=SC2086
  wait ${PIDS}
  prune_local_test_image "${IMAGE_WITH_TAG}"
  finalize_test "${TEST_NAME}"
}

spec_expect_message() {
  _expect_message "${spec_expect_message:-""}" "${1}"
}

spec_expect_multiple_messages() {
  _expect_multiple_messages "${spec_expect_multiple_messages:-""}" "${1}"
}

spec_expect_no_message() {
  _expect_no_message "${spec_expect_no_message:-""}" "${1}"
}

_init_swarm() {
  local SELF_ID=
  SELF_ID=$(docker node inspect self --format "{{.Description.Hostname}}" 2>/dev/null);
  if [ -n "${SELF_ID}" ]; then
    echo "Host ${SELF_ID} is already a swarm manager."
    return 0
  fi
  echo "Run docker swarm init"
  docker swarm init 2>&1
}

# Image for the software under test (SUT)
_get_sut_image() {
  local SUT_REPO_TAG="${GANTRY_TEST_CONTAINER_REPO_TAG:-""}"
  echo "${SUT_REPO_TAG}"
}

_next_available_port() {
  local START="${1}"
  local LIMIT="${2:-1}"
  local END=$((START+LIMIT))
  [ "${END}" -le "${START}" ] && END=$((START+1))
  local PORT="${START}"
  while nc -z localhost "${PORT}"; do
    PORT=$((PORT+1))
    if [ "${PORT}" -ge "${END}" ]; then
      PORT=
      return 1
    fi
  done
  echo "${PORT}"
}

_get_test_registry_file() {
  local SUITE_NAME="${1:?}"
  SUITE_NAME=$(echo "${SUITE_NAME}" | tr ' ' '-')
  echo "/tmp/TEST_REGISTRY-${SUITE_NAME}"
}

load_test_registry() {
  local SUITE_NAME="${1:?}"
  local REGISTRY_FILE=
  REGISTRY_FILE=$(_get_test_registry_file "${SUITE_NAME}")
  [ ! -r "${REGISTRY_FILE}" ] && return 1
  cat "${REGISTRY_FILE}"
}

_start_registry() {
  local SUITE_NAME="${1:?}"
  SUITE_NAME=$(echo "${SUITE_NAME}" | tr ' ' '-')
  local SUITE_NAME_LENGTH="${#SUITE_NAME}"
  local REGISTRY_SERVICE_NAME="gantry-test-registry-${SUITE_NAME}"
  local REGISTRY_BASE="127.0.0.1"
  local REGISTRY_PORT=$((55000+SUITE_NAME_LENGTH*2))
  local TEST_REGISTRY="${REGISTRY_BASE}:${REGISTRY_PORT}"
  export TEST_USERNAME="gantry"
  export TEST_PASSWORD="gantry"
  local REGISTRY_IMAGE="docker.io/registry"
  local TRIES=0
  local MAX_RETRIES=50
  local PORT_LIMIT=500
  while true; do
    if ! REGISTRY_PORT=$(_next_available_port "${REGISTRY_PORT}" "${PORT_LIMIT}" 2>&1); then
      echo "_start_registry _next_available_port error: ${REGISTRY_PORT}" >&2
      return 1
    fi
    if [ -z "${REGISTRY_PORT}" ]; then
      echo "_start_registry _next_available_port error: REGISTRY_PORT is empty." >&2
      return 1
    fi
    stop_service "${REGISTRY_SERVICE_NAME}" 1>/dev/null 2>&1
    TEST_REGISTRY="${REGISTRY_BASE}:${REGISTRY_PORT}"
    echo "${SUITE_NAME} starting registry ${TEST_REGISTRY} "
    # SC2046 (warning): Quote this to prevent word splitting.
    # shellcheck disable=SC2046
    if docker service create --quiet \
      --name "${REGISTRY_SERVICE_NAME}" \
      --restart-condition "on-failure" \
      --restart-max-attempts 5 \
      $(_location_constraints) \
      --mode=replicated \
      -p "${REGISTRY_PORT}:5000" \
      "${REGISTRY_IMAGE}" 2>&1; then
      break;
    fi
    if [ "${TRIES}" -ge "${MAX_RETRIES}" ]; then
      echo "_start_registry Reach MAX_RETRIES ${MAX_RETRIES}" >&2
      return 1
    fi
    TRIES=$((TRIES+1))
    REGISTRY_PORT=$((REGISTRY_PORT+1))
    sleep 1
  done
  local REGISTRY_FILE=
  if ! REGISTRY_FILE=$(_get_test_registry_file "${SUITE_NAME}" 2>&1); then
    echo "_start_registry _get_test_registry_file error: ${REGISTRY_FILE}" >&2
    return 1
  fi
  echo "${SUITE_NAME} uses registry ${TEST_REGISTRY}."
  echo "${TEST_REGISTRY}" > "${REGISTRY_FILE}"
}

_stop_registry() {
  local SUITE_NAME="${1:?}"
  SUITE_NAME=$(echo "${SUITE_NAME}" | tr ' ' '-')
  local REGISTRY_SERVICE_NAME="gantry-test-registry-${SUITE_NAME}"
  local REGISTRY=
  REGISTRY=$(load_test_registry "${SUITE_NAME}") || return 1
  echo "Removing registry ${REGISTRY} "
  stop_service "${REGISTRY_SERVICE_NAME}"
  local REGISTRY_FILE=
  REGISTRY_FILE=$(_get_test_registry_file "${SUITE_NAME}") || return 1
  rm "${REGISTRY_FILE}"
  return 0
}

initialize_all_tests() {
  local SUITE_NAME="${1:-"gantry"}"
  SUITE_NAME=$(echo "${SUITE_NAME}" | tr ' ' '-')
  local SCRIPT_DIR=
  SCRIPT_DIR="$(_get_script_dir)" || return 1
  source "${SCRIPT_DIR}/../src/lib-common.sh"
  echo "=============================="
  echo "== Starting suite ${SUITE_NAME}"
  echo "=============================="
  _init_swarm
  _start_registry "${SUITE_NAME}"
}

# finish_all_tests should return non zero when there are errors.
finish_all_tests() {
  local SUITE_NAME="${1:-"gantry"}"
  SUITE_NAME=$(echo "${SUITE_NAME}" | tr ' ' '-')
  _stop_registry "${SUITE_NAME}"
  echo "=============================="
  echo "== Finished all tests in ${SUITE_NAME}"
  echo "=============================="
}

initialize_test() {
  local TEST_NAME="${1:-"gantry"}"
  echo "=============================="
  echo "== Starting ${TEST_NAME}"
  echo "=============================="
}

reset_gantry_env() {
  local SERVICE_NAME="${1}"
  export DOCKER_HOST=
  export GANTRY_LOG_LEVEL="DEBUG"
  export GANTRY_NODE_NAME=
  export GANTRY_POST_RUN_CMD=
  export GANTRY_PRE_RUN_CMD=
  export GANTRY_SLEEP_SECONDS=
  export GANTRY_ROLLBACK_ON_FAILURE=
  export GANTRY_REGISTRY_CONFIG=
  export GANTRY_REGISTRY_CONFIG_FILE=
  export GANTRY_REGISTRY_CONFIGS_FILE=
  export GANTRY_REGISTRY_HOST=
  export GANTRY_REGISTRY_HOST_FILE=
  export GANTRY_REGISTRY_PASSWORD=
  export GANTRY_REGISTRY_PASSWORD_FILE=
  export GANTRY_REGISTRY_USER=
  export GANTRY_REGISTRY_USER_FILE=
  export GANTRY_SERVICES_EXCLUDED=
  export GANTRY_SERVICES_EXCLUDED_FILTERS=
  if [ -z "${SERVICE_NAME}" ]; then
    export GANTRY_SERVICES_FILTERS=
  else
    export GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  fi
  export GANTRY_SERVICES_SELF=
  export GANTRY_MANIFEST_CMD=
  export GANTRY_MANIFEST_NUM_WORKERS=
  export GANTRY_MANIFEST_OPTIONS=
  export GANTRY_ROLLBACK_OPTIONS=
  export GANTRY_UPDATE_JOBS=
  export GANTRY_UPDATE_NUM_WORKERS=
  export GANTRY_UPDATE_OPTIONS=
  export GANTRY_UPDATE_TIMEOUT_SECONDS=
  export GANTRY_CLEANUP_IMAGES=
  export GANTRY_CLEANUP_IMAGES_OPTIONS=
  export GANTRY_CLEANUP_IMAGES_REMOVER=ghcr.io/shizunge/gantry-development
  export GANTRY_IMAGES_TO_REMOVE=
  export GANTRY_NOTIFICATION_APPRISE_URL=
  export GANTRY_NOTIFICATION_CONDITION=
  export GANTRY_NOTIFICATION_TITLE=
}

finalize_test() {
  local TEST_NAME="${1}"
  local RED='\033[0;31m'
  local GREEN='\033[0;32m'
  local NO_COLOR='\033[0m'
  local TSET_STATUS="DONE"
  local RETURN_VALUE=0
  echo "=============================="
  echo -e "== ${TSET_STATUS} ${TEST_NAME}"
  echo "=============================="
  return "${RETURN_VALUE}"
}

get_image_with_tag() {
  local SUITE_NAME="${1:?}"
  SUITE_NAME=$(echo "${SUITE_NAME}" | tr ' ' '-')
  local IMAGE="gantry/test"
  local REGISTRY=
  REGISTRY=$(load_test_registry "${SUITE_NAME}") || return 1
  if [ -z "${IMAGE}" ]; then
    echo "IMAGE is empty." >&2
    return 1
  fi
  [ "${REGISTRY}" = "docker.io" ] && REGISTRY=""
  local IMAGE_WITH_TAG="${IMAGE}"
  if [ -n "${REGISTRY}" ]; then
    IMAGE_WITH_TAG="${REGISTRY}/${IMAGE_WITH_TAG}"
  fi
  IMAGE_WITH_TAG="${IMAGE_WITH_TAG}:${SUITE_NAME}-$(unique_id)"
  echo "${IMAGE_WITH_TAG}"
}

_handle_failure() {
  local MESSAGE="${1}"
  local RED='\033[0;31m'
  local NO_COLOR='\033[0m'
  echo -e "${RED}ERROR${NO_COLOR} ${MESSAGE}"
}

_expect_multiple_messages() {
  TEXT="${1}"
  MESSAGE="${2}"
  local GREEN='\033[0;32m'
  local NO_COLOR='\033[0m'
  if ! ACTUAL_MSG=$(echo "${TEXT}" | grep -Po "${MESSAGE}"); then
    _handle_failure "Failed to find expected message \"${MESSAGE}\"."
    return 1
  fi
  local COUNT=
  COUNT=$(echo "${TEXT}" | grep -Poc "${MESSAGE}");
  if [ "${COUNT}" -le 1 ]; then
    _handle_failure "Failed to find multiple expected messages \"${MESSAGE}\" COUNT=${COUNT}."
    return 1
  fi
  echo -e "${GREEN}EXPECTED${NO_COLOR} found ${COUNT} messages: ${ACTUAL_MSG}"
}

_expect_message() {
  TEXT="${1}"
  MESSAGE="${2}"
  local GREEN='\033[0;32m'
  local NO_COLOR='\033[0m'
  if ! ACTUAL_MSG=$(echo "${TEXT}" | grep -Po "${MESSAGE}"); then
    _handle_failure "Failed to find expected message \"${MESSAGE}\"."
    return 1
  fi
  echo -e "${GREEN}EXPECTED${NO_COLOR} found message: ${ACTUAL_MSG}"
}

_expect_no_message() {
  TEXT="${1}"
  MESSAGE="${2}"
  local GREEN='\033[0;32m'
  local NO_COLOR='\033[0m'
  if ACTUAL_MSG=$(echo "${TEXT}" | grep -Po "${MESSAGE}"); then
    _handle_failure "The following message should not present: \"${ACTUAL_MSG}\""
    return 1
  fi
  echo -e "${GREEN}EXPECTED${NO_COLOR} found no message matches: ${MESSAGE}"
}

unique_id() {
  # Try to generate a unique id.
  # To reduce the possibility that tests run in parallel on the same machine affect each other.
  local PID="$$"
  local RANDOM_STR=
  RANDOM_STR=$(head /dev/urandom | LANG=C tr -dc 'A-Za-z0-9' | head -c 8)
  echo "$(date +%s)-${PID}-${RANDOM_STR}"
}

build_test_image() {
  local IMAGE_WITH_TAG="${1}"
  local TASK_SECONDS="${2}"
  local EXIT_SECONDS="${3}"
  # Run the container forever
  local TASK_CMD="tail -f /dev/null;"
  if [ -n "${TASK_SECONDS}" ] && [ "${TASK_SECONDS}" -ge "0" ]; then
    # Finsih the job in the given time.
    TASK_CMD="sleep ${TASK_SECONDS};"
  fi
  local EXIT_CMD="sleep 0;"
  if [ -n "${EXIT_SECONDS}" ] && [ "${EXIT_SECONDS}" -gt "0" ]; then
    EXIT_CMD="sleep ${EXIT_SECONDS};"
  fi
  local FILE=
  FILE=$(mktemp)
  echo "FROM alpinelinux/docker-cli:latest" > "${FILE}"
  echo "ENTRYPOINT [\"sh\", \"-c\", \"echo $(unique_id); trap \\\"${EXIT_CMD}\\\" HUP INT TERM; ${TASK_CMD}\"]" >> "${FILE}"
  echo "Building ${IMAGE_WITH_TAG} "
  timeout 120 docker build --quiet --tag "${IMAGE_WITH_TAG}" --file "${FILE}" .
  rm "${FILE}"
}

build_and_push_test_image() {
  local IMAGE_WITH_TAG="${1}"
  local TASK_SECONDS="${2}"
  local EXIT_SECONDS="${3}"
  build_test_image "${IMAGE_WITH_TAG}" "${TASK_SECONDS}" "${EXIT_SECONDS}"
  echo "Pushing image "
  docker push --quiet "${IMAGE_WITH_TAG}"
}

prune_local_test_image() {
  local IMAGE_WITH_TAG="${1}"
  echo "Removing image ${IMAGE_WITH_TAG} "
  docker image rm "${IMAGE_WITH_TAG}" --force
}

wait_zero_running_tasks() {
  local SERVICE_NAME="${1}"
  local TIMEOUT_SECONDS="${2}"
  local NUM_RUNS=1
  local REPLICAS=
  local USED_SECONDS=0
  local TRIES=0
  local MAX_RETRIES=120
  echo "Wait until ${SERVICE_NAME} has zero running tasks."
  while [ "${NUM_RUNS}" -ne 0 ]; do
    if [ -n "${TIMEOUT_SECONDS}" ] && [ "${USED_SECONDS}" -ge "${TIMEOUT_SECONDS}" ]; then
      _handle_failure "Services ${SERVICE_NAME} does not stop after ${TIMEOUT_SECONDS} seconds."
      return 1
    fi
    if ! REPLICAS=$(docker service ls --filter "name=${SERVICE_NAME}" --format '{{.Replicas}} {{.Name}}' 2>&1); then
      _handle_failure "Failed to obtain task states of service ${SERVICE_NAME}: ${REPLICAS}"
      return 1
    fi
    # For `docker service ls --filter`, the name filter matches on all or the prefix of a service's name
    # See https://docs.docker.com/engine/reference/commandline/service_ls/#name
    # It does not do the exact match of the name. See https://github.com/moby/moby/issues/32985
    # We do an extra step to to perform the exact match.
    REPLICAS=$(echo "${REPLICAS}" | sed -n "s/\(.*\) ${SERVICE_NAME}$/\1/p")
    if [ "${TRIES}" -ge "${MAX_RETRIES}" ]; then
      echo "wait_zero_running_tasks Reach MAX_RETRIES ${MAX_RETRIES}" >&2
      return 1
    fi
    TRIES=$((TRIES+1))
    # https://docs.docker.com/engine/reference/commandline/service_ls/#examples
    # The REPLICAS is like "5/5" or "1/1 (3/5 completed)"
    # Get the number before the first "/".
    NUM_RUNS=$(echo "${REPLICAS}/" | cut -d '/' -f 1)
    sleep 1
    USED_SECONDS=$((USED_SECONDS+1))
  done
}

_hostname() {
  if [ -z "${STATIC_VAR_HOSTNAME}" ]; then
    local SELF_ID=
    SELF_ID=$(docker node inspect self --format "{{.Description.Hostname}}" 2>/dev/null);
    if [ -n "${SELF_ID}" ]; then
      export STATIC_VAR_HOSTNAME="${SELF_ID}"
    fi
  fi
  echo "${STATIC_VAR_HOSTNAME}"
}

_location_constraints() {
  local NODE_NAME=
  NODE_NAME="$(_hostname)"
  [ -z "${NODE_NAME}" ] && echo "" && return 0
  local ARGS="--constraint node.hostname==${NODE_NAME}";
  echo "${ARGS}"
}

_wait_service_state() {
  local SERVICE_NAME="${1}"
  local STATE="${2}"
  local TRIES=0
  local MAX_RETRIES=120
  while ! docker service ps --format "{{.CurrentState}}" "${SERVICE_NAME}" | grep -q "${STATE}"; do
    if [ "${TRIES}" -ge "${MAX_RETRIES}" ]; then
      echo "_wait_service_state Reach MAX_RETRIES ${MAX_RETRIES}" >&2
      return 1
    fi
    TRIES=$((TRIES+1))
    sleep 1
  done
}

start_replicated_service() {
  local SERVICE_NAME="${1}"
  local IMAGE_WITH_TAG="${2}"
  [ "${#SERVICE_NAME}" -gt 63 ] && SERVICE_NAME=${SERVICE_NAME:0:63}
  echo "Creating service ${SERVICE_NAME} in replicated mode "
  # SC2046 (warning): Quote this to prevent word splitting.
  # shellcheck disable=SC2046
  timeout 120 docker service create --quiet \
    --name "${SERVICE_NAME}" \
    --restart-condition "on-failure" \
    --restart-max-attempts 5 \
    $(_location_constraints) \
    --mode=replicated \
    "${IMAGE_WITH_TAG}"
}

start_global_service() {
  local SERVICE_NAME="${1}"
  local IMAGE_WITH_TAG="${2}"
  [ "${#SERVICE_NAME}" -gt 63 ] && SERVICE_NAME=${SERVICE_NAME:0:63}
  echo "Creating service ${SERVICE_NAME} in global mode "
  # SC2046 (warning): Quote this to prevent word splitting.
  # shellcheck disable=SC2046
  timeout 120 docker service create --quiet \
    --name "${SERVICE_NAME}" \
    --restart-condition "on-failure" \
    --restart-max-attempts 5 \
    $(_location_constraints) \
    --mode=global \
    "${IMAGE_WITH_TAG}"
}

_start_replicated_job() {
  local SERVICE_NAME="${1}"
  local IMAGE_WITH_TAG="${2}"
  [ "${#SERVICE_NAME}" -gt 63 ] && SERVICE_NAME=${SERVICE_NAME:0:63}
  echo "Creating service ${SERVICE_NAME} in replicated job mode "
  # SC2046 (warning): Quote this to prevent word splitting.
  # shellcheck disable=SC2046
  timeout 120 docker service create --quiet \
    --name "${SERVICE_NAME}" \
    --restart-condition "on-failure" \
    --restart-max-attempts 5 \
    $(_location_constraints) \
    --mode=replicated-job --detach=true \
    "${IMAGE_WITH_TAG}"
  # wait until the job is running
  _wait_service_state "${SERVICE_NAME}" "Running"
}

stop_service() {
  local SERVICE_NAME="${1}"
  echo "Removing service "
  docker service rm "${SERVICE_NAME}"
}

_get_script_dir() {
  # SC2128: Expanding an array without an index only gives the first element.
  # SC3054 (warning): In POSIX sh, array references are undefined.
  # shellcheck disable=SC2128,SC3054
  if [ -z "${BASH_SOURCE}" ] || [ -z "${BASH_SOURCE[0]}" ]; then
    echo "BASH_SOURCE is empty." >&2
    echo "."
    return 1
  fi
  local SCRIPT_DIR=
  # SC3054 (warning): In POSIX sh, array references are undefined.
  # shellcheck disable=SC3054
  SCRIPT_DIR="$( cd "$(dirname "${BASH_SOURCE[0]}")" || return 1; pwd -P )"
  if [ -d "${SCRIPT_DIR}/.git" ]; then
    # We may reach here if SCRIPT_DIR is "pwd -P".
    # Assume .git is in the project root folder, but not in the tests folder.
    SCRIPT_DIR="${SCRIPT_DIR}/tests"
  fi
  echo "${SCRIPT_DIR}"
}

_get_entrypoint() {
  if [ -n "${STATIC_VAR_ENTRYPOINT}" ]; then
    echo "${STATIC_VAR_ENTRYPOINT}"
    return 0
  fi
  local SCRIPT_DIR=
  SCRIPT_DIR="$(_get_script_dir)" || return 1
  export STATIC_VAR_ENTRYPOINT="${SCRIPT_DIR}/../src/entrypoint.sh"
  echo "source ${STATIC_VAR_ENTRYPOINT}"
}

_add_file_to_mount_options() {
  local MOUNT_OPTIONS="${1}"
  local FILE="${2}"
  if [ -n "${FILE}" ] && [ -r "${FILE}" ]; then
    MOUNT_OPTIONS="${MOUNT_OPTIONS} --mount type=bind,source=${FILE},target=${FILE}"
  fi
  echo "${MOUNT_OPTIONS}"
}

_run_gantry_container() {
  local STACK="${1}"
  local SUT_REPO_TAG=
  SUT_REPO_TAG="$(_get_sut_image)"
  if [ -z "${SUT_REPO_TAG}" ]; then
    return 1
  fi
  local SERVICE_NAME=
  SERVICE_NAME="gantry-test-SUT-$(unique_id)"
  docker service rm "${SERVICE_NAME}" >/dev/null 2>&1;
  local MOUNT_OPTIONS=
  MOUNT_OPTIONS=$(_add_file_to_mount_options "${MOUNT_OPTIONS}" "${GANTRY_REGISTRY_CONFIG_FILE}")
  MOUNT_OPTIONS=$(_add_file_to_mount_options "${MOUNT_OPTIONS}" "${GANTRY_REGISTRY_CONFIGS_FILE}")
  MOUNT_OPTIONS=$(_add_file_to_mount_options "${MOUNT_OPTIONS}" "${GANTRY_REGISTRY_HOST_FILE}")
  MOUNT_OPTIONS=$(_add_file_to_mount_options "${MOUNT_OPTIONS}" "${GANTRY_REGISTRY_PASSWORD_FILE}")
  MOUNT_OPTIONS=$(_add_file_to_mount_options "${MOUNT_OPTIONS}" "${GANTRY_REGISTRY_USER_FILE}")
  if [ "${GANTRY_LOG_LEVEL}" != "NONE" ]; then
    echo "Starting SUT service ${SERVICE_NAME} with image ${SUT_REPO_TAG}."
  fi
  local RETURN_VALUE=0
  local CMD_OUTPUT=
  # SC2086 (info): Double quote to prevent globbing and word splitting.
  # shellcheck disable=SC2086
  if ! CMD_OUTPUT=$(docker service create --name "${SERVICE_NAME}" \
    --mode replicated-job --restart-condition=none --network host \
    --constraint "node.role==manager" \
    --mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock \
    ${MOUNT_OPTIONS} \
    --env "DOCKER_HOST=${DOCKER_HOST}" \
    --env "GANTRY_LOG_LEVEL=${GANTRY_LOG_LEVEL}" \
    --env "GANTRY_NODE_NAME=${GANTRY_NODE_NAME}" \
    --env "GANTRY_POST_RUN_CMD=${GANTRY_POST_RUN_CMD}" \
    --env "GANTRY_PRE_RUN_CMD=${GANTRY_PRE_RUN_CMD}" \
    --env "GANTRY_SLEEP_SECONDS=${GANTRY_SLEEP_SECONDS}" \
    --env "GANTRY_REGISTRY_CONFIG=${GANTRY_REGISTRY_CONFIG}" \
    --env "GANTRY_REGISTRY_CONFIG_FILE=${GANTRY_REGISTRY_CONFIG_FILE}" \
    --env "GANTRY_REGISTRY_CONFIGS_FILE=${GANTRY_REGISTRY_CONFIGS_FILE}" \
    --env "GANTRY_REGISTRY_HOST=${GANTRY_REGISTRY_HOST}" \
    --env "GANTRY_REGISTRY_HOST_FILE=${GANTRY_REGISTRY_HOST_FILE}" \
    --env "GANTRY_REGISTRY_PASSWORD=${GANTRY_REGISTRY_PASSWORD}" \
    --env "GANTRY_REGISTRY_PASSWORD_FILE=${GANTRY_REGISTRY_PASSWORD_FILE}" \
    --env "GANTRY_REGISTRY_USER=${GANTRY_REGISTRY_USER}" \
    --env "GANTRY_REGISTRY_USER_FILE=${GANTRY_REGISTRY_USER_FILE}" \
    --env "GANTRY_SERVICES_EXCLUDED=${GANTRY_SERVICES_EXCLUDED}" \
    --env "GANTRY_SERVICES_EXCLUDED_FILTERS=${GANTRY_SERVICES_EXCLUDED_FILTERS}" \
    --env "GANTRY_SERVICES_FILTERS=${GANTRY_SERVICES_FILTERS}" \
    --env "GANTRY_SERVICES_SELF=${GANTRY_SERVICES_SELF}" \
    --env "GANTRY_MANIFEST_CMD=${GANTRY_MANIFEST_CMD}" \
    --env "GANTRY_MANIFEST_NUM_WORKERS=${GANTRY_MANIFEST_NUM_WORKERS}" \
    --env "GANTRY_MANIFEST_OPTIONS=${GANTRY_MANIFEST_OPTIONS}" \
    --env "GANTRY_ROLLBACK_ON_FAILURE=${GANTRY_ROLLBACK_ON_FAILURE}" \
    --env "GANTRY_ROLLBACK_OPTIONS=${GANTRY_ROLLBACK_OPTIONS}" \
    --env "GANTRY_UPDATE_JOBS=${GANTRY_UPDATE_JOBS}" \
    --env "GANTRY_UPDATE_NUM_WORKERS=${GANTRY_UPDATE_NUM_WORKERS}" \
    --env "GANTRY_UPDATE_OPTIONS=${GANTRY_UPDATE_OPTIONS}" \
    --env "GANTRY_UPDATE_TIMEOUT_SECONDS=${GANTRY_UPDATE_TIMEOUT_SECONDS}" \
    --env "GANTRY_CLEANUP_IMAGES=${GANTRY_CLEANUP_IMAGES}" \
    --env "GANTRY_CLEANUP_IMAGES_OPTIONS=${GANTRY_CLEANUP_IMAGES_OPTIONS}" \
    --env "GANTRY_CLEANUP_IMAGES_REMOVER=${GANTRY_CLEANUP_IMAGES_REMOVER}" \
    --env "GANTRY_IMAGES_TO_REMOVE=${GANTRY_IMAGES_TO_REMOVE}" \
    --env "GANTRY_NOTIFICATION_APPRISE_URL=${GANTRY_NOTIFICATION_APPRISE_URL}" \
    --env "GANTRY_NOTIFICATION_CONDITION=${GANTRY_NOTIFICATION_CONDITION}" \
    --env "GANTRY_NOTIFICATION_TITLE=${GANTRY_NOTIFICATION_TITLE}" \
    --env "TZ=${TZ}" \
    "${SUT_REPO_TAG}" \
    "${STACK}" 2>&1); then
    echo "Failed to create service ${SERVICE_NAME}: ${CMD_OUTPUT}" >&2
    RETURN_VALUE=1
  fi
  docker service logs --raw "${SERVICE_NAME}"
  if ! CMD_OUTPUT=$(docker service rm "${SERVICE_NAME}" 2>&1); then
    echo "Failed to remove service ${SERVICE_NAME}: ${CMD_OUTPUT}" >&2
    RETURN_VALUE=1
  fi
  return "${RETURN_VALUE}"
}

run_gantry() {
  local STACK="${1}"
  if _run_gantry_container "${STACK}"; then
    return 0
  fi
  local ENTRYPOINT=
  ENTRYPOINT=$(_get_entrypoint) || return 1
  ${ENTRYPOINT} "${STACK}"
}

set +a
