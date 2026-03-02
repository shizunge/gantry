#!/bin/bash spellspec
# Copyright (C) 2024-2026 Shizun Ge
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

Describe 'trigger'
  SUITE_NAME="trigger"
  BeforeAll "initialize_all_tests ${SUITE_NAME}"
  AfterAll "finish_all_tests ${SUITE_NAME}"
  Describe "test_trigger_SLEEP_SECONDS_not_a_number"
    TEST_NAME="test_trigger_SLEEP_SECONDS_not_a_number"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    test_trigger_SLEEP_SECONDS_not_a_number() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      reset_gantry_env "${SUITE_NAME}" "${SERVICE_NAME}"
      export GANTRY_SLEEP_SECONDS="NotANumber"
      run_gantry "${SUITE_NAME}" "${TEST_NAME}"
    }
    BeforeEach "common_setup_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_trigger_SLEEP_SECONDS_not_a_number "${TEST_NAME}" "${SERVICE_NAME}"
      The status should be failure
      The stdout should satisfy display_output
      The stdout should satisfy spec_expect_no_message ".+"
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_no_message "${START_WITHOUT_A_SQUARE_BRACKET}"
      The stderr should satisfy spec_expect_message    "GANTRY_SLEEP_SECONDS ${MUST_BE_A_NUMBER}.*"
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING_ALL}"
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${PERFORM_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_SKIP_JOBS}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_INSPECT_FAILURE}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_NO_NEW_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATING}"
      The stderr should satisfy spec_expect_no_message "${UPDATED}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_UPDATES}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLING_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLED_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATE_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_ERRORS}"
      The stderr should satisfy spec_expect_no_message "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_no_message "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${DONE_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${SCHEDULE_NEXT_UPDATE_AT}"
      The stderr should satisfy spec_expect_no_message "${SLEEP_SECONDS_BEFORE_NEXT_UPDATE}"
    End
  End
  Describe "test_trigger_SLEEP_SECONDS"
    TEST_NAME="test_trigger_SLEEP_SECONDS"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    test_trigger_SLEEP_SECONDS() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      reset_gantry_env "${SUITE_NAME}" "${SERVICE_NAME}"
      # Assume that the inspect will be done within the following time.
      # Based on the tests on github action, it could take 10 seconds to just finish the filter services.
      # Then it could takes another 15 seconds to finish inspection due the many tests are running in parallel.
      export GANTRY_SLEEP_SECONDS="25"
      # Run run_gantry in background.
      run_gantry "${SUITE_NAME}" "${TEST_NAME}" &
      local PID="${!}"
      sleep $((GANTRY_SLEEP_SECONDS*3+1))
      stop_gantry_container "${TEST_NAME}"
      kill "${PID}"
    }
    BeforeEach "common_setup_no_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_trigger_SLEEP_SECONDS "${TEST_NAME}" "${SERVICE_NAME}"
      The status should be success
      The stdout should satisfy display_output
      The stdout should satisfy spec_expect_no_message ".+"
      The stderr should satisfy display_output
      # Do not check START_WITHOUT_A_SQUARE_BRACKET because the kill command could cause a "Broken pipe" error.
      # The stderr should satisfy spec_expect_no_message "${START_WITHOUT_A_SQUARE_BRACKET}"
      The stderr should satisfy spec_expect_multiple_messages "${SKIP_UPDATING}.*${SERVICE_NAME}.*${SKIP_REASON_CURRENT_IS_LATEST}"
      The stderr should satisfy spec_expect_no_message        "${PERFORM_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message        "${NUM_SERVICES_SKIP_JOBS}"
      The stderr should satisfy spec_expect_no_message        "${NUM_SERVICES_INSPECT_FAILURE}"
      The stderr should satisfy spec_expect_multiple_messages "${NUM_SERVICES_NO_NEW_IMAGES}"
      The stderr should satisfy spec_expect_no_message        "${NUM_SERVICES_UPDATING}"
      The stderr should satisfy spec_expect_no_message        "${ADDING_OPTIONS}"
      The stderr should satisfy spec_expect_no_message        "${UPDATED}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message        "${NO_UPDATES}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message        "${ROLLING_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message        "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message        "${ROLLED_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_multiple_messages "${NO_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message        "${NUM_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message        "${NUM_SERVICES_UPDATE_FAILED}"
      The stderr should satisfy spec_expect_no_message        "${NUM_SERVICES_ERRORS}"
      The stderr should satisfy spec_expect_multiple_messages "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_no_message        "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_no_message        "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_no_message        "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message        "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message        "${DONE_REMOVING_IMAGES}"
      # Check messages between iterations.
      The stderr should satisfy spec_expect_message           "${SCHEDULE_NEXT_UPDATE_AT}"
      The stderr should satisfy spec_expect_message           "${SLEEP_SECONDS_BEFORE_NEXT_UPDATE}"
    End
  End
End # Describe 'Single service'
