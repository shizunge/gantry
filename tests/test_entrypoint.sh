#!/bin/bash
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

SKIP_UPDATING_SERVICE="Skip updating service in .*job mode"
NO_NEW_IMAGE="No new image"
ADD_OPTION="Adding options"
NO_UPDATES="No updates"
UPDATED="UPDATED"
ROLLING_BACK="Rolling back"
FAILED_TO_ROLLBACK="Failed to roll back"
ROLLED_BACK="Rolled back"
NO_SERVICES_UPDATED="No services updated"
NO_IMAGES_TO_REMOVE="No images to remove"
NUM_SERVICES_UPDATED="[1-9] service\(s\) updated"
NUM_SERVICES_UPDATE_FAILED="[1-9] service\(s\) update failed"
REMOVING_NUM_IMAGES="Removing [1-9] image\(s\)"
SKIP_REMOVING_IMAGES="Skip removing images"
REMOVED_IMAGE="Removed image"
FAILED_TO_REMOVE_IMAGE="Failed to remove image"

test_new_image_no() {
  local IMAGE_WITH_TAG="${1}"
  local SERVICE_NAME STDOUT
  SERVICE_NAME="gantry-test-$(unique_id)"

  initialize_test "${FUNCNAME[0]}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_replicated_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"

  export GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  STDOUT=$(run_gantry "${FUNCNAME[0]}" 2>&1 | tee >(cat 1>&2))

  expect_no_message "${STDOUT}" "${SKIP_UPDATING_SERVICE}.*${SERVICE_NAME}"
  expect_message    "${STDOUT}" "${SERVICE_NAME}.*${NO_NEW_IMAGE}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${UPDATED}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_UPDATES}"
  expect_no_message "${STDOUT}" "${ROLLING_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${ROLLED_BACK}.*${SERVICE_NAME}"
  expect_message    "${STDOUT}" "${NO_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NUM_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NUM_SERVICES_UPDATE_FAILED}"
  expect_message    "${STDOUT}" "${NO_IMAGES_TO_REMOVE}"
  expect_no_message "${STDOUT}" "${REMOVING_NUM_IMAGES}"
  expect_no_message "${STDOUT}" "${SKIP_REMOVING_IMAGES}"
  expect_no_message "${STDOUT}" "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
  expect_no_message "${STDOUT}" "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"

  stop_service "${SERVICE_NAME}"
  prune_local_test_image "${IMAGE_WITH_TAG}"
  finalize_test "${FUNCNAME[0]}"
}

test_new_image_yes() {
  local IMAGE_WITH_TAG="${1}"
  local SERVICE_NAME STDOUT
  SERVICE_NAME="gantry-test-$(unique_id)"

  initialize_test "${FUNCNAME[0]}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_replicated_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"

  export GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  STDOUT=$(run_gantry "${FUNCNAME[0]}" 2>&1 | tee >(cat 1>&2))

  expect_no_message "${STDOUT}" "${SKIP_UPDATING_SERVICE}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_NEW_IMAGE}"
  expect_message    "${STDOUT}" "${SERVICE_NAME}.*${UPDATED}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_UPDATES}"
  expect_no_message "${STDOUT}" "${ROLLING_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${ROLLED_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${NO_SERVICES_UPDATED}"
  expect_message    "${STDOUT}" "${NUM_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NUM_SERVICES_UPDATE_FAILED}"
  expect_no_message "${STDOUT}" "${NO_IMAGES_TO_REMOVE}"
  expect_message    "${STDOUT}" "${REMOVING_NUM_IMAGES}"
  expect_no_message "${STDOUT}" "${SKIP_REMOVING_IMAGES}"
  expect_message    "${STDOUT}" "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
  expect_no_message "${STDOUT}" "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"

  stop_service "${SERVICE_NAME}"
  prune_local_test_image "${IMAGE_WITH_TAG}"
  finalize_test "${FUNCNAME[0]}"
}

test_new_image_multiple_services() {
  local IMAGE_WITH_TAG="${1}"
  local BASE_NAME STDOUT
  BASE_NAME="gantry-test-$(unique_id)"
  local SERVICE_NAME0="${BASE_NAME}-0"
  local SERVICE_NAME1="${BASE_NAME}-1"
  local SERVICE_NAME2="${BASE_NAME}-2"
  local SERVICE_NAME3="${BASE_NAME}-3"
  local SERVICE_NAME4="${BASE_NAME}-4"

  initialize_test "${FUNCNAME[0]}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_replicated_service "${SERVICE_NAME0}" "${IMAGE_WITH_TAG}"
  start_replicated_service "${SERVICE_NAME1}" "${IMAGE_WITH_TAG}"
  start_replicated_service "${SERVICE_NAME2}" "${IMAGE_WITH_TAG}"
  start_replicated_service "${SERVICE_NAME3}" "${IMAGE_WITH_TAG}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_replicated_service "${SERVICE_NAME4}" "${IMAGE_WITH_TAG}"

  export GANTRY_SERVICES_FILTERS="name=${BASE_NAME}"
  # test both the list of names and the filters
  export GANTRY_SERVICES_EXCLUDED="${SERVICE_NAME1}"
  export GANTRY_SERVICES_EXCLUDED_FILTERS="name=${SERVICE_NAME2}"
  STDOUT=$(run_gantry "${FUNCNAME[0]}" 2>&1 | tee >(cat 1>&2))

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
  expect_no_message "${STDOUT}" "${NUM_SERVICES_UPDATE_FAILED}"
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
  prune_local_test_image "${IMAGE_WITH_TAG}"
  finalize_test "${FUNCNAME[0]}"
}

test_login_config() {
  # It would be difficult to test updating failure due to authorization errors.
  # We may need to setup a private registry to test that.
  # Here are just a simple login test.
  local IMAGE_WITH_TAG="${1}"
  local REGISTRY="${2}"
  local USER="${3}"
  local PASS="${4}"
  local SERVICE_NAME STDOUT
  SERVICE_NAME="gantry-test-$(unique_id)"
  local LABEL="gantry.auth.config"
  local CONFIG=
  CONFIG="C$(unique_id)"
  if [ -z "${USER}" ] || [ -z "${PASS}" ]; then
    echo "Skip ${FUNCNAME[0]}. No user or pass provided."
    return 0
  fi

  initialize_test "${FUNCNAME[0]}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_replicated_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
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
  STDOUT=$(run_gantry "${FUNCNAME[0]}" 2>&1 | tee >(cat 1>&2))
  rm "${USER_FILE}"
  rm "${PASS_FILE}"

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
  expect_no_message "${STDOUT}" "${NUM_SERVICES_UPDATE_FAILED}"
  expect_no_message "${STDOUT}" "${NO_IMAGES_TO_REMOVE}"
  expect_message    "${STDOUT}" "${REMOVING_NUM_IMAGES}"
  expect_no_message "${STDOUT}" "${SKIP_REMOVING_IMAGES}"
  expect_message    "${STDOUT}" "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
  expect_no_message "${STDOUT}" "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"

  stop_service "${SERVICE_NAME}"
  prune_local_test_image "${IMAGE_WITH_TAG}"
  finalize_test "${FUNCNAME[0]}"
}

test_login_REGISTRY_CONFIGS_FILE() {
  # It would be difficult to test updating failure due to authorization errors.
  # We may need to setup a private registry to test that.
  # Here are just a simple login test.
  local IMAGE_WITH_TAG="${1}"
  local REGISTRY="${2}"
  local USER="${3}"
  local PASS="${4}"
  local SERVICE_NAME STDOUT
  SERVICE_NAME="gantry-test-$(unique_id)"
  local LABEL="gantry.auth.config"
  local CONFIG=
  CONFIG="C$(unique_id)"
  if [ -z "${REGISTRY}" ] || [ -z "${USER}" ] || [ -z "${PASS}" ]; then
    echo "Skip ${FUNCNAME[0]}. No registry, user or pass provided."
    return 0
  fi

  initialize_test "${FUNCNAME[0]}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_replicated_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
  docker service update --quiet --label-add "${LABEL}=${CONFIG}" "${SERVICE_NAME}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"

  local CONFIGS_FILE=
  CONFIGS_FILE=$(mktemp)
  echo "${CONFIG} ${REGISTRY} ${USER} ${PASS}" > "${CONFIGS_FILE}"

  export GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  export GANTRY_REGISTRY_CONFIGS_FILE="${CONFIGS_FILE}"
  STDOUT=$(run_gantry "${FUNCNAME[0]}" 2>&1 | tee >(cat 1>&2))
  rm "${CONFIGS_FILE}"
  rm -r "${CONFIG}"

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
  expect_no_message "${STDOUT}" "${NUM_SERVICES_UPDATE_FAILED}"
  expect_no_message "${STDOUT}" "${NO_IMAGES_TO_REMOVE}"
  expect_message    "${STDOUT}" "${REMOVING_NUM_IMAGES}"
  expect_no_message "${STDOUT}" "${SKIP_REMOVING_IMAGES}"
  expect_message    "${STDOUT}" "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
  expect_no_message "${STDOUT}" "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"

  stop_service "${SERVICE_NAME}"
  prune_local_test_image "${IMAGE_WITH_TAG}"
  finalize_test "${FUNCNAME[0]}"
}

test_SERVICES_EXCLUDED() {
  local IMAGE_WITH_TAG="${1}"
  local SERVICE_NAME STDOUT
  SERVICE_NAME="gantry-test-$(unique_id)"

  initialize_test "${FUNCNAME[0]}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_replicated_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"

  export GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  export GANTRY_SERVICES_EXCLUDED="${SERVICE_NAME}"
  STDOUT=$(run_gantry "${FUNCNAME[0]}" 2>&1 | tee >(cat 1>&2))

  expect_no_message "${STDOUT}" "${SKIP_UPDATING_SERVICE}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_NEW_IMAGE}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${UPDATED}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_UPDATES}"
  expect_no_message "${STDOUT}" "${ROLLING_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${ROLLED_BACK}.*${SERVICE_NAME}"
  expect_message    "${STDOUT}" "${NO_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NUM_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NUM_SERVICES_UPDATE_FAILED}"
  expect_message    "${STDOUT}" "${NO_IMAGES_TO_REMOVE}"
  expect_no_message "${STDOUT}" "${REMOVING_NUM_IMAGES}"
  expect_no_message "${STDOUT}" "${SKIP_REMOVING_IMAGES}"
  expect_no_message "${STDOUT}" "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
  expect_no_message "${STDOUT}" "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
 
  stop_service "${SERVICE_NAME}"
  prune_local_test_image "${IMAGE_WITH_TAG}"
  finalize_test "${FUNCNAME[0]}"
}

test_SERVICES_EXCLUDED_FILTERS() {
  local IMAGE_WITH_TAG="${1}"
  local SERVICE_NAME STDOUT
  SERVICE_NAME="gantry-test-$(unique_id)"

  initialize_test "${FUNCNAME[0]}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_replicated_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"

  export GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  export GANTRY_SERVICES_EXCLUDED_FILTERS="name=${SERVICE_NAME}"
  STDOUT=$(run_gantry "${FUNCNAME[0]}" 2>&1 | tee >(cat 1>&2))

  expect_no_message "${STDOUT}" "${SKIP_UPDATING_SERVICE}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_NEW_IMAGE}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${UPDATED}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_UPDATES}"
  expect_no_message "${STDOUT}" "${ROLLING_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${ROLLED_BACK}.*${SERVICE_NAME}"
  expect_message    "${STDOUT}" "${NO_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NUM_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NUM_SERVICES_UPDATE_FAILED}"
  expect_message    "${STDOUT}" "${NO_IMAGES_TO_REMOVE}"
  expect_no_message "${STDOUT}" "${REMOVING_NUM_IMAGES}"
  expect_no_message "${STDOUT}" "${SKIP_REMOVING_IMAGES}"
  expect_no_message "${STDOUT}" "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
  expect_no_message "${STDOUT}" "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"

  stop_service "${SERVICE_NAME}"
  prune_local_test_image "${IMAGE_WITH_TAG}"
  finalize_test "${FUNCNAME[0]}"
}

test_jobs_skipping() {
  local IMAGE_WITH_TAG="${1}"
  local SERVICE_NAME STDOUT
  SERVICE_NAME="gantry-test-$(unique_id)"

  initialize_test "${FUNCNAME[0]}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_replicated_job "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"

  export GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  STDOUT=$(run_gantry "${FUNCNAME[0]}" 2>&1 | tee >(cat 1>&2))

  expect_message    "${STDOUT}" "${SKIP_UPDATING_SERVICE}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_NEW_IMAGE}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${UPDATED}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_UPDATES}"
  expect_no_message "${STDOUT}" "${ROLLING_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${ROLLED_BACK}.*${SERVICE_NAME}"
  expect_message    "${STDOUT}" "${NO_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NUM_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NUM_SERVICES_UPDATE_FAILED}"
  expect_message    "${STDOUT}" "${NO_IMAGES_TO_REMOVE}"
  expect_no_message "${STDOUT}" "${REMOVING_NUM_IMAGES}"
  expect_no_message "${STDOUT}" "${SKIP_REMOVING_IMAGES}"
  expect_no_message "${STDOUT}" "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
  expect_no_message "${STDOUT}" "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"

  stop_service "${SERVICE_NAME}"
  prune_local_test_image "${IMAGE_WITH_TAG}"
  finalize_test "${FUNCNAME[0]}"
}

test_jobs_UPDATE_JOBS_true() {
  local IMAGE_WITH_TAG="${1}"
  local SERVICE_NAME STDOUT
  SERVICE_NAME="gantry-test-$(unique_id)"

  initialize_test "${FUNCNAME[0]}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_replicated_job "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"

  export GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  export GANTRY_UPDATE_JOBS="true"
  # The job may not reach the desired "Complete" state and blocking update CLI. So add "--detach=true"
  export GANTRY_UPDATE_OPTIONS="--detach=true"
  STDOUT=$(run_gantry "${FUNCNAME[0]}" 2>&1 | tee >(cat 1>&2))

  expect_no_message "${STDOUT}" "${SKIP_UPDATING_SERVICE}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_NEW_IMAGE}"
  expect_message    "${STDOUT}" "${ADD_OPTION}.*${GANTRY_UPDATE_OPTIONS}"
  expect_message    "${STDOUT}" "${SERVICE_NAME}.*${UPDATED}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_UPDATES}"
  expect_no_message "${STDOUT}" "${ROLLING_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${ROLLED_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${NO_SERVICES_UPDATED}"
  expect_message    "${STDOUT}" "${NUM_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NUM_SERVICES_UPDATE_FAILED}"
  expect_no_message "${STDOUT}" "${NO_IMAGES_TO_REMOVE}"
  expect_message    "${STDOUT}" "${REMOVING_NUM_IMAGES}"
  expect_no_message "${STDOUT}" "${SKIP_REMOVING_IMAGES}"
  # Since the job may not reach the desired state, they are still using the image. Image remover will fail.
  expect_no_message "${STDOUT}" "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
  expect_message    "${STDOUT}" "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"

  stop_service "${SERVICE_NAME}"
  prune_local_test_image "${IMAGE_WITH_TAG}"
  finalize_test "${FUNCNAME[0]}"
}

test_jobs_UPDATE_JOBS_true_no_running_tasks() {
  local IMAGE_WITH_TAG="${1}"
  local SERVICE_NAME SLEEP_SECONDS STDOUT
  SERVICE_NAME="gantry-test-$(unique_id)"
  SLEEP_SECONDS=15

  initialize_test "${FUNCNAME[0]}"
  build_and_push_test_image "${IMAGE_WITH_TAG}" "${SLEEP_SECONDS}"
  start_replicated_job "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
  wait_zero_running_tasks "${SERVICE_NAME}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"

  export GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  export GANTRY_UPDATE_JOBS="true"
  STDOUT=$(run_gantry "${FUNCNAME[0]}" 2>&1 | tee >(cat 1>&2))

  expect_message    "${STDOUT}" "${ADD_OPTION}.*--detach=true"
  # Cannot add "--replicas" to replicated job
  expect_no_message "${STDOUT}" "${ADD_OPTION}.*--replicas=0"
  expect_no_message "${STDOUT}" "${SKIP_UPDATING_SERVICE}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_NEW_IMAGE}"
  expect_message    "${STDOUT}" "${SERVICE_NAME}.*${UPDATED}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_UPDATES}"
  expect_no_message "${STDOUT}" "${ROLLING_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${ROLLED_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${NO_SERVICES_UPDATED}"
  expect_message    "${STDOUT}" "${NUM_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NUM_SERVICES_UPDATE_FAILED}"
  expect_no_message "${STDOUT}" "${NO_IMAGES_TO_REMOVE}"
  expect_message    "${STDOUT}" "${REMOVING_NUM_IMAGES}"
  expect_no_message "${STDOUT}" "${SKIP_REMOVING_IMAGES}"
  expect_message    "${STDOUT}" "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
  expect_no_message "${STDOUT}" "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"

  stop_service "${SERVICE_NAME}"
  prune_local_test_image "${IMAGE_WITH_TAG}"
  finalize_test "${FUNCNAME[0]}"
}

test_MANIFEST_CMD_none() {
  local IMAGE_WITH_TAG="${1}"
  local SERVICE_NAME STDOUT
  SERVICE_NAME="gantry-test-$(unique_id)"

  initialize_test "${FUNCNAME[0]}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_replicated_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
  # No image updates after service started.

  export GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  export GANTRY_MANIFEST_CMD="none"
  export GANTRY_UPDATE_OPTIONS="--force"
  STDOUT=$(run_gantry "${FUNCNAME[0]}" 2>&1 | tee >(cat 1>&2))

  # Do not set GANTRY_SERVICES_SELF, it should be set autoamtically
  # If we are not testing gantry inside a container, it should failed to find the service name.
  # To test gantry container, we need to use run_gantry_container.
  expect_no_message "${STDOUT}" ".*GRANTRY_SERVICES_SELF.*"
  # Gantry is still trying to update the service.
  # But it will see no new images.
  expect_no_message "${STDOUT}" "${SKIP_UPDATING_SERVICE}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_NEW_IMAGE}"
  expect_message    "${STDOUT}" "${ADD_OPTION}.*${GANTRY_UPDATE_OPTIONS}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${UPDATED}"
  expect_message    "${STDOUT}" "${SERVICE_NAME}.*${NO_UPDATES}"
  expect_no_message "${STDOUT}" "${ROLLING_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${ROLLED_BACK}.*${SERVICE_NAME}"
  expect_message    "${STDOUT}" "${NO_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NUM_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NUM_SERVICES_UPDATE_FAILED}"
  expect_message    "${STDOUT}" "${NO_IMAGES_TO_REMOVE}"
  expect_no_message "${STDOUT}" "${REMOVING_NUM_IMAGES}"
  expect_no_message "${STDOUT}" "${SKIP_REMOVING_IMAGES}"
  expect_no_message "${STDOUT}" "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
  expect_no_message "${STDOUT}" "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"

  stop_service "${SERVICE_NAME}"
  prune_local_test_image "${IMAGE_WITH_TAG}"
  finalize_test "${FUNCNAME[0]}"
}

test_MANIFEST_CMD_none_SERVICES_SELF() {
  # If the service is self, it will always run manifest checking. Even if the CMD is set to none
  local IMAGE_WITH_TAG="${1}"
  local SERVICE_NAME STDOUT
  SERVICE_NAME="gantry-test-$(unique_id)"

  initialize_test "${FUNCNAME[0]}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_replicated_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
  # No image updates after service started.

  # Explicitly set GANTRY_SERVICES_SELF
  export GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  export GANTRY_SERVICES_SELF="${SERVICE_NAME}"
  export GANTRY_MANIFEST_CMD="none"
  STDOUT=$(run_gantry "${FUNCNAME[0]}" 2>&1 | tee >(cat 1>&2))

  expect_no_message "${STDOUT}" ".*GRANTRY_SERVICES_SELF.*"
  expect_no_message "${STDOUT}" "${SKIP_UPDATING_SERVICE}.*${SERVICE_NAME}"
  expect_message    "${STDOUT}" "${SERVICE_NAME}.*${NO_NEW_IMAGE}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${UPDATED}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_UPDATES}"
  expect_no_message "${STDOUT}" "${ROLLING_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${ROLLED_BACK}.*${SERVICE_NAME}"
  expect_message    "${STDOUT}" "${NO_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NUM_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NUM_SERVICES_UPDATE_FAILED}"
  expect_message    "${STDOUT}" "${NO_IMAGES_TO_REMOVE}"
  expect_no_message "${STDOUT}" "${REMOVING_NUM_IMAGES}"
  expect_no_message "${STDOUT}" "${SKIP_REMOVING_IMAGES}"
  expect_no_message "${STDOUT}" "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
  expect_no_message "${STDOUT}" "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"

  stop_service "${SERVICE_NAME}"
  prune_local_test_image "${IMAGE_WITH_TAG}"
  finalize_test "${FUNCNAME[0]}"
}

test_MANIFEST_CMD_manifest() {
  local IMAGE_WITH_TAG="${1}"
  local SERVICE_NAME STDOUT
  SERVICE_NAME="gantry-test-$(unique_id)"

  initialize_test "${FUNCNAME[0]}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_replicated_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"

  export GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  export GANTRY_MANIFEST_OPTIONS="--insecure"
  export GANTRY_MANIFEST_CMD="manifest"
  STDOUT=$(run_gantry "${FUNCNAME[0]}" 2>&1 | tee >(cat 1>&2))

  expect_no_message "${STDOUT}" "${SKIP_UPDATING_SERVICE}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_NEW_IMAGE}"
  expect_message    "${STDOUT}" "${SERVICE_NAME}.*${UPDATED}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_UPDATES}"
  expect_no_message "${STDOUT}" "${ROLLING_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${ROLLED_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${NO_SERVICES_UPDATED}"
  expect_message    "${STDOUT}" "${NUM_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NUM_SERVICES_UPDATE_FAILED}"
  expect_no_message "${STDOUT}" "${NO_IMAGES_TO_REMOVE}"
  expect_message    "${STDOUT}" "${REMOVING_NUM_IMAGES}"
  expect_no_message "${STDOUT}" "${SKIP_REMOVING_IMAGES}"
  expect_message    "${STDOUT}" "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
  expect_no_message "${STDOUT}" "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"

  stop_service "${SERVICE_NAME}"
  prune_local_test_image "${IMAGE_WITH_TAG}"
  finalize_test "${FUNCNAME[0]}"
}

test_no_running_tasks_replicated() {
  # Add "--detach=true" when there is no running tasks.
  # https://github.com/docker/cli/issues/627
  local IMAGE_WITH_TAG="${1}"
  local SERVICE_NAME STDOUT
  SERVICE_NAME="gantry-test-$(unique_id)"

  initialize_test "${FUNCNAME[0]}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_replicated_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
  docker service update --quiet --replicas=0 "${SERVICE_NAME}"
  wait_zero_running_tasks "${SERVICE_NAME}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"

  export GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  STDOUT=$(run_gantry "${FUNCNAME[0]}" 2>&1 | tee >(cat 1>&2))

  expect_message    "${STDOUT}" "${ADD_OPTION}.*--detach=true"
  expect_message    "${STDOUT}" "${ADD_OPTION}.*--replicas=0"
  expect_no_message "${STDOUT}" "${SKIP_UPDATING_SERVICE}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_NEW_IMAGE}"
  expect_message    "${STDOUT}" "${SERVICE_NAME}.*${UPDATED}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_UPDATES}"
  expect_no_message "${STDOUT}" "${ROLLING_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${ROLLED_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${NO_SERVICES_UPDATED}"
  expect_message    "${STDOUT}" "${NUM_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NUM_SERVICES_UPDATE_FAILED}"
  expect_no_message "${STDOUT}" "${NO_IMAGES_TO_REMOVE}"
  expect_message    "${STDOUT}" "${REMOVING_NUM_IMAGES}"
  expect_no_message "${STDOUT}" "${SKIP_REMOVING_IMAGES}"
  expect_message    "${STDOUT}" "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
  expect_no_message "${STDOUT}" "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"

  stop_service "${SERVICE_NAME}"
  prune_local_test_image "${IMAGE_WITH_TAG}"
  finalize_test "${FUNCNAME[0]}"
}

test_no_running_tasks_global() {
  # Add "--detach=true" when there is no running tasks.
  # https://github.com/docker/cli/issues/627
  local IMAGE_WITH_TAG="${1}"
  local SERVICE_NAME SLEEP_SECONDS STDOUT
  SERVICE_NAME="gantry-test-$(unique_id)"
  SLEEP_SECONDS=15

  initialize_test "${FUNCNAME[0]}"
  build_and_push_test_image "${IMAGE_WITH_TAG}" "${SLEEP_SECONDS}"
  start_global_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
  # The tasks should exit after SLEEP_SECONDS seconds sleep. Then it will have 0 running tasks.
  wait_zero_running_tasks "${SERVICE_NAME}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"

  export GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  STDOUT=$(run_gantry "${FUNCNAME[0]}" 2>&1 | tee >(cat 1>&2))

  expect_message    "${STDOUT}" "${ADD_OPTION}.*--detach=true"
  # Cannot add "--replicas" to global
  expect_no_message "${STDOUT}" "${ADD_OPTION}.*--replicas=0"
  expect_no_message "${STDOUT}" "${SKIP_UPDATING_SERVICE}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_NEW_IMAGE}"
  expect_message    "${STDOUT}" "${SERVICE_NAME}.*${UPDATED}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_UPDATES}"
  expect_no_message "${STDOUT}" "${ROLLING_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${ROLLED_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${NO_SERVICES_UPDATED}"
  expect_message    "${STDOUT}" "${NUM_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NUM_SERVICES_UPDATE_FAILED}"
  expect_no_message "${STDOUT}" "${NO_IMAGES_TO_REMOVE}"
  expect_message    "${STDOUT}" "${REMOVING_NUM_IMAGES}"
  expect_no_message "${STDOUT}" "${SKIP_REMOVING_IMAGES}"
  expect_message    "${STDOUT}" "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
  expect_no_message "${STDOUT}" "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"

  stop_service "${SERVICE_NAME}"
  prune_local_test_image "${IMAGE_WITH_TAG}"
  finalize_test "${FUNCNAME[0]}"
}

test_rollback_due_to_timeout() {
  local IMAGE_WITH_TAG="${1}"
  local SERVICE_NAME STDOUT
  SERVICE_NAME="gantry-test-$(unique_id)"
  local LABEL="gantry.test"

  initialize_test "${FUNCNAME[0]}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_replicated_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  # Prune the local copy to force re-download the image.
  prune_local_test_image "${IMAGE_WITH_TAG}"
  docker system prune -f;

  export GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  # Assume service update won't be done within 1 second.
  export GANTRY_UPDATE_TIMEOUT_SECONDS=1
  # Add a label to increase the updating time.
  export GANTRY_UPDATE_OPTIONS="--label-add=${LABEL}=${SERVICE_NAME}"
  STDOUT=$(run_gantry "${FUNCNAME[0]}" 2>&1 | tee >(cat 1>&2))

  expect_no_message "${STDOUT}" "${SKIP_UPDATING_SERVICE}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_NEW_IMAGE}"
  expect_message    "${STDOUT}" "${ADD_OPTION}.*${GANTRY_UPDATE_OPTIONS}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${UPDATED}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_UPDATES}"
  expect_message    "${STDOUT}" "${ROLLING_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
  expect_message    "${STDOUT}" "${ROLLED_BACK}.*${SERVICE_NAME}"
  expect_message    "${STDOUT}" "${NO_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NUM_SERVICES_UPDATED}"
  expect_message    "${STDOUT}" "${NUM_SERVICES_UPDATE_FAILED}"
  expect_message    "${STDOUT}" "${NO_IMAGES_TO_REMOVE}"
  expect_no_message "${STDOUT}" "${REMOVING_NUM_IMAGES}"
  expect_no_message "${STDOUT}" "${SKIP_REMOVING_IMAGES}"
  expect_no_message "${STDOUT}" "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
  expect_no_message "${STDOUT}" "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"

  stop_service "${SERVICE_NAME}"
  prune_local_test_image "${IMAGE_WITH_TAG}"
  finalize_test "${FUNCNAME[0]}"
}

test_rollback_failed() {
  local IMAGE_WITH_TAG="${1}"
  local SERVICE_NAME STDOUT
  SERVICE_NAME="gantry-test-$(unique_id)"
  local LABEL="gantry.test"

  initialize_test "${FUNCNAME[0]}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_replicated_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  # Prune the local copy to force re-download the image.
  prune_local_test_image "${IMAGE_WITH_TAG}"
  docker system prune -f;

  export GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  # Assume service update won't be done within 1 second.
  export GANTRY_UPDATE_TIMEOUT_SECONDS=1
  export GANTRY_UPDATE_OPTIONS="--label-add=${LABEL}=${SERVICE_NAME}"
  # Rollback would fail due to the incorrect option.
  export GANTRY_ROLLBACK_OPTIONS="--incorrect-option"
  STDOUT=$(run_gantry "${FUNCNAME[0]}" 2>&1 | tee >(cat 1>&2))

  expect_no_message "${STDOUT}" "${SKIP_UPDATING_SERVICE}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_NEW_IMAGE}"
  expect_message    "${STDOUT}" "${ADD_OPTION}.*${GANTRY_UPDATE_OPTIONS}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${UPDATED}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_UPDATES}"
  expect_message    "${STDOUT}" "${ADD_OPTION}.*${GANTRY_ROLLBACK_OPTIONS}"
  expect_message    "${STDOUT}" "${ROLLING_BACK}.*${SERVICE_NAME}"
  expect_message    "${STDOUT}" "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${ROLLED_BACK}.*${SERVICE_NAME}"
  expect_message    "${STDOUT}" "${NO_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NUM_SERVICES_UPDATED}"
  expect_message    "${STDOUT}" "${NUM_SERVICES_UPDATE_FAILED}"
  expect_message    "${STDOUT}" "${NO_IMAGES_TO_REMOVE}"
  expect_no_message "${STDOUT}" "${REMOVING_NUM_IMAGES}"
  expect_no_message "${STDOUT}" "${SKIP_REMOVING_IMAGES}"
  expect_no_message "${STDOUT}" "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
  expect_no_message "${STDOUT}" "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"

  stop_service "${SERVICE_NAME}"
  prune_local_test_image "${IMAGE_WITH_TAG}"
  finalize_test "${FUNCNAME[0]}"
}

test_rollback_ROLLBACK_ON_FAILURE_false() {
  local IMAGE_WITH_TAG="${1}"
  local SERVICE_NAME STDOUT
  SERVICE_NAME="gantry-test-$(unique_id)"
  local LABEL="gantry.test"

  initialize_test "${FUNCNAME[0]}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_replicated_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  # Prune the local copy to force re-download the image.
  prune_local_test_image "${IMAGE_WITH_TAG}"
  docker system prune -f;

  export GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  # Assume service update won't be done within 1 second.
  export GANTRY_UPDATE_TIMEOUT_SECONDS=1
  export GANTRY_UPDATE_OPTIONS="--label-add=${LABEL}=${SERVICE_NAME}"
  export GANTRY_ROLLBACK_ON_FAILURE="false"
  STDOUT=$(run_gantry "${FUNCNAME[0]}" 2>&1 | tee >(cat 1>&2))

  expect_no_message "${STDOUT}" "${SKIP_UPDATING_SERVICE}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_NEW_IMAGE}"
  expect_message    "${STDOUT}" "${ADD_OPTION}.*${GANTRY_UPDATE_OPTIONS}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${UPDATED}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_UPDATES}"
  expect_no_message "${STDOUT}" "${ROLLING_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${ROLLED_BACK}.*${SERVICE_NAME}"
  expect_message    "${STDOUT}" "${NO_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NUM_SERVICES_UPDATED}"
  expect_message    "${STDOUT}" "${NUM_SERVICES_UPDATE_FAILED}"
  expect_message    "${STDOUT}" "${NO_IMAGES_TO_REMOVE}"
  expect_no_message "${STDOUT}" "${REMOVING_NUM_IMAGES}"
  expect_no_message "${STDOUT}" "${SKIP_REMOVING_IMAGES}"
  expect_no_message "${STDOUT}" "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
  expect_no_message "${STDOUT}" "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"

  stop_service "${SERVICE_NAME}"
  prune_local_test_image "${IMAGE_WITH_TAG}"
  finalize_test "${FUNCNAME[0]}"
}

test_options_LOG_LEVEL_none() {
  # Same as test_new_image_yes, except set LOG_LEVEL to NONE
  local IMAGE_WITH_TAG="${1}"
  local SERVICE_NAME STDOUT
  SERVICE_NAME="gantry-test-$(unique_id)"

  initialize_test "${FUNCNAME[0]}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_replicated_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"

  export GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  export GANTRY_LOG_LEVEL=NONE
  echo "Start running Gantry."
  STDOUT=$(run_gantry "${FUNCNAME[0]}" 2>&1 | tee >(cat 1>&2))

  expect_no_message "${STDOUT}" ".+"

  stop_service "${SERVICE_NAME}"
  prune_local_test_image "${IMAGE_WITH_TAG}"
  finalize_test "${FUNCNAME[0]}"
}

test_options_UPDATE_OPTIONS() {
  # Check an observable difference before and after applying UPDATE_OPTIONS.
  local IMAGE_WITH_TAG="${1}"
  local SERVICE_NAME STDOUT
  SERVICE_NAME="gantry-test-$(unique_id)"
  local LABEL="gantry.test"
  local LABEL_VALUE=

  initialize_test "${FUNCNAME[0]}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_replicated_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"

  LABEL_VALUE=$(read_service_label "${SERVICE_NAME}" "${LABEL}")
  expect_no_message "${LABEL_VALUE}" "${SERVICE_NAME}"

  export GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  export GANTRY_UPDATE_OPTIONS="--label-add=${LABEL}=${SERVICE_NAME}"
  STDOUT=$(run_gantry "${FUNCNAME[0]}" 2>&1 | tee >(cat 1>&2))

  LABEL_VALUE=$(read_service_label "${SERVICE_NAME}" "${LABEL}")
  expect_message    "${LABEL_VALUE}" "${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${SKIP_UPDATING_SERVICE}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_NEW_IMAGE}"
  expect_message    "${STDOUT}" "${ADD_OPTION}.*${GANTRY_UPDATE_OPTIONS}"
  expect_message    "${STDOUT}" "${SERVICE_NAME}.*${UPDATED}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_UPDATES}"
  expect_no_message "${STDOUT}" "${ROLLING_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${ROLLED_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${NO_SERVICES_UPDATED}"
  expect_message    "${STDOUT}" "${NUM_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NUM_SERVICES_UPDATE_FAILED}"
  expect_no_message "${STDOUT}" "${NO_IMAGES_TO_REMOVE}"
  expect_message    "${STDOUT}" "${REMOVING_NUM_IMAGES}"
  expect_no_message "${STDOUT}" "${SKIP_REMOVING_IMAGES}"
  expect_message    "${STDOUT}" "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
  expect_no_message "${STDOUT}" "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"

  stop_service "${SERVICE_NAME}"
  prune_local_test_image "${IMAGE_WITH_TAG}"
  finalize_test "${FUNCNAME[0]}"
}

test_options_PRE_POST_RUN_CMD() {
  local IMAGE_WITH_TAG="${1}"
  local SERVICE_NAME STDOUT
  SERVICE_NAME="gantry-test-$(unique_id)"

  initialize_test "${FUNCNAME[0]}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_replicated_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"

  export GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  export GANTRY_PRE_RUN_CMD="echo \"Pre update\""
  export GANTRY_POST_RUN_CMD="echo \"Post update\""
  STDOUT=$(run_gantry "${FUNCNAME[0]}" 2>&1 | tee >(cat 1>&2))

  expect_message    "${STDOUT}" "Pre update"
  expect_no_message "${STDOUT}" "${SKIP_UPDATING_SERVICE}.*${SERVICE_NAME}"
  expect_message    "${STDOUT}" "${SERVICE_NAME}.*${NO_NEW_IMAGE}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${UPDATED}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_UPDATES}"
  expect_no_message "${STDOUT}" "${ROLLING_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${ROLLED_BACK}.*${SERVICE_NAME}"
  expect_message    "${STDOUT}" "${NO_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NUM_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NUM_SERVICES_UPDATE_FAILED}"
  expect_message    "${STDOUT}" "${NO_IMAGES_TO_REMOVE}"
  expect_no_message "${STDOUT}" "${REMOVING_NUM_IMAGES}"
  expect_no_message "${STDOUT}" "${SKIP_REMOVING_IMAGES}"
  expect_no_message "${STDOUT}" "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
  expect_no_message "${STDOUT}" "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
  expect_message    "${STDOUT}" "Post update"

  stop_service "${SERVICE_NAME}"
  prune_local_test_image "${IMAGE_WITH_TAG}"
  finalize_test "${FUNCNAME[0]}"
}

test_CLEANUP_IMAGES_false() {
  local IMAGE_WITH_TAG="${1}"
  local SERVICE_NAME STDOUT
  SERVICE_NAME="gantry-test-$(unique_id)"

  initialize_test "${FUNCNAME[0]}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_replicated_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"

  export GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  export GANTRY_CLEANUP_IMAGES="false"
  STDOUT=$(run_gantry "${FUNCNAME[0]}" 2>&1 | tee >(cat 1>&2))

  expect_no_message "${STDOUT}" "${SKIP_UPDATING_SERVICE}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_NEW_IMAGE}"
  expect_message    "${STDOUT}" "${SERVICE_NAME}.*${UPDATED}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_UPDATES}"
  expect_no_message "${STDOUT}" "${ROLLING_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${ROLLED_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${NO_SERVICES_UPDATED}"
  expect_message    "${STDOUT}" "${NUM_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NUM_SERVICES_UPDATE_FAILED}"
  expect_no_message "${STDOUT}" "${NO_IMAGES_TO_REMOVE}"
  expect_no_message "${STDOUT}" "${REMOVING_NUM_IMAGES}"
  expect_message    "${STDOUT}" "${SKIP_REMOVING_IMAGES}"
  expect_no_message "${STDOUT}" "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
  expect_no_message "${STDOUT}" "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"

  stop_service "${SERVICE_NAME}"
  prune_local_test_image "${IMAGE_WITH_TAG}"
  finalize_test "${FUNCNAME[0]}"
}

test_CLEANUP_IMAGES_OPTIONS_bad() {
  local IMAGE_WITH_TAG="${1}"
  local SERVICE_NAME STDOUT
  SERVICE_NAME="gantry-test-$(unique_id)"

  initialize_test "${FUNCNAME[0]}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_replicated_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"

  export GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  export GANTRY_CLEANUP_IMAGES="true"
  # Image remover would fail due to the incorrect option.
  export GANTRY_CLEANUP_IMAGES_OPTIONS="--incorrect-option"
  STDOUT=$(run_gantry "${FUNCNAME[0]}" 2>&1 | tee >(cat 1>&2))

  expect_no_message "${STDOUT}" "${SKIP_UPDATING_SERVICE}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_NEW_IMAGE}"
  expect_message    "${STDOUT}" "${SERVICE_NAME}.*${UPDATED}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_UPDATES}"
  expect_no_message "${STDOUT}" "${ROLLING_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${ROLLED_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${NO_SERVICES_UPDATED}"
  expect_message    "${STDOUT}" "${NUM_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NUM_SERVICES_UPDATE_FAILED}"
  expect_no_message "${STDOUT}" "${NO_IMAGES_TO_REMOVE}"
  expect_message    "${STDOUT}" "${REMOVING_NUM_IMAGES}"
  expect_no_message "${STDOUT}" "${SKIP_REMOVING_IMAGES}"
  expect_message    "${STDOUT}" "${ADD_OPTION}.*${GANTRY_CLEANUP_IMAGES_OPTIONS}"
  expect_message    "${STDOUT}" "${FAILED_TO_REMOVE_IMAGE}.*${GANTRY_CLEANUP_IMAGES_OPTIONS}"
  expect_no_message "${STDOUT}" "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
  expect_no_message "${STDOUT}" "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"

  stop_service "${SERVICE_NAME}"
  prune_local_test_image "${IMAGE_WITH_TAG}"
  finalize_test "${FUNCNAME[0]}"
}

test_CLEANUP_IMAGES_OPTIONS_good() {
  local IMAGE_WITH_TAG="${1}"
  local SERVICE_NAME STDOUT
  SERVICE_NAME="gantry-test-$(unique_id)"

  initialize_test "${FUNCNAME[0]}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_replicated_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"

  export GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  export GANTRY_CLEANUP_IMAGES="true"
  export GANTRY_CLEANUP_IMAGES_OPTIONS="--container-label=test"
  STDOUT=$(run_gantry "${FUNCNAME[0]}" 2>&1 | tee >(cat 1>&2))

  expect_no_message "${STDOUT}" "${SKIP_UPDATING_SERVICE}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_NEW_IMAGE}"
  expect_message    "${STDOUT}" "${SERVICE_NAME}.*${UPDATED}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_UPDATES}"
  expect_no_message "${STDOUT}" "${ROLLING_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${ROLLED_BACK}.*${SERVICE_NAME}"
  expect_no_message "${STDOUT}" "${NO_SERVICES_UPDATED}"
  expect_message    "${STDOUT}" "${NUM_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NUM_SERVICES_UPDATE_FAILED}"
  expect_no_message "${STDOUT}" "${NO_IMAGES_TO_REMOVE}"
  expect_message    "${STDOUT}" "${REMOVING_NUM_IMAGES}"
  expect_no_message "${STDOUT}" "${SKIP_REMOVING_IMAGES}"
  expect_message    "${STDOUT}" "${ADD_OPTION}.*${GANTRY_CLEANUP_IMAGES_OPTIONS}"
  expect_no_message "${STDOUT}" "${FAILED_TO_REMOVE_IMAGE}.*${GANTRY_CLEANUP_IMAGES_OPTIONS}"
  expect_message    "${STDOUT}" "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
  expect_no_message "${STDOUT}" "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"

  stop_service "${SERVICE_NAME}"
  prune_local_test_image "${IMAGE_WITH_TAG}"
  finalize_test "${FUNCNAME[0]}"
}

