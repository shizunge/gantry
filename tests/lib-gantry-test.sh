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

test_start() {
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
  export GANTRY_MANIFEST_INSPECT=
  export GANTRY_MANIFEST_OPTIONS=
  export GANTRY_MANIFEST_USE_MANIFEST_CMD=
  export GANTRY_ROLLBACK_ON_FAILURE=
  export GANTRY_ROLLBACK_OPTIONS=
  export GANTRY_UPDATE_JOBS=
  export GANTRY_UPDATE_OPTIONS=
  export GANTRY_UPDATE_TIMEOUT_SECONDS=
  export GANTRY_CLEANUP_IMAGES=
  export GANTRY_NOTIFICATION_APPRISE_URL=
  export GANTRY_NOTIFICATION_TITLE=
}

test_end() {
  local TEST_NAME=${1}
  echo "=============================="
  echo "== ${TEST_NAME} Done"
}

expect_message() {
  TEXT=${1}
  MESSAGE=${2}
  if ! ACTUAL_MSG=$(echo "${TEXT}" | grep -P "${MESSAGE}"); then
    echo "ERROR failed to find expected message \"${MESSAGE}\"."
    exit 1
  fi
  echo "EXPECTED found message: ${ACTUAL_MSG}"
}

expect_no_message() {
  TEXT=${1}
  MESSAGE=${2}
  if ACTUAL_MSG=$(echo "${TEXT}" | grep -P "${MESSAGE}"); then
    echo "ERROR Message \"${ACTUAL_MSG}\" should not present."
    exit 1
  fi
  echo "EXPECTED found no message matches: ${MESSAGE}"
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
  docker build --quiet --tag "${IMAGE_WITH_TAG}" --file "${FILE}" .
  echo -n "Pushing ${IMAGE_WITH_TAG} "
  docker push --quiet "${IMAGE_WITH_TAG}"
  rm "${FILE}"
}

wait_zero_running_tasks() {
  local SERVICE_NAME="${1}"
  local NUM_RUNS=1
  local REPLICAS=
  echo "Wait until ${SERVICE_NAME} has zero running tasks."
  while [ "${NUM_RUNS}" -ne 0 ]; do
    if ! REPLICAS=$(docker service ls --filter "name=${SERVICE_NAME}" --format '{{.Replicas}}' 2>&1); then
      echo "Failed to obtain task states of service ${SERVICE_NAME}: ${REPLICAS}" >&2
      exit 1
    fi
    # https://docs.docker.com/engine/reference/commandline/service_ls/#examples
    # The REPLICAS is like "5/5" or "1/1 (3/5 completed)"
    # Get the number before the first "/".
    NUM_RUNS=$(echo "${REPLICAS}" | cut -d '/' -f 1)
  done
}

location_constraints() {
  local NODE_NAME="${GLOBAL_HOSTNAME:-""}"
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
  echo -n "Creating ${SERVICE_NAME} "
  # SC2046 (warning): Quote this to prevent word splitting.
  # shellcheck disable=SC2046
  docker service create --quiet --name "${SERVICE_NAME}" $(location_constraints) --mode=replicated "${IMAGE_WITH_TAG}"
}

start_global_service() {
  local SERVICE_NAME="${1}"
  local IMAGE_WITH_TAG="${2}"
  echo -n "Creating ${SERVICE_NAME} "
  # SC2046 (warning): Quote this to prevent word splitting.
  # shellcheck disable=SC2046
  docker service create --quiet --name "${SERVICE_NAME}" $(location_constraints) --mode=global "${IMAGE_WITH_TAG}"
}

start_replicated_job() {
  local SERVICE_NAME="${1}"
  local IMAGE_WITH_TAG="${2}"
  echo -n "Creating ${SERVICE_NAME} "
  # SC2046 (warning): Quote this to prevent word splitting.
  # shellcheck disable=SC2046
  docker service create --quiet --name "${SERVICE_NAME}" $(location_constraints) --mode=replicated-job --detach=true "${IMAGE_WITH_TAG}"
  # wait until the job is running
  wait_service_state "${SERVICE_NAME}" "Running"
}

stop_service() {
  local SERVICE_NAME="${1}"
  echo -n "Removing ${SERVICE_NAME} "
  docker service rm "${SERVICE_NAME}"
}
