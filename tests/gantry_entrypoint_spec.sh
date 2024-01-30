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

Describe 'Entrypoint'
  SUITE_NAME="Entrypoint"
  BeforeAll "initialize_all_tests ${SUITE_NAME}"
  AfterAll "finish_all_tests ${SUITE_NAME}"
  Describe "test_SLEEP_SECONDS_not_a_number"
    TEST_NAME="test_SLEEP_SECONDS_not_a_number"
    IMAGE_WITH_TAG=$(get_image_with_tag)
    SERVICE_NAME="gantry-test-$(unique_id)"
    test_SLEEP_SECONDS_not_a_number() {
      local TEST_NAME=${1}
      export GANTRY_SLEEP_SECONDS="NotANumber"
      run_gantry "${TEST_NAME}"
    }
    Before "common_setup_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    After "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_gantry'
      When call test_SLEEP_SECONDS_not_a_number "${TEST_NAME}"
      The status should be failure
      The stdout should satisfy display_output
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_message    "GANTRY_SLEEP_SECONDS must be a number.*"
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING_JOB}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${PERFORM_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_NEW_IMAGE}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${UPDATED}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_UPDATES}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLING_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLED_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATE_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_no_message "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${SLEEP_SECONDS_BEFORE_NEXT_UPDATE}"
    End
  End
  Describe "test_IMAGES_TO_REMOVE_none_empty"
    # Test the remove image entrypoint. To improve coverage.
    TEST_NAME="test_IMAGES_TO_REMOVE_none_empty"
    IMAGE_WITH_TAG=$(get_image_with_tag)
    IMAGE_WITH_TAG0="${IMAGE_WITH_TAG}-0"
    IMAGE_WITH_TAG1="${IMAGE_WITH_TAG}-1"
    IMAGE_WITH_TAG2="${IMAGE_WITH_TAG}-2"
    SERVICE_NAME="gantry-test-$(unique_id)"
    SERVICE_NAME0="${SERVICE_NAME}-0"
    SERVICE_NAME1="${SERVICE_NAME}-1"
    test_start() {
      local TEST_NAME=${1}
      local IMAGE_WITH_TAG=${2}
      local SERVICE_NAME=${3}
      local IMAGE_WITH_TAG0="${IMAGE_WITH_TAG}-0"
      local IMAGE_WITH_TAG1="${IMAGE_WITH_TAG}-1"
      local IMAGE_WITH_TAG2="${IMAGE_WITH_TAG}-2"
      local SERVICE_NAME0="${SERVICE_NAME}-0"
      local SERVICE_NAME1="${SERVICE_NAME}-1"
      local TASK_SECONDS=15
      initialize_test "${TEST_NAME}"
      # The task will finish in ${TASK_SECONDS} seconds
      build_and_push_test_image "${IMAGE_WITH_TAG0}" "${TASK_SECONDS}"
      start_global_service "${SERVICE_NAME0}" "${IMAGE_WITH_TAG0}"
      build_and_push_test_image "${IMAGE_WITH_TAG1}"
      start_global_service "${SERVICE_NAME1}" "${IMAGE_WITH_TAG1}"
      # The tasks should exit after TASK_SECONDS seconds sleep. Then it will have 0 running tasks.
      wait_zero_running_tasks "${SERVICE_NAME0}"
      # Do not creat the Image IMAGE_WITH_TAG2, to run the test on a non-exist image.
      export GANTRY_IMAGES_TO_REMOVE="${IMAGE_WITH_TAG0} ${IMAGE_WITH_TAG1} ${IMAGE_WITH_TAG2}"
    }
    test_end() {
      local TEST_NAME=${1}
      local IMAGE_WITH_TAG=${2}
      local SERVICE_NAME=${3}
      local IMAGE_WITH_TAG0="${IMAGE_WITH_TAG}-0"
      local IMAGE_WITH_TAG1="${IMAGE_WITH_TAG}-1"
      local SERVICE_NAME0="${SERVICE_NAME}-0"
      local SERVICE_NAME1="${SERVICE_NAME}-1"
      stop_service "${SERVICE_NAME0}"
      stop_service "${SERVICE_NAME1}"
      # If run successfully, IMAGE_WITH_TAG0 should already be removed.
      prune_local_test_image "${IMAGE_WITH_TAG0}" 2>&1
      prune_local_test_image "${IMAGE_WITH_TAG1}"
      finalize_test "${TEST_NAME}"
    }
    Before "test_start ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    After "test_end ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_gantry'
      When call run_gantry "${TEST_NAME}"
      The status should be success
      The stdout should satisfy display_output
      The stdout should satisfy spec_expect_message "Removed exited container.*${SERVICE_NAME0}.*${IMAGE_WITH_TAG0}"
      The stdout should satisfy spec_expect_message "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG0}"
      The stdout should satisfy spec_expect_message "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG1}"
      The stdout should satisfy spec_expect_message "There is no image.*${IMAGE_WITH_TAG2}"
      The stderr should satisfy display_output
    End
  End
End # Describe 'Single service'
