#!/bin/bash spellspec
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

# Test cleanup images related options.
Describe 'cleanup-images'
  SUITE_NAME="cleanup-images"
  BeforeAll "initialize_all_tests ${SUITE_NAME}"
  AfterAll "finish_all_tests ${SUITE_NAME}"
  Describe "test_CLEANUP_IMAGES_false"
    TEST_NAME="test_CLEANUP_IMAGES_false"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    test_CLEANUP_IMAGES_false() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      reset_gantry_env "${SUITE_NAME}" "${SERVICE_NAME}"
      export GANTRY_CLEANUP_IMAGES="false"
      run_gantry "${SUITE_NAME}" "${TEST_NAME}"
    }
    BeforeEach "common_setup_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_CLEANUP_IMAGES_false "${TEST_NAME}" "${SERVICE_NAME}"
      The status should be success
      The stdout should satisfy display_output
      The stdout should satisfy spec_expect_no_message ".+"
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_no_message "${START_WITHOUT_A_SQUARE_BRACKET}"
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${PERFORM_UPDATING}.*${SERVICE_NAME}.*${PERFORM_REASON_HAS_NEWER_IMAGE}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_SKIP_JOBS}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_INSPECT_FAILURE}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_NO_NEW_IMAGES}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_UPDATING}"
      The stderr should satisfy spec_expect_message    "${UPDATED}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_UPDATES}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLING_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLED_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_message    "1 ${SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATE_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_ERRORS}"
      The stderr should satisfy spec_expect_no_message "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_no_message "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_message    "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${DONE_REMOVING_IMAGES}"
    End
  End
  Describe "test_CLEANUP_IMAGES_OPTIONS_bad"
    TEST_NAME="test_CLEANUP_IMAGES_OPTIONS_bad"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    test_CLEANUP_IMAGES_OPTIONS_bad() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      reset_gantry_env "${SUITE_NAME}" "${SERVICE_NAME}"
      export GANTRY_CLEANUP_IMAGES="true"
      # Image remover would fail due to the incorrect option.
      export GANTRY_CLEANUP_IMAGES_OPTIONS="--incorrect-option"
      run_gantry "${SUITE_NAME}" "${TEST_NAME}"
    }
    BeforeEach "common_setup_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_CLEANUP_IMAGES_OPTIONS_bad "${TEST_NAME}" "${SERVICE_NAME}"
      The status should be success
      The stdout should satisfy display_output
      The stdout should satisfy spec_expect_no_message ".+"
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_no_message "${START_WITHOUT_A_SQUARE_BRACKET}"
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${PERFORM_UPDATING}.*${SERVICE_NAME}.*${PERFORM_REASON_HAS_NEWER_IMAGE}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_SKIP_JOBS}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_INSPECT_FAILURE}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_NO_NEW_IMAGES}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_UPDATING}"
      The stderr should satisfy spec_expect_message    "${UPDATED}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_UPDATES}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLING_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLED_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_message    "1 ${SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATE_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_ERRORS}"
      The stderr should satisfy spec_expect_no_message "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_message    "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_message    "${ADDING_OPTIONS}.*--incorrect-option.*"
      The stderr should satisfy spec_expect_message    "Failed.*--incorrect-option"
      The stderr should satisfy spec_expect_no_message "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${DONE_REMOVING_IMAGES}"
    End
  End
  Describe "test_CLEANUP_IMAGES_OPTIONS_good"
    TEST_NAME="test_CLEANUP_IMAGES_OPTIONS_good"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    test_CLEANUP_IMAGES_OPTIONS_good() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      reset_gantry_env "${SUITE_NAME}" "${SERVICE_NAME}"
      export GANTRY_CLEANUP_IMAGES="true"
      export GANTRY_CLEANUP_IMAGES_OPTIONS="--container-label=test"
      run_gantry "${SUITE_NAME}" "${TEST_NAME}"
    }
    BeforeEach "common_setup_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_CLEANUP_IMAGES_OPTIONS_good "${TEST_NAME}" "${SERVICE_NAME}"
      The status should be success
      The stdout should satisfy display_output
      The stdout should satisfy spec_expect_no_message ".+"
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_no_message "${START_WITHOUT_A_SQUARE_BRACKET}"
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${PERFORM_UPDATING}.*${SERVICE_NAME}.*${PERFORM_REASON_HAS_NEWER_IMAGE}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_SKIP_JOBS}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_INSPECT_FAILURE}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_NO_NEW_IMAGES}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_UPDATING}"
      The stderr should satisfy spec_expect_message    "${UPDATED}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_UPDATES}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLING_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLED_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_message    "1 ${SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATE_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_ERRORS}"
      The stderr should satisfy spec_expect_no_message "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_message    "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_message    "${ADDING_OPTIONS}.*--container-label=test.*"
      The stderr should satisfy spec_expect_no_message "Failed.*--container-label=test"
      The stderr should satisfy spec_expect_message    "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_message    "${DONE_REMOVING_IMAGES}"
    End
  End
  Describe "test_IMAGES_TO_REMOVE_none_empty"
    # Test the remove image entrypoint. To improve coverage.
    TEST_NAME="test_IMAGES_TO_REMOVE_none_empty"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    IMAGE_WITH_TAG0="${IMAGE_WITH_TAG}-0"
    IMAGE_WITH_TAG1="${IMAGE_WITH_TAG}-1"
    IMAGE_WITH_TAG2="${IMAGE_WITH_TAG}-2"
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    SERVICE_NAME0="${SERVICE_NAME}-0"
    SERVICE_NAME1="${SERVICE_NAME}-1"
    test_start() {
      local TEST_NAME="${1}"
      local IMAGE_WITH_TAG="${2}"
      local SERVICE_NAME="${3}"
      local IMAGE_WITH_TAG0="${IMAGE_WITH_TAG}-0"
      local IMAGE_WITH_TAG1="${IMAGE_WITH_TAG}-1"
      local IMAGE_WITH_TAG2="${IMAGE_WITH_TAG}-2"
      local SERVICE_NAME0="${SERVICE_NAME}-0"
      local SERVICE_NAME1="${SERVICE_NAME}-1"
      local TASK_SECONDS=15
      local TIMEOUT_SECONDS=1
      initialize_test "${TEST_NAME}"
      # The task will finish in ${TASK_SECONDS} seconds
      build_and_push_test_image "${IMAGE_WITH_TAG0}" "${TASK_SECONDS}"
      start_global_service "${SERVICE_NAME0}" "${IMAGE_WITH_TAG0}" "${TIMEOUT_SECONDS}"
      build_and_push_test_image "${IMAGE_WITH_TAG1}"
      start_global_service "${SERVICE_NAME1}" "${IMAGE_WITH_TAG1}" "${TIMEOUT_SECONDS}"
      # The tasks should exit after TASK_SECONDS seconds sleep. Then it will have 0 running tasks.
      wait_zero_running_tasks "${SERVICE_NAME0}"
      # Do not creat the Image IMAGE_WITH_TAG2, to run the test on a non-exist image.
    }
    test_IMAGES_TO_REMOVE_none_empty() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      local IMAGE_WITH_TAG="${3}"
      local IMAGE_WITH_TAG0="${IMAGE_WITH_TAG}-0"
      local IMAGE_WITH_TAG1="${IMAGE_WITH_TAG}-1"
      local IMAGE_WITH_TAG2="${IMAGE_WITH_TAG}-2"
      reset_gantry_env "${SUITE_NAME}" "${SERVICE_NAME}"
      export GANTRY_IMAGES_TO_REMOVE="${IMAGE_WITH_TAG0} ${IMAGE_WITH_TAG1} ${IMAGE_WITH_TAG2}"
      run_gantry "${SUITE_NAME}" "${TEST_NAME}"
    }
    test_end() {
      local TEST_NAME="${1}"
      local IMAGE_WITH_TAG="${2}"
      local SERVICE_NAME="${3}"
      local IMAGE_WITH_TAG0="${IMAGE_WITH_TAG}-0"
      local IMAGE_WITH_TAG1="${IMAGE_WITH_TAG}-1"
      stop_multiple_services "${SERVICE_NAME}" 0 1
      # If run successfully, IMAGE_WITH_TAG0 should already be removed.
      prune_local_test_image "${IMAGE_WITH_TAG0}" 2>&1
      prune_local_test_image "${IMAGE_WITH_TAG1}"
      finalize_test "${TEST_NAME}"
    }
    BeforeEach "test_start ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "test_end ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_IMAGES_TO_REMOVE_none_empty "${TEST_NAME}" "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
      The status should be success
      The stdout should satisfy display_output
      The stdout should satisfy spec_expect_no_message ".+"
      The stderr should satisfy display_output
      # It should not use the log function from the lib-common, the messages do not start with "[".
      The stderr should satisfy spec_expect_no_message "^((?:\x1b\[[0-9;]*[mG])?\[)"
      The stderr should satisfy spec_expect_message    "Removed exited container.*${SERVICE_NAME0}.*${IMAGE_WITH_TAG0}"
      The stderr should satisfy spec_expect_message    "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG0}"
      The stderr should satisfy spec_expect_message    "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG1}"
      The stderr should satisfy spec_expect_message    "There is no image.*${IMAGE_WITH_TAG2}"
      The stderr should satisfy spec_expect_message    "${DONE_REMOVING_IMAGES}"
    End
  End
End # Describe 'Single service'
