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
# START_WITHOUT_A_SQUARE_BRACKET ignores color codes. Use test_log not to trigger this check.
export START_WITHOUT_A_SQUARE_BRACKET="^(?!(?:\x1b\[[0-9;]*[mG])?\[)"
export GANTRY_AUTH_CONFIG_LABEL="gantry.auth.config"
export MUST_BE_A_NUMBER="must be a number"
export LOGGED_INTO_REGISTRY="Logged into registry"
export DEFAULT_CONFIGURATION="default configuration"
export FAILED_TO_LOGIN_TO_REGISTRY="Failed to login to registry"
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
export CONFIG_IS_NOT_A_DIRECTORY="is not a directory that contains Docker configuration files"
export THERE_ARE_NUM_CONFIGURATIONS="There are [0-9]+ configuration\(s\)"
export USER_LOGGED_INTO_DEFAULT="User logged in using the default Docker configuration"
export ADDING_OPTIONS="Adding options"
export ADDING_OPTIONS_WITH_REGISTRY_AUTH="Adding options.*--with-registry-auth"
export SET_TIMEOUT_TO="Set timeout to"
export RETURN_VALUE_INDICATES_TIMEOUT="The return value 124 indicates the job timed out."
export THERE_ARE_ADDITIONAL_MESSAGES="There are additional messages from updating"
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
export DONE_REMOVING_IMAGES="Done removing images"
export SCHEDULE_NEXT_UPDATE_AT="Schedule next update at"
export SLEEP_SECONDS_BEFORE_NEXT_UPDATE="Sleep [0-9]+ seconds before next update"

export TEST_IMAGE_REMOVER="ghcr.io/shizunge/gantry-development"
export TEST_SERVICE_IMAGE="alpine:latest"

test_log() {
  echo "${GANTRY_LOG_LEVEL}" | grep -q -i "^NONE$"  && return 0;
  [ -n "${GANTRY_IMAGES_TO_REMOVE}" ] && echo "${*}" >&2 && return 0;
  echo "[$(date -Iseconds)] Test: ${*}" >&2
}

display_output() {
  echo "${display_output:-""}"
}

check_login_input() {
  local REGISTRY="${1}"
  local USERNAME="${2}"
  local PASSWORD="${3}"
  if [ -z "${REGISTRY}" ] || [ -z "${USERNAME}" ] || [ -z "${PASSWORD}" ]; then
    echo "No REGISTRY, USERNAME or PASSWORD provided." >&2
    return 1
  fi
  return 0
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
  start_multiple_replicated_services "${SERVICE_NAME}" "${IMAGE_WITH_TAG}" 0 "${MAX_SERVICES_NUM}"
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
  local EXIT_SECONDS="${5}"
  initialize_test "${TEST_NAME}"
  # The task will finish in ${TASK_SECONDS} seconds, when ${TASK_SECONDS} is not empty
  build_and_push_test_image "${IMAGE_WITH_TAG}" "${TASK_SECONDS}" "${EXIT_SECONDS}"
  _start_replicated_job "${SERVICE_NAME}" "${IMAGE_WITH_TAG}" "${TASK_SECONDS}" "${EXIT_SECONDS}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
}

common_setup_timeout() {
  local TEST_NAME="${1}"
  local IMAGE_WITH_TAG="${2}"
  local SERVICE_NAME="${3}"
  local TIMEOUT="${4}"
  local TIMEOUT_PLUS_ONE=$((TIMEOUT+1))
  local TIMEOUT_PLUS_TWO=$((TIMEOUT+2))
  initialize_test "${TEST_NAME}"
  # -1 thus the task runs forever.
  # exit will take longer than the timeout.
  build_and_push_test_image "${IMAGE_WITH_TAG}" "-1" "${TIMEOUT_PLUS_TWO}"
  # Timeout set by "service create" should be smaller than the exit time above.
  start_replicated_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}" "${TIMEOUT_PLUS_ONE}"
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
  stop_multiple_services "${SERVICE_NAME}" 0 "${MAX_SERVICES_NUM}"
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

_get_initial_port() {
  # local BASE="${1}"
  local PID=$$
  local RANDOM_NUM=$(( PID % 1000 ))
  echo $(( 55000 + RANDOM_NUM ))
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

_get_docker_config_file() {
  local REGISTRY="${1:?}"
  REGISTRY=$(echo "${REGISTRY}" | tr ':' '-')
  echo "/tmp/TEST_DOCKER_CONFIG-${REGISTRY}"
}

_get_docker_config_argument() {
  local IMAGE_WITH_TAG="${1:?}"
  local REGISTRY=
  REGISTRY=$(echo "${IMAGE_WITH_TAG}" | cut -d '/' -f 1)
  local CONFIG=
  CONFIG=$(_get_docker_config_file "${REGISTRY}") || return 1
  [ -d "${CONFIG}" ] && echo "--config ${CONFIG}"
}

_login_test_registry() {
  local ENFORCE_LOGIN="${1}"
  local REGISTRY="${2}"
  local USERNAME="${3}"
  local PASSWORD="${4}"
  if ! _enforce_login_enabled "${ENFORCE_LOGIN}"; then
    USERNAME="username"
    PASSWORD="password"
  fi
  echo "Logging in ${REGISTRY}."
  local CONFIG=
  CONFIG=$(_get_docker_config_file "${REGISTRY}") || return 1
  echo "${PASSWORD}" | docker --config "${CONFIG}" login --username="${USERNAME}" --password-stdin "${REGISTRY}" 2>&1
}

_logout_test_registry() {
  local ENFORCE_LOGIN="${1}"
  local REGISTRY="${2}"
  local CONFIG=
  CONFIG=$(_get_docker_config_file "${REGISTRY}") || return 1
  if _enforce_login_enabled "${ENFORCE_LOGIN}"; then
    echo "Logging out ${REGISTRY}."
    docker --config "${CONFIG}" logout
  fi
  [ -d "${CONFIG}" ] && rm -r "${CONFIG}"
}

_get_test_registry_file() {
  local SUITE_NAME="${1:?}"
  SUITE_NAME=$(echo "${SUITE_NAME}" | tr ' ' '-')
  echo "/tmp/TEST_REGISTRY-${SUITE_NAME}"
}

_remove_test_registry_file() {
  local SUITE_NAME="${1:?}"
  local REGISTRY_FILE=
  REGISTRY_FILE=$(_get_test_registry_file "${SUITE_NAME}") || return 1
  rm "${REGISTRY_FILE}"
}

_store_test_registry() {
  local SUITE_NAME="${1:?}"
  local TEST_REGISTRY="${2}"
  local REGISTRY_FILE=
  if ! REGISTRY_FILE=$(_get_test_registry_file "${SUITE_NAME}" 2>&1); then
    echo "_store_test_registry error: ${REGISTRY_FILE}" >&2
    return 1
  fi
  echo "Suite \"${SUITE_NAME}\" uses registry ${TEST_REGISTRY}."
  echo "${TEST_REGISTRY}" > "${REGISTRY_FILE}"
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
  local ENFORCE_LOGIN="${2}"
  local TIMEOUT_SECONDS="${3:-1}"
  SUITE_NAME=$(echo "${SUITE_NAME}" | tr ' ' '-')
  local SUITE_NAME_LENGTH="${#SUITE_NAME}"
  local REGISTRY_SERVICE_NAME="gantry-test-registry-${SUITE_NAME}"
  local REGISTRY_BASE="localhost"
  local REGISTRY_PORT=
  REGISTRY_PORT=$(_get_initial_port "${SUITE_NAME_LENGTH}")
  local TEST_REGISTRY="${REGISTRY_BASE}:${REGISTRY_PORT}"
  export TEST_USERNAME="gantry"
  export TEST_PASSWORD="gantry"
  local REGISTRY_IMAGE="docker.io/registry"
  local TRIES=0
  local MAX_RETRIES=50
  local PORT_LIMIT=500
  pull_image_if_not_exist "${REGISTRY_IMAGE}"
  while true; do
    if ! REGISTRY_PORT=$(_next_available_port "${REGISTRY_PORT}" "${PORT_LIMIT}" 2>&1); then
      echo "_start_registry _next_available_port error: ${REGISTRY_PORT}" >&2
      return 1
    fi
    if [ -z "${REGISTRY_PORT}" ]; then
      echo "_start_registry _next_available_port error: REGISTRY_PORT is empty." >&2
      return 1
    fi
    docker container stop "${REGISTRY_SERVICE_NAME}" 1>/dev/null 2>&1;
    docker container rm -f "${REGISTRY_SERVICE_NAME}" 1>/dev/null 2>&1;
    TEST_REGISTRY="${REGISTRY_BASE}:${REGISTRY_PORT}"
    echo "Suite \"${SUITE_NAME}\" starts registry ${TEST_REGISTRY} "
    local CID=
    # SC2046 (warning): Quote this to prevent word splitting.
    # SC2086 (info): Double quote to prevent globbing and word splitting.
    # shellcheck disable=SC2046,SC2086
    if CID=$(docker container run -d --rm \
      --name "${REGISTRY_SERVICE_NAME}" \
      --network=host \
      -e "REGISTRY_HTTP_ADDR=${TEST_REGISTRY}" \
      -e "REGISTRY_HTTP_HOST=http://${TEST_REGISTRY}" \
      --stop-timeout "${TIMEOUT_SECONDS}" \
      $(_add_htpasswd "${ENFORCE_LOGIN}" "${TEST_USERNAME}" "${TEST_PASSWORD}") \
      "${REGISTRY_IMAGE}" 2>&1); then
      local STATUS=
      while [ "${STATUS}" != "running" ]; do
        STATUS=$(docker container inspect "${CID}" --format '{{.State.Status}}')
      done
      break;
    fi
    if [ "${TRIES}" -ge "${MAX_RETRIES}" ]; then
      echo "_start_registry Reach MAX_RETRIES ${MAX_RETRIES}" >&2
      return 1
    fi
    REGISTRY_PORT=$((REGISTRY_PORT+1))
    TRIES=$((TRIES+1))
    sleep 1
  done
  _store_test_registry "${SUITE_NAME}" "${TEST_REGISTRY}" || return 1;
  TRIES=0
  while ! _login_test_registry "${ENFORCE_LOGIN}" "${TEST_REGISTRY}" "${TEST_USERNAME}" "${TEST_PASSWORD}"; do
    if [ "${TRIES}" -ge "${MAX_RETRIES}" ]; then
      echo "_login_test_registry Reach MAX_RETRIES ${MAX_RETRIES}" >&2
      return 1
    fi
    TRIES=$((TRIES+1))
    sleep 1
  done
}

_stop_registry() {
  local SUITE_NAME="${1:?}"
  local ENFORCE_LOGIN="${2}"
  SUITE_NAME=$(echo "${SUITE_NAME}" | tr ' ' '-')
  local REGISTRY_SERVICE_NAME="gantry-test-registry-${SUITE_NAME}"
  local REGISTRY=
  REGISTRY=$(load_test_registry "${SUITE_NAME}") || return 1
  echo "Removing registry ${REGISTRY} "
  docker container stop "${REGISTRY_SERVICE_NAME}" 1>/dev/null 2>&1;
  docker container rm -f "${REGISTRY_SERVICE_NAME}" 1>/dev/null 2>&1;
  _logout_test_registry "${ENFORCE_LOGIN}" "${REGISTRY}" || return 1
  _remove_test_registry_file "${SUITE_NAME}" || return 1
  return 0
}

initialize_all_tests() {
  local SUITE_NAME="${1:-"gantry"}"
  local ENFORCE_LOGIN="${2}"
  SUITE_NAME=$(echo "${SUITE_NAME}" | tr ' ' '-')
  local SCRIPT_DIR=
  SCRIPT_DIR="$(_get_script_dir)" || return 1
  source "${SCRIPT_DIR}/../src/lib-common.sh"
  echo "=============================="
  echo "== Starting suite ${SUITE_NAME}"
  echo "=============================="
  _init_swarm
  _start_registry "${SUITE_NAME}" "${ENFORCE_LOGIN}"
  pull_image_if_not_exist "${TEST_IMAGE_REMOVER}"
}

# finish_all_tests should return non zero when there are errors.
finish_all_tests() {
  local SUITE_NAME="${1:-"gantry"}"
  local ENFORCE_LOGIN="${2}"
  SUITE_NAME=$(echo "${SUITE_NAME}" | tr ' ' '-')
  _stop_registry "${SUITE_NAME}" "${ENFORCE_LOGIN}"
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
  export DOCKER_CONFIG=
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
  export GANTRY_SERVICES_FILTERS=
  if [ -n "${SERVICE_NAME}" ]; then
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
  export GANTRY_CLEANUP_IMAGES_REMOVER="${TEST_IMAGE_REMOVER}"
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
  if ! ACTUAL_MSG=$(echo -e "${TEXT}" | grep -Po "${MESSAGE}"); then
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
  if ACTUAL_MSG=$(echo -e "${TEXT}" | grep -Po "${MESSAGE}"); then
    _handle_failure "The following message should not present: \"${ACTUAL_MSG}\""
    return 1
  fi
  echo -e "${GREEN}EXPECTED${NO_COLOR} found no message matches: ${MESSAGE}"
}

unique_id() {
  # Try to generate a unique id.
  # To reduce the possibility that tests run in parallel on the same machine affect each other.
  local PID="$$"
  local TIME_STR=
  TIME_STR=$(date +%s)
  TIME_STR=$((TIME_STR % 10000))
  local RANDOM_STR=
  # repository name must be lowercase
  RANDOM_STR=$(head /dev/urandom | LANG=C tr -dc 'a-z0-9' | head -c 8)
  echo "${PID}-${TIME_STR}-${RANDOM_STR}"
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
  local EXIT_CMD="true;"
  if [ -n "${EXIT_SECONDS}" ] && [ "${EXIT_SECONDS}" -gt "0" ]; then
    EXIT_CMD="sleep ${EXIT_SECONDS};"
  fi
  local FILE=
  FILE=$(mktemp)
  echo "FROM ${TEST_SERVICE_IMAGE}" > "${FILE}"
  echo "ENTRYPOINT [\"sh\", \"-c\", \"echo $(unique_id); trap \\\"${EXIT_CMD}\\\" HUP INT TERM; ${TASK_CMD}\"]" >> "${FILE}"
  pull_image_if_not_exist "${TEST_SERVICE_IMAGE}"
  echo "Building image ${IMAGE_WITH_TAG} from ${FILE}"
  timeout 120 docker build --quiet --tag "${IMAGE_WITH_TAG}" --file "${FILE}" .
  rm "${FILE}"
}

build_and_push_test_image() {
  local IMAGE_WITH_TAG="${1}"
  local TASK_SECONDS="${2}"
  local EXIT_SECONDS="${3}"
  build_test_image "${IMAGE_WITH_TAG}" "${TASK_SECONDS}" "${EXIT_SECONDS}"
  echo "Pushing image ${IMAGE_WITH_TAG}"
  # SC2046 (warning): Quote this to prevent word splitting.
  # shellcheck disable=SC2046
  docker $(_get_docker_config_argument "${IMAGE_WITH_TAG}") push --quiet "${IMAGE_WITH_TAG}"
}

prune_local_test_image() {
  local IMAGE_WITH_TAG="${1}"
  echo "Removing image ${IMAGE_WITH_TAG}"
  docker image rm "${IMAGE_WITH_TAG}" --force
}

docker_service_update() {
  docker service update --quiet "${@}" >/dev/null
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

pull_image_if_not_exist() {
  local IMAGE="${1}"
  if ! docker image inspect "${IMAGE}" > /dev/null 2>&1; then
    docker pull "${IMAGE}" > /dev/null
  fi
}

_enforce_login_enabled() {
  local ENFORCE_LOGIN="${1}"
  test "${ENFORCE_LOGIN}" == "ENFORCE_LOGIN"
}

_add_htpasswd() {
  local ENFORCE_LOGIN="${1}"
  local USER="${2}"
  local PASS="${3}"
  if ! _enforce_login_enabled "${ENFORCE_LOGIN}"; then
    return 0
  fi
  local HTTPD_IMAGE="httpd:2"
  # https://distribution.github.io/distribution/about/deploying/#native-basic-auth
  local PASSWD=
  PASSWD="$(mktemp)"
  pull_image_if_not_exist "${HTTPD_IMAGE}"
  docker_run --entrypoint htpasswd "${HTTPD_IMAGE}" -Bbn "${USER}" "${PASS}" > "${PASSWD}"
  echo "--mount type=bind,source=${PASSWD},target=${PASSWD} \
        -e REGISTRY_AUTH=htpasswd \
        -e REGISTRY_AUTH_HTPASSWD_REALM=RegistryRealm \
        -e REGISTRY_AUTH_HTPASSWD_PATH=${PASSWD} "
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

_correct_test_service_name() {
  local SERVICE_NAME="${1}"
  [ "${#SERVICE_NAME}" -gt 63 ] && SERVICE_NAME=${SERVICE_NAME:0:63}
  echo "${SERVICE_NAME}"
}

get_test_service_name() {
  local TEST_NAME="${1}"
  local TEST_NAME_SHORT="${TEST_NAME}"
  # Max length is 63. Leave some spaces for suffix
  [ "${#TEST_NAME}" -gt 30 ] && TEST_NAME_SHORT=${TEST_NAME:0-30}
  local SERVICE_NAME=
  SERVICE_NAME="g$(unique_id)-${TEST_NAME_SHORT}"
  SERVICE_NAME=$(echo "${SERVICE_NAME}" | tr '[:upper:]' '[:lower:]')
  SERVICE_NAME=$(echo "${SERVICE_NAME}" | tr '_' '-')
  echo "${SERVICE_NAME}"
}

start_replicated_service() {
  local SERVICE_NAME="${1}"
  local IMAGE_WITH_TAG="${2}"
  local TIMEOUT_SECONDS="${3:-1}"
  SERVICE_NAME=$(_correct_test_service_name "${SERVICE_NAME}")
  echo "Creating service ${SERVICE_NAME} in replicated mode "
  # During creation:
  # * Add --detach to reduce the test runtime.
  # For updating:
  # * Add --update-monitor=1s to save about 4s for each service update.
  # * Add --stop-grace-period=1s to save about 4s for each service update.
  # For rolling back:
  # * Add --rollback-monitor=1s: needs to exam the effect.
  # SC2046 (warning): Quote this to prevent word splitting.
  # shellcheck disable=SC2046
  timeout 120 docker $(_get_docker_config_argument "${IMAGE_WITH_TAG}") service create --quiet \
    --name "${SERVICE_NAME}" \
    --restart-condition "on-failure" \
    --restart-max-attempts 5 \
    --with-registry-auth \
    --update-monitor="${TIMEOUT_SECONDS}s" \
    --stop-grace-period="${TIMEOUT_SECONDS}s" \
    --rollback-monitor="${TIMEOUT_SECONDS}s" \
    $(_location_constraints) \
    --mode=replicated \
    --detach=true \
    "${IMAGE_WITH_TAG}"
  _wait_service_state "${SERVICE_NAME}" "Running"
}

start_multiple_replicated_services() {
  local SERVICE_NAME="${1}"
  local IMAGE_WITH_TAG="${2}"
  local START_NUM="${3}"
  local END_NUM="${4}"
  local NUM=
  local PIDS=
  for NUM in $(seq "${START_NUM}" "${END_NUM}"); do
    local SERVICE_NAME_NUM="${SERVICE_NAME}-${NUM}"
    start_replicated_service "${SERVICE_NAME_NUM}" "${IMAGE_WITH_TAG}" &
    PIDS="${!} ${PIDS}"
  done
  # SC2086 (info): Double quote to prevent globbing and word splitting.
  # shellcheck disable=SC2086
  wait ${PIDS}
}

start_global_service() {
  local SERVICE_NAME="${1}"
  local IMAGE_WITH_TAG="${2}"
  local TIMEOUT_SECONDS="${3:-1}"
  SERVICE_NAME=$(_correct_test_service_name "${SERVICE_NAME}")
  echo "Creating service ${SERVICE_NAME} in global mode "
  # Do not add --detach, because we want to wait for the job finishes.
  # SC2046 (warning): Quote this to prevent word splitting.
  # shellcheck disable=SC2046
  timeout 120 docker $(_get_docker_config_argument "${IMAGE_WITH_TAG}") service create --quiet \
    --name "${SERVICE_NAME}" \
    --restart-condition "on-failure" \
    --restart-max-attempts 5 \
    --with-registry-auth \
    --update-monitor="${TIMEOUT_SECONDS}s" \
    --stop-grace-period="${TIMEOUT_SECONDS}s" \
    --rollback-monitor="${TIMEOUT_SECONDS}s" \
    $(_location_constraints) \
    --mode=global \
    "${IMAGE_WITH_TAG}"
}

_start_replicated_job() {
  local SERVICE_NAME="${1}"
  local IMAGE_WITH_TAG="${2}"
  local TASK_SECONDS="${3:-1}"
  local EXIT_SECONDS="${4:-1}"
  SERVICE_NAME=$(_correct_test_service_name "${SERVICE_NAME}")
  echo "Creating service ${SERVICE_NAME} in replicated job mode "
  # Always add --detach=true, do not wait for the job finishes.
  # SC2046 (warning): Quote this to prevent word splitting.
  # shellcheck disable=SC2046
  timeout 120 docker $(_get_docker_config_argument "${IMAGE_WITH_TAG}") service create --quiet \
    --name "${SERVICE_NAME}" \
    --restart-condition "on-failure" \
    --restart-max-attempts 5 \
    --with-registry-auth \
    --stop-grace-period="${EXIT_SECONDS}s" \
    $(_location_constraints) \
    --mode=replicated-job \
    --detach=true \
    "${IMAGE_WITH_TAG}"
  # wait until the job is running
  _wait_service_state "${SERVICE_NAME}" "Running"
}

stop_service() {
  local SERVICE_NAME="${1}"
  echo "Removing service ${SERVICE_NAME}"
  docker service rm "${SERVICE_NAME}"
}

stop_multiple_services() {
  local SERVICE_NAME="${1}"
  local START_NUM="${2}"
  local END_NUM="${3}"
  local NUM=
  local PIDS=
  for NUM in $(seq "${START_NUM}" "${END_NUM}"); do
    local SERVICE_NAME_NUM="${SERVICE_NAME}-${NUM}"
    stop_service "${SERVICE_NAME_NUM}" &
    PIDS="${!} ${PIDS}"
  done
  # SC2086 (info): Double quote to prevent globbing and word splitting.
  # shellcheck disable=SC2086
  wait ${PIDS}
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
  local HOST_PATH="${2}"
  if [ -n "${HOST_PATH}" ] && [ -r "${HOST_PATH}" ]; then
    # Use the absolute path inside the container.
    local TARGET=
    TARGET=$(readlink -f "${HOST_PATH}")
    MOUNT_OPTIONS="${MOUNT_OPTIONS} --mount type=bind,source=${HOST_PATH},target=${TARGET}"
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
  MOUNT_OPTIONS=$(_add_file_to_mount_options "${MOUNT_OPTIONS}" "${DOCKER_CONFIG}")
  MOUNT_OPTIONS=$(_add_file_to_mount_options "${MOUNT_OPTIONS}" "${GANTRY_REGISTRY_CONFIG_FILE}")
  MOUNT_OPTIONS=$(_add_file_to_mount_options "${MOUNT_OPTIONS}" "${GANTRY_REGISTRY_CONFIGS_FILE}")
  MOUNT_OPTIONS=$(_add_file_to_mount_options "${MOUNT_OPTIONS}" "${GANTRY_REGISTRY_HOST_FILE}")
  MOUNT_OPTIONS=$(_add_file_to_mount_options "${MOUNT_OPTIONS}" "${GANTRY_REGISTRY_PASSWORD_FILE}")
  MOUNT_OPTIONS=$(_add_file_to_mount_options "${MOUNT_OPTIONS}" "${GANTRY_REGISTRY_USER_FILE}")
  test_log "Starting SUT service ${SERVICE_NAME} with image ${SUT_REPO_TAG}."
  local RETURN_VALUE=0
  local CMD_OUTPUT=
  # SC2086 (info): Double quote to prevent globbing and word splitting.
  # shellcheck disable=SC2086
  if ! CMD_OUTPUT=$(docker service create --name "${SERVICE_NAME}" \
    --mode replicated-job --restart-condition=none --network host \
    --constraint "node.role==manager" \
    --mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock \
    ${MOUNT_OPTIONS} \
    --env "DOCKER_CONFIG=${DOCKER_CONFIG}" \
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
