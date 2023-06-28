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
  GANTRY_LOG_LEVEL=
  GANTRY_NODE_NAME=
  GANTRY_SLEEP_SECONDS=
  GANTRY_REGISTRY_CONFIG=
  GANTRY_REGISTRY_CONFIG_FILE=
  GANTRY_REGISTRY_CONFIGS_FILE=
  GANTRY_REGISTRY_HOST=
  GANTRY_REGISTRY_HOST_FILE=
  GANTRY_REGISTRY_PASSWORD=
  GANTRY_REGISTRY_PASSWORD_FILE=
  GANTRY_REGISTRY_USER=
  GANTRY_REGISTRY_USER_FILE=
  GANTRY_SERVICES_EXCLUDED=
  GANTRY_SERVICES_EXCLUDED_FILTERS=
  GANTRY_SERVICES_FILTERS=
  GANTRY_SERVICES_SELF=
  GANTRY_MANIFEST_INSPECT=
  GANTRY_MANIFEST_OPTIONS=
  GANTRY_MANIFEST_USE_MANIFEST_CMD=
  GANTRY_ROLLBACK_ON_FAILURE=
  GANTRY_ROLLBACK_OPTIONS=
  GANTRY_UPDATE_JOBS=
  GANTRY_UPDATE_OPTIONS=
  GANTRY_UPDATE_TIMEOUT_SECONDS=
  GANTRY_CLEANUP_IMAGES=
  GANTRY_NOTIFICATION_APPRISE_URL=
  GANTRY_NOTIFICATION_TITLE=
}

test_end_no_error() {
  local TEST_NAME=${1}
  echo "=============================="
  echo "== ${TEST_NAME} no errors"
}

build_and_push_test_image() {
  local IMAGE_WITH_TAG="${1}"
  local FILE=
  FILE=$(mktemp)
  echo "FROM alpinelinux/docker-cli:latest" > "${FILE}"
  echo "ENTRYPOINT [\"sh\", \"-c\", \"\"echo $(date -Iseconds); tail -f /dev/null;\"\"]" >> "${FILE}"
  docker build --tag "${IMAGE_WITH_TAG}" --push --file "${FILE}" .
}

start_service() {
  local SERVICE_NAME="${1}"
  local IMAGE_WITH_TAG="${2}"
  echo -n "Creating: ${SERVICE_NAME} "
  docker service create --name "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
}

stop_service() {
  local SERVICE_NAME="${1}"
  echo -n "Removing: "
  docker service rm "${SERVICE_NAME}"
}
