#!/bin/bash
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

initialize_test() {
  local TEST_NAME=${1}
  echo "=============================="
  echo "== ${TEST_NAME} started"
  echo "=============================="
  export GANTRY_LOG_LEVEL="DEBUG"
  export GANTRY_NODE_NAME=
  export GANTRY_SLEEP_SECONDS=
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
  export GANTRY_SERVICES_SELF=
  export GANTRY_MANIFEST_CMD=
  export GANTRY_MANIFEST_OPTIONS=
  export GANTRY_ROLLBACK_ON_FAILURE=
  export GANTRY_ROLLBACK_OPTIONS=
  export GANTRY_UPDATE_JOBS=
  export GANTRY_UPDATE_OPTIONS=
  export GANTRY_UPDATE_TIMEOUT_SECONDS=
  export GANTRY_CLEANUP_IMAGES=
  export GANTRY_NOTIFICATION_APPRISE_URL=
  export GANTRY_NOTIFICATION_TITLE=
  GLOBAL_THIS_TEST_ERRORS=0
}

finalize_test() {
  local TEST_NAME=${1}
  local TSET_STATUS="OK"
  local RETURN_VALUE=0
  if [ "${GLOBAL_THIS_TEST_ERRORS}" -ne 0 ]; then
    TSET_STATUS="${GLOBAL_THIS_TEST_ERRORS} ERRORS"
    RETURN_VALUE=1
  fi
  echo "=============================="
  echo "== ${TEST_NAME} ${TSET_STATUS}"
  return "${RETURN_VALUE}"
}

# finish_all_tests should return non zero when there are errors.
finish_all_tests() {
  local NUM_ERRORS="${GLOBAL_ALL_ERRORS:-0}"
  if [ "${NUM_ERRORS}" -ne 0 ]; then
    echo "=============================="
    echo "== There are total ${NUM_ERRORS} error(s)."
    return 1
  fi
  echo "=============================="
  echo "== All tests pass."
}

handle_failure() {
  local MESSAGE="${1}"
  echo "${MESSAGE}" >&2
  GLOBAL_THIS_TEST_ERRORS=$((GLOBAL_THIS_TEST_ERRORS+1))
  GLOBAL_ALL_ERRORS=$((GLOBAL_ALL_ERRORS+1))
}

expect_message() {
  TEXT=${1}
  MESSAGE=${2}
  if ! ACTUAL_MSG=$(echo "${TEXT}" | grep -P "${MESSAGE}"); then
    handle_failure "ERROR failed to find expected message \"${MESSAGE}\"."
    return 1
  fi
  echo "EXPECTED found message: ${ACTUAL_MSG}"
}

expect_no_message() {
  TEXT=${1}
  MESSAGE=${2}
  if ACTUAL_MSG=$(echo "${TEXT}" | grep -P "${MESSAGE}"); then
    handle_failure "ERROR Message \"${ACTUAL_MSG}\" should not present."
    return 1
  fi
  echo "EXPECTED found no message matches: ${MESSAGE}"
}

read_service_label() {
  local SERVICE_NAME="${1}"
  local LABEL="${2}"
  docker service inspect -f "{{index .Spec.Labels \"${LABEL}\"}}" "${SERVICE_NAME}"
}

build_and_push_test_image() {
  local IMAGE_WITH_TAG="${1}"
  local SLEEP_SECONDS="${2}"
  local SLEEP_CMD="sleep ${SLEEP_SECONDS}"
  if [ -z "${SLEEP_SECONDS}" ]; then
    SLEEP_CMD="tail -f /dev/null"
  fi
  local FILE=
  FILE=$(mktemp)
  echo "FROM alpinelinux/docker-cli:latest" > "${FILE}"
  echo "ENTRYPOINT [\"sh\", \"-c\", \"echo $(date -Iseconds); ${SLEEP_CMD};\"]" >> "${FILE}"
  echo -n "Building ${IMAGE_WITH_TAG} "
  timeout 300 docker build --quiet --tag "${IMAGE_WITH_TAG}" --file "${FILE}" .
  echo -n "Pushing ${IMAGE_WITH_TAG} "
  docker push --quiet "${IMAGE_WITH_TAG}"
  rm "${FILE}"
}

prune_local_test_image() {
  local IMAGE_WITH_TAG="${1}"
  echo "Removing image ${IMAGE_WITH_TAG} "
  docker image rm "${IMAGE_WITH_TAG}"
}

wait_zero_running_tasks() {
  local SERVICE_NAME="${1}"
  local TIMEOUT_SECONDS="${2}"
  local NUM_RUNS=1
  local REPLICAS=
  local SECONDS=0
  echo "Wait until ${SERVICE_NAME} has zero running tasks."
  while [ "${NUM_RUNS}" -ne 0 ]; do
    if [ -n "${TIMEOUT_SECONDS}" ] && [ "${SECONDS}" -ge "${TIMEOUT_SECONDS}" ]; then
      handle_failure "Services ${SERVICE_NAME} does not stop after ${TIMEOUT_SECONDS} seconds."
      return 1
    fi
    if ! REPLICAS=$(docker service ls --filter "name=${SERVICE_NAME}" --format '{{.Replicas}}' 2>&1); then
      handle_failure "Failed to obtain task states of service ${SERVICE_NAME}: ${REPLICAS}"
      return 1
    fi
    # https://docs.docker.com/engine/reference/commandline/service_ls/#examples
    # The REPLICAS is like "5/5" or "1/1 (3/5 completed)"
    # Get the number before the first "/".
    NUM_RUNS=$(echo "${REPLICAS}" | cut -d '/' -f 1)
    sleep 1
    SECONDS=$((SECONDS+1))
  done
}

hostname() {
  if [ -z "${GLOBAL_HOSTNAME}" ]; then
    local SELF_ID=
    SELF_ID=$(docker node inspect self --format "{{.Description.Hostname}}" 2>/dev/null);
    if [ -n "${SELF_ID}" ]; then
      GLOBAL_HOSTNAME="${SELF_ID}"
    fi
  fi
  echo "${GLOBAL_HOSTNAME}"
}

location_constraints() {
  local NODE_NAME=
  NODE_NAME="$(hostname)"
  [ -z "${NODE_NAME}" ] && echo "" && return 0
  local ARGS="--constraint node.hostname==${NODE_NAME}";
  echo "${ARGS}"
}

wait_service_state() {
  local SERVICE_NAME="${1}"
  local STATE="${2}"
  while ! docker service ps --format "{{.CurrentState}}" "${SERVICE_NAME}" | grep -q "${STATE}"; do
    sleep 1
  done
}

start_replicated_service() {
  local SERVICE_NAME="${1}"
  local IMAGE_WITH_TAG="${2}"
  echo -n "Creating service ${SERVICE_NAME} in replicated mode "
  # SC2046 (warning): Quote this to prevent word splitting.
  # shellcheck disable=SC2046
  timeout 300 docker service create --quiet \
    --name "${SERVICE_NAME}" \
    --restart-condition "on-failure" \
    --restart-max-attempts 5 \
    $(location_constraints) \
    --mode=replicated \
    "${IMAGE_WITH_TAG}"
}

start_global_service() {
  local SERVICE_NAME="${1}"
  local IMAGE_WITH_TAG="${2}"
  echo -n "Creating service ${SERVICE_NAME} in global mode "
  # SC2046 (warning): Quote this to prevent word splitting.
  # shellcheck disable=SC2046
  timeout 300 docker service create --quiet \
    --name "${SERVICE_NAME}" \
    --restart-condition "on-failure" \
    --restart-max-attempts 5 \
    $(location_constraints) \
    --mode=global \
    "${IMAGE_WITH_TAG}"
}

start_replicated_job() {
  local SERVICE_NAME="${1}"
  local IMAGE_WITH_TAG="${2}"
  echo -n "Creating service ${SERVICE_NAME} in replicated job mode "
  # SC2046 (warning): Quote this to prevent word splitting.
  # shellcheck disable=SC2046
  timeout 300 docker service create --quiet \
    --name "${SERVICE_NAME}" \
    --restart-condition "on-failure" \
    --restart-max-attempts 5 \
    $(location_constraints) \
    --mode=replicated-job --detach=true \
    "${IMAGE_WITH_TAG}"
  # wait until the job is running
  wait_service_state "${SERVICE_NAME}" "Running"
}

stop_service() {
  local SERVICE_NAME="${1}"
  echo -n "Removing ${SERVICE_NAME} "
  docker service rm "${SERVICE_NAME}"
}

get_script_dir() {
  if [ -z "${BASH_SOURCE[0]}" ]; then
    echo "BASH_SOURCE is empty." >&2
    echo "."
    return 1
  fi
  local SCRIPT_DIR=
  SCRIPT_DIR="$( cd "$(dirname "${BASH_SOURCE[0]}")" || return 1; pwd -P )"
  echo "${SCRIPT_DIR}"
}

get_entrypoint() {
  if [ -n "${GLOBAL_ENTRYPOINT}" ]; then
    echo "${GLOBAL_ENTRYPOINT}"
    return 0
  fi
  local SCRIPT_DIR=
  SCRIPT_DIR="$(get_script_dir)" || return 1
  GLOBAL_ENTRYPOINT="${SCRIPT_DIR}/../src/entrypoint.sh"
  echo "source ${GLOBAL_ENTRYPOINT}"
}

run_gantry_container() {
  local CONTAINER_REPO_TAG="${GANTRY_TEST_CONTAINER_REPO_TAG:-""}"
  if [ -z "${CONTAINER_REPO_TAG}" ]; then
    return 1
  fi
  local STACK="${1}"
  local SERVICE_NAME="gantry-test"
  local CMD_OUTPUT=
  docker service rm "${SERVICE_NAME}" >/dev/null 2>&1;
  if ! CMD_OUTPUT=$(docker service create --quiet --name "${SERVICE_NAME}" \
    --mode replicated-job \
    --constraint "node.role==manager" \
    --mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock \
    --env "GANTRY_LOG_LEVEL=${GANTRY_LOG_LEVEL}" \
    --env "GANTRY_NODE_NAME=${GANTRY_NODE_NAME}" \
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
    --env "GANTRY_MANIFEST_OPTIONS=${GANTRY_MANIFEST_OPTIONS}" \
    --env "GANTRY_ROLLBACK_ON_FAILURE=${GANTRY_ROLLBACK_ON_FAILURE}" \
    --env "GANTRY_ROLLBACK_OPTIONS=${GANTRY_ROLLBACK_OPTIONS}" \
    --env "GANTRY_UPDATE_JOBS=${GANTRY_UPDATE_JOBS}" \
    --env "GANTRY_UPDATE_OPTIONS=${GANTRY_UPDATE_OPTIONS}" \
    --env "GANTRY_UPDATE_TIMEOUT_SECONDS=${GANTRY_UPDATE_TIMEOUT_SECONDS}" \
    --env "GANTRY_CLEANUP_IMAGES=${GANTRY_CLEANUP_IMAGES}" \
    --env "GANTRY_NOTIFICATION_APPRISE_URL=${GANTRY_NOTIFICATION_APPRISE_URL}" \
    --env "GANTRY_NOTIFICATION_TITLE=${GANTRY_NOTIFICATION_TITLE}" \
    "${CONTAINER_REPO_TAG}" \
    "${STACK}" 2>&1); then
    echo "Failed to create service ${SERVICE_NAME}: ${CMD_OUTPUT}" >&2
  fi
  docker service logs --raw "${SERVICE_NAME}"
  if ! CMD_OUTPUT=$(docker service rm "${SERVICE_NAME}" 2>&1); then
    echo "Failed to remove service ${SERVICE_NAME}: ${CMD_OUTPUT}" >&2
  fi
}

run_gantry() {
  local STACK="${1}"
  if run_gantry_container "${STACK}"; then
    return 0
  fi
  local ENTRYPOINT=
  ENTRYPOINT=$(get_entrypoint) || return 1
  ${ENTRYPOINT} "${STACK}"
}
