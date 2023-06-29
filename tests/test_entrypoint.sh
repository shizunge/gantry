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

SKIP_UPDATING_SERVICE="Skip updating service in .*job mode"
NO_NEW_IMAGE="No new image"
NO_UPDATES="No updates"
UPDATED="UPDATED"
ROLLING_BACK="Rolling back"
FAILED_TO_ROLLBACK="Failed to roll back"
ROLLED_BACK="Rolled back"
NO_SERVICES_UPDATED="No services updated"
NO_IMAGES_TO_REMOVE="No images to remove"
NUM_SERVICES_UPDATED="[1-9] service\(s\) updated"
REMOVING_NUM_IMAGES="Removing [1-9] image\(s\)"
SKIP_REMOVING_IMAGES="Skip removing images"
REMOVED_IMAGE="Removed image"
FAILED_TO_REMOVE_IMAGE="Failed to remove image"

test_no_new_image() {
  local IMAGE_WITH_TAG="${1}"

  test_start "${FUNCNAME[0]}"
  local SERVICE_NAME STDOUT
  SERVICE_NAME="gantry-test-$(date +%s)"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"

  export GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  STDOUT=$(run_gantry "${FUNCNAME[0]}" 2>&1 | tee /dev/tty)

  expect_no_message "${STDOUT}" "${SKIP_UPDATING_SERVICE}.*${SERVICE_NAME}"
  expect_message    "${STDOUT}" "${SERVICE_NAME}.*${NO_NEW_IMAGE}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${UPDATED}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_UPDATES}"
  expect_no_message "${STDOUT}" "${ROLLING_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${ROLLED_BACK}.*${SERVICE_NAME}"
  expect_message    "${STDOUT}" "${NO_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NUM_SERVICES_UPDATED}"
  expect_message    "${STDOUT}" "${NO_IMAGES_TO_REMOVE}"
  expect_no_message "${STDOUT}" "${REMOVING_NUM_IMAGES}"
  expect_no_message "${STDOUT}" "${SKIP_REMOVING_IMAGES}"
  expect_no_message "${STDOUT}" "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
  expect_no_message "${STDOUT}" "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"

  stop_service "${SERVICE_NAME}"
  test_end "${FUNCNAME[0]}"
  return 0
}

test_new_image() {
  local IMAGE_WITH_TAG="${1}"

  test_start "${FUNCNAME[0]}"
  local SERVICE_NAME STDOUT
  SERVICE_NAME="gantry-test-$(date +%s)"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"

  export GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  STDOUT=$(run_gantry "${FUNCNAME[0]}" 2>&1 | tee /dev/tty)

  expect_no_message "${STDOUT}" "${SKIP_UPDATING_SERVICE}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_NEW_IMAGE}"
  expect_message    "${STDOUT}" "${SERVICE_NAME}.*${UPDATED}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_UPDATES}"
  expect_no_message "${STDOUT}" "${ROLLING_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${ROLLED_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${NO_SERVICES_UPDATED}"
  expect_message    "${STDOUT}" "${NUM_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NO_IMAGES_TO_REMOVE}"
  expect_message    "${STDOUT}" "${REMOVING_NUM_IMAGES}"
  expect_no_message "${STDOUT}" "${SKIP_REMOVING_IMAGES}"
  expect_message    "${STDOUT}" "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
  expect_no_message "${STDOUT}" "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"

  stop_service "${SERVICE_NAME}"
  test_end "${FUNCNAME[0]}"
  return 0
}

test_login_config() {
  # It would be difficult to test updating failure due to authorization errors.
  # We may need to setup a private registry to test that.
  # Here are just a simple login test.
  local IMAGE_WITH_TAG="${1}"
  local REGISTRY="${2}"
  local USER="${3}"
  local PASS="${4}"
  local LABEL="gantry.auth.config"
  local CONFIG=
  CONFIG="C$(date +%s)"
  if [ -z "${USER}" ] || [ -z "${PASS}" ]; then
    echo "Skip ${FUNCNAME[0]}. No user or pass provided."
    return 0
  fi

  test_start "${FUNCNAME[0]}"
  local SERVICE_NAME STDOUT
  SERVICE_NAME="gantry-test-$(date +%s)"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
  docker service update --quiet --label-add "${LABEL}=${CONFIG}" "${SERVICE_NAME}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"

  local USER_FILE PASS_FILE
  USER_FILE=$(mktemp)
  PASS_FILE=$(mktemp)
  echo "${USER}" > "${USER_FILE}"
  echo "${PASS}" > "${PASS_FILE}"

  export GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  export GANTRY_REGISTRY_CONFIG="${CONFIG}"
  export GANTRY_REGISTRY_HOST="${REGISTRY}"
  export GANTRY_REGISTRY_PASSWORD_FILE="${PASS_FILE}"
  export GANTRY_REGISTRY_USER_FILE="${USER_FILE}"
  STDOUT=$(run_gantry "${FUNCNAME[0]}" 2>&1 | tee /dev/tty)

  expect_message    "${STDOUT}" "Logged into registry *${REGISTRY} for config ${CONFIG}"
  expect_no_message "${STDOUT}" "${SKIP_UPDATING_SERVICE}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_NEW_IMAGE}"
  expect_message    "${STDOUT}" "${SERVICE_NAME}.*${UPDATED}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_UPDATES}"
  expect_no_message "${STDOUT}" "${ROLLING_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${ROLLED_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${NO_SERVICES_UPDATED}"
  expect_message    "${STDOUT}" "${NUM_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NO_IMAGES_TO_REMOVE}"
  expect_message    "${STDOUT}" "${REMOVING_NUM_IMAGES}"
  expect_no_message "${STDOUT}" "${SKIP_REMOVING_IMAGES}"
  expect_message    "${STDOUT}" "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
  expect_no_message "${STDOUT}" "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"

  stop_service "${SERVICE_NAME}"
  test_end "${FUNCNAME[0]}"
  return 0
}

test_SERVICES_EXCLUDED() {
  local IMAGE_WITH_TAG="${1}"

  test_start "${FUNCNAME[0]}"
  local SERVICE_NAME STDOUT
  SERVICE_NAME="gantry-test-$(date +%s)"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"

  export GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  export GANTRY_SERVICES_EXCLUDED="${SERVICE_NAME}"
  STDOUT=$(run_gantry "${FUNCNAME[0]}" 2>&1 | tee /dev/tty)

  expect_no_message "${STDOUT}" "${SKIP_UPDATING_SERVICE}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_NEW_IMAGE}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${UPDATED}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_UPDATES}"
  expect_no_message "${STDOUT}" "${ROLLING_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${ROLLED_BACK}.*${SERVICE_NAME}"
  expect_message    "${STDOUT}" "${NO_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NUM_SERVICES_UPDATED}"
  expect_message    "${STDOUT}" "${NO_IMAGES_TO_REMOVE}"
  expect_no_message "${STDOUT}" "${REMOVING_NUM_IMAGES}"
  expect_no_message "${STDOUT}" "${SKIP_REMOVING_IMAGES}"
  expect_no_message "${STDOUT}" "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
  expect_no_message "${STDOUT}" "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
 
  stop_service "${SERVICE_NAME}"
  test_end "${FUNCNAME[0]}"
  return 0
}

test_SERVICES_EXCLUDED_FILTERS() {
  local IMAGE_WITH_TAG="${1}"

  test_start "${FUNCNAME[0]}"
  local SERVICE_NAME STDOUT
  SERVICE_NAME="gantry-test-$(date +%s)"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"

  export GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  export GANTRY_SERVICES_EXCLUDED_FILTERS="name=${SERVICE_NAME}"
  STDOUT=$(run_gantry "${FUNCNAME[0]}" 2>&1 | tee /dev/tty)

  expect_no_message "${STDOUT}" "${SKIP_UPDATING_SERVICE}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_NEW_IMAGE}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${UPDATED}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_UPDATES}"
  expect_no_message "${STDOUT}" "${ROLLING_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${ROLLED_BACK}.*${SERVICE_NAME}"
  expect_message    "${STDOUT}" "${NO_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NUM_SERVICES_UPDATED}"
  expect_message    "${STDOUT}" "${NO_IMAGES_TO_REMOVE}"
  expect_no_message "${STDOUT}" "${REMOVING_NUM_IMAGES}"
  expect_no_message "${STDOUT}" "${SKIP_REMOVING_IMAGES}"
  expect_no_message "${STDOUT}" "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
  expect_no_message "${STDOUT}" "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"

  stop_service "${SERVICE_NAME}"
  test_end "${FUNCNAME[0]}"
  return 0
}

test_SERVICES_EXCLUDED_combined() {
  local IMAGE_WITH_TAG="${1}"

  test_start "${FUNCNAME[0]}"
  local SERVICE_NAME STDOUT
  BASE_NAME="gantry-test-$(date +%s)"
  SERVICE_NAME0="${BASE_NAME}-0"
  SERVICE_NAME1="${BASE_NAME}-1"
  SERVICE_NAME2="${BASE_NAME}-2"
  SERVICE_NAME3="${BASE_NAME}-3"
  SERVICE_NAME4="${BASE_NAME}-4"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_service "${SERVICE_NAME0}" "${IMAGE_WITH_TAG}"
  start_service "${SERVICE_NAME1}" "${IMAGE_WITH_TAG}"
  start_service "${SERVICE_NAME2}" "${IMAGE_WITH_TAG}"
  start_service "${SERVICE_NAME3}" "${IMAGE_WITH_TAG}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_service "${SERVICE_NAME4}" "${IMAGE_WITH_TAG}"

  export GANTRY_SERVICES_FILTERS="name=${BASE_NAME}"
  # test both the list of names and the filters
  export GANTRY_SERVICES_EXCLUDED="${SERVICE_NAME1}"
  export GANTRY_SERVICES_EXCLUDED_FILTERS="name=${SERVICE_NAME2}"
  STDOUT=$(run_gantry "${FUNCNAME[0]}" 2>&1 | tee /dev/tty)

  # Service 0 and 3 should get updated.
  # Service 1 and 2 should be excluded.
  # Service 4 created with new image, no update.
  # Failed to remove the image as service 1 and 2 are still using it.
  expect_no_message "${STDOUT}" "${SKIP_UPDATING_SERVICE}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME0}.*${NO_NEW_IMAGE}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME1}.*${NO_NEW_IMAGE}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME2}.*${NO_NEW_IMAGE}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME3}.*${NO_NEW_IMAGE}"
  expect_message    "${STDOUT}" "${SERVICE_NAME4}.*${NO_NEW_IMAGE}"
  expect_message    "${STDOUT}" "${SERVICE_NAME0}.*${UPDATED}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME1}.*${UPDATED}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME2}.*${UPDATED}"
  expect_message    "${STDOUT}" "${SERVICE_NAME3}.*${UPDATED}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME4}.*${UPDATED}"
  expect_no_message "${STDOUT}" "${NO_SERVICES_UPDATED}"
  expect_message    "${STDOUT}" "${NUM_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NO_IMAGES_TO_REMOVE}"
  expect_message    "${STDOUT}" "${REMOVING_NUM_IMAGES}"
  expect_no_message "${STDOUT}" "${SKIP_REMOVING_IMAGES}"
  expect_no_message "${STDOUT}" "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
  expect_message    "${STDOUT}" "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"

  stop_service "${SERVICE_NAME4}"
  stop_service "${SERVICE_NAME3}"
  stop_service "${SERVICE_NAME2}"
  stop_service "${SERVICE_NAME1}"
  stop_service "${SERVICE_NAME0}"
  test_end "${FUNCNAME[0]}"
  return 0
}

test_jobs_skipping() {
  local IMAGE_WITH_TAG="${1}"

  test_start "${FUNCNAME[0]}"
  local SERVICE_NAME STDOUT
  SERVICE_NAME="gantry-test-$(date +%s)"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_replicated_job "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"

  export GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  STDOUT=$(run_gantry "${FUNCNAME[0]}" 2>&1 | tee /dev/tty)

  expect_message    "${STDOUT}" "${SKIP_UPDATING_SERVICE}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_NEW_IMAGE}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${UPDATED}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_UPDATES}"
  expect_no_message "${STDOUT}" "${ROLLING_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${ROLLED_BACK}.*${SERVICE_NAME}"
  expect_message    "${STDOUT}" "${NO_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NUM_SERVICES_UPDATED}"
  expect_message    "${STDOUT}" "${NO_IMAGES_TO_REMOVE}"
  expect_no_message "${STDOUT}" "${REMOVING_NUM_IMAGES}"
  expect_no_message "${STDOUT}" "${SKIP_REMOVING_IMAGES}"
  expect_no_message "${STDOUT}" "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
  expect_no_message "${STDOUT}" "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"

  stop_service "${SERVICE_NAME}"
  test_end "${FUNCNAME[0]}"
  return 0
}

test_jobs_UPDATE_JOBS_on() {
  local IMAGE_WITH_TAG="${1}"

  test_start "${FUNCNAME[0]}"
  local SERVICE_NAME STDOUT
  SERVICE_NAME="gantry-test-$(date +%s)"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_replicated_job "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"

  export GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  export GANTRY_UPDATE_JOBS="true"
  # The job may not reach the desired "Complete" state and blocking update CLI. So add "--detach=true"
  export GANTRY_UPDATE_OPTIONS="--detach=true"
  STDOUT=$(run_gantry "${FUNCNAME[0]}" 2>&1 | tee /dev/tty)

  expect_no_message "${STDOUT}" "${SKIP_UPDATING_SERVICE}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_NEW_IMAGE}"
  expect_message    "${STDOUT}" "${SERVICE_NAME}.*${UPDATED}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_UPDATES}"
  expect_no_message "${STDOUT}" "${ROLLING_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${ROLLED_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${NO_SERVICES_UPDATED}"
  expect_message    "${STDOUT}" "${NUM_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NO_IMAGES_TO_REMOVE}"
  expect_message    "${STDOUT}" "${REMOVING_NUM_IMAGES}"
  expect_no_message "${STDOUT}" "${SKIP_REMOVING_IMAGES}"
  # Since the job may not reach the desired state, they are still using the image. Image remover will fail.
  expect_no_message    "${STDOUT}" "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
  expect_message "${STDOUT}" "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"

  stop_service "${SERVICE_NAME}"
  test_end "${FUNCNAME[0]}"
  return 0
}

test_MANIFEST_INSPECT_off() {
  local IMAGE_WITH_TAG="${1}"

  test_start "${FUNCNAME[0]}"
  local SERVICE_NAME STDOUT
  SERVICE_NAME="gantry-test-$(date +%s)"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
  # No image updates after service started.

  export GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  export GANTRY_MANIFEST_INSPECT="false"
  export GANTRY_UPDATE_OPTIONS="--force"
  STDOUT=$(run_gantry "${FUNCNAME[0]}" 2>&1 | tee /dev/tty)

  # Gantry is still trying to update the service.
  # But it will see no new images.
  expect_no_message "${STDOUT}" "${SKIP_UPDATING_SERVICE}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_NEW_IMAGE}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${UPDATED}"
  expect_message    "${STDOUT}" "${SERVICE_NAME}.*${NO_UPDATES}"
  expect_no_message "${STDOUT}" "${ROLLING_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${ROLLED_BACK}.*${SERVICE_NAME}"
  expect_message    "${STDOUT}" "${NO_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NUM_SERVICES_UPDATED}"
  expect_message    "${STDOUT}" "${NO_IMAGES_TO_REMOVE}"
  expect_no_message "${STDOUT}" "${REMOVING_NUM_IMAGES}"
  expect_no_message "${STDOUT}" "${SKIP_REMOVING_IMAGES}"
  expect_no_message "${STDOUT}" "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
  expect_no_message "${STDOUT}" "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"

  stop_service "${SERVICE_NAME}"
  test_end "${FUNCNAME[0]}"
  return 0
}

test_replicated_no_running_tasks() {
  # Add "--detach=true" when there is no running tasks.
  # https://github.com/docker/cli/issues/627
  local IMAGE_WITH_TAG="${1}"

  test_start "${FUNCNAME[0]}"
  local SERVICE_NAME STDOUT
  SERVICE_NAME="gantry-test-$(date +%s)"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
  docker service update --quiet --replicas=0 "${SERVICE_NAME}"
  wait_zero_running_tasks "${SERVICE_NAME}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"

  export GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  STDOUT=$(run_gantry "${FUNCNAME[0]}" 2>&1 | tee /dev/tty)

  expect_message    "${STDOUT}" "Add option.*--detach=true"
  expect_message    "${STDOUT}" "Add option.*--replicas=0"
  expect_no_message "${STDOUT}" "${SKIP_UPDATING_SERVICE}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_NEW_IMAGE}"
  expect_message    "${STDOUT}" "${SERVICE_NAME}.*${UPDATED}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_UPDATES}"
  expect_no_message "${STDOUT}" "${ROLLING_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${ROLLED_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${NO_SERVICES_UPDATED}"
  expect_message    "${STDOUT}" "${NUM_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NO_IMAGES_TO_REMOVE}"
  expect_message    "${STDOUT}" "${REMOVING_NUM_IMAGES}"
  expect_no_message "${STDOUT}" "${SKIP_REMOVING_IMAGES}"
  expect_message    "${STDOUT}" "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
  expect_no_message "${STDOUT}" "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"

  stop_service "${SERVICE_NAME}"
  test_end "${FUNCNAME[0]}"
  return 0
}

test_replicated_no_running_tasks_rollback() {
  # Add "--detach=true" when there is no running tasks.
  # https://github.com/docker/cli/issues/627
  # To test it is ok to add the additional options to docker service update --rollback.
  local IMAGE_WITH_TAG="${1}"

  test_start "${FUNCNAME[0]}"
  local SERVICE_NAME STDOUT
  SERVICE_NAME="gantry-test-$(date +%s)"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
  docker service update --quiet --replicas=0 "${SERVICE_NAME}"
  wait_zero_running_tasks "${SERVICE_NAME}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"

  export GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  # Assume service update won't be done within 1 second.
  export GANTRY_UPDATE_TIMEOUT_SECONDS=1
  STDOUT=$(run_gantry "${FUNCNAME[0]}" 2>&1 | tee /dev/tty)

  expect_message    "${STDOUT}" "Add option.*--detach=true"
  expect_message    "${STDOUT}" "Add option.*--replicas=0"
  expect_no_message "${STDOUT}" "${SKIP_UPDATING_SERVICE}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_NEW_IMAGE}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${UPDATED}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_UPDATES}"
  expect_message    "${STDOUT}" "${ROLLING_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
  expect_message    "${STDOUT}" "${ROLLED_BACK}.*${SERVICE_NAME}"
  expect_message    "${STDOUT}" "${NO_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NUM_SERVICES_UPDATED}"
  expect_message    "${STDOUT}" "${NO_IMAGES_TO_REMOVE}"
  expect_no_message "${STDOUT}" "${REMOVING_NUM_IMAGES}"
  expect_no_message "${STDOUT}" "${SKIP_REMOVING_IMAGES}"
  expect_no_message "${STDOUT}" "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
  expect_no_message "${STDOUT}" "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"

  stop_service "${SERVICE_NAME}"
  test_end "${FUNCNAME[0]}"
  return 0
}

test_timeout_rollback() {
  local IMAGE_WITH_TAG="${1}"

  test_start "${FUNCNAME[0]}"
  local SERVICE_NAME STDOUT
  SERVICE_NAME="gantry-test-$(date +%s)"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"

  export GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  # Assume service update won't be done within 1 second.
  export GANTRY_UPDATE_TIMEOUT_SECONDS=1
  STDOUT=$(run_gantry "${FUNCNAME[0]}" 2>&1 | tee /dev/tty)

  expect_no_message "${STDOUT}" "${SKIP_UPDATING_SERVICE}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_NEW_IMAGE}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${UPDATED}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_UPDATES}"
  expect_message    "${STDOUT}" "${ROLLING_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
  expect_message    "${STDOUT}" "${ROLLED_BACK}.*${SERVICE_NAME}"
  expect_message    "${STDOUT}" "${NO_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NUM_SERVICES_UPDATED}"
  expect_message    "${STDOUT}" "${NO_IMAGES_TO_REMOVE}"
  expect_no_message "${STDOUT}" "${REMOVING_NUM_IMAGES}"
  expect_no_message "${STDOUT}" "${SKIP_REMOVING_IMAGES}"
  expect_no_message "${STDOUT}" "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
  expect_no_message "${STDOUT}" "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"

  stop_service "${SERVICE_NAME}"
  test_end "${FUNCNAME[0]}"
  return 0
}

test_timeout_rollback_failed() {
  local IMAGE_WITH_TAG="${1}"

  test_start "${FUNCNAME[0]}"
  local SERVICE_NAME STDOUT
  SERVICE_NAME="gantry-test-$(date +%s)"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"

  export GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  # Assume service update won't be done within 1 second.
  export GANTRY_UPDATE_TIMEOUT_SECONDS=1
  export GANTRY_ROLLBACK_OPTIONS="--incorrect_option"
  STDOUT=$(run_gantry "${FUNCNAME[0]}" 2>&1 | tee /dev/tty)

  expect_no_message "${STDOUT}" "${SKIP_UPDATING_SERVICE}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_NEW_IMAGE}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${UPDATED}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_UPDATES}"
  expect_message    "${STDOUT}" "${ROLLING_BACK}.*${SERVICE_NAME}"
  expect_message    "${STDOUT}" "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${ROLLED_BACK}.*${SERVICE_NAME}"
  expect_message    "${STDOUT}" "${NO_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NUM_SERVICES_UPDATED}"
  expect_message    "${STDOUT}" "${NO_IMAGES_TO_REMOVE}"
  expect_no_message "${STDOUT}" "${REMOVING_NUM_IMAGES}"
  expect_no_message "${STDOUT}" "${SKIP_REMOVING_IMAGES}"
  expect_no_message "${STDOUT}" "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
  expect_no_message "${STDOUT}" "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"

  stop_service "${SERVICE_NAME}"
  test_end "${FUNCNAME[0]}"
  return 0
}

test_timeout_ROLLBACK_ON_FAILURE_off() {
  local IMAGE_WITH_TAG="${1}"

  test_start "${FUNCNAME[0]}"
  local SERVICE_NAME STDOUT
  SERVICE_NAME="gantry-test-$(date +%s)"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"

  export GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  # Assume service update won't be done within 1 second.
  export GANTRY_UPDATE_TIMEOUT_SECONDS=1
  export GANTRY_ROLLBACK_ON_FAILURE="false"
  STDOUT=$(run_gantry "${FUNCNAME[0]}" 2>&1 | tee /dev/tty)

  expect_no_message "${STDOUT}" "${SKIP_UPDATING_SERVICE}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_NEW_IMAGE}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${UPDATED}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_UPDATES}"
  expect_no_message "${STDOUT}" "${ROLLING_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${ROLLED_BACK}.*${SERVICE_NAME}"
  expect_message    "${STDOUT}" "${NO_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NUM_SERVICES_UPDATED}"
  expect_message    "${STDOUT}" "${NO_IMAGES_TO_REMOVE}"
  expect_no_message "${STDOUT}" "${REMOVING_NUM_IMAGES}"
  expect_no_message "${STDOUT}" "${SKIP_REMOVING_IMAGES}"
  expect_no_message "${STDOUT}" "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
  expect_no_message "${STDOUT}" "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"

  stop_service "${SERVICE_NAME}"
  test_end "${FUNCNAME[0]}"
  return 0
}

test_CLEANUP_IMAGES_off() {
  local IMAGE_WITH_TAG="${1}"

  test_start "${FUNCNAME[0]}"
  local SERVICE_NAME STDOUT
  SERVICE_NAME="gantry-test-$(date +%s)"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"

  export GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  export GANTRY_CLEANUP_IMAGES="false"
  STDOUT=$(run_gantry "${FUNCNAME[0]}" 2>&1 | tee /dev/tty)

  expect_no_message "${STDOUT}" "${SKIP_UPDATING_SERVICE}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_NEW_IMAGE}"
  expect_message    "${STDOUT}" "${SERVICE_NAME}.*${UPDATED}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_UPDATES}"
  expect_no_message "${STDOUT}" "${ROLLING_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${ROLLED_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${NO_SERVICES_UPDATED}"
  expect_message    "${STDOUT}" "${NUM_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NO_IMAGES_TO_REMOVE}"
  expect_no_message "${STDOUT}" "${REMOVING_NUM_IMAGES}"
  expect_message    "${STDOUT}" "${SKIP_REMOVING_IMAGES}"
  expect_no_message "${STDOUT}" "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
  expect_no_message "${STDOUT}" "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"

  stop_service "${SERVICE_NAME}"
  test_end "${FUNCNAME[0]}"
  return 0
}
