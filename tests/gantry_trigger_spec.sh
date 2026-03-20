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

export ALREADY_TIMES_UP="Already times up. Run next update."
export SLEEP_SECONDS_BEFORE_NEXT_UPDATE="Sleep [0-9]+ seconds before next update"
export FOUND_CHANGES_IN="Found changes in"
export RUNNING_SCHEDULED_UPDATE="Running scheduled update."

# Assume that the inspect will be done within the following time.
# Set the value based on the tests on github action, while many tests are running in parallel.
export SLEEP_SECONDS=10

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
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_INSPECT_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_ROLLBACK_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_ERRORS}"
      The stderr should satisfy spec_expect_no_message "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_no_message "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${DONE_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${SCHEDULE_NEXT_UPDATE_AT}"
      The stderr should satisfy spec_expect_no_message "${ALREADY_TIMES_UP}"
      The stderr should satisfy spec_expect_no_message "${SLEEP_SECONDS_BEFORE_NEXT_UPDATE}"
      The stderr should satisfy spec_expect_no_message "${WATCH_CHANGES_IN}"
      The stderr should satisfy spec_expect_no_message "${FOUND_CHANGES_IN}"
      The stderr should satisfy spec_expect_no_message "${RUNNING_SCHEDULED_UPDATE}"
    End
  End
  Describe "test_trigger_TRIGGER_PATH_only"
    TEST_NAME="test_trigger_TRIGGER_PATH_only"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    test_trigger_TRIGGER_PATH_only() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      local TRIGGER_PATH=
      TRIGGER_PATH=$(get_config_name)
      mkdir -p "${TRIGGER_PATH}"
      chmod 777 "${TRIGGER_PATH}"
      local TRIGGER_FILE="${TRIGGER_PATH}/trigger_file"
      reset_gantry_env "${SUITE_NAME}" "${SERVICE_NAME}"
      export GANTRY_TEST_HOST_TO_CONTAINER="${TRIGGER_PATH}"
      export GANTRY_SLEEP_SECONDS="0"
      export GANTRY_TRIGGER_PATH="${TRIGGER_PATH}"
      # Use GANTRY_POST_RUN_CMD to indicate that update is done.
      export GANTRY_POST_RUN_CMD="if [ -e \"${TRIGGER_PATH}/done0\" ]; then touch \"${TRIGGER_PATH}/done1\"; else touch \"${TRIGGER_PATH}/done0\"; fi; chmod -R 777 \"${TRIGGER_PATH}\";"
      # Run run_gantry in background.
      run_gantry "${SUITE_NAME}" "${TEST_NAME}" &
      local PID="${!}"
      while [ ! -e "${TRIGGER_PATH}/done0" ]; do sleep 1; done
      while [ ! -e "${TRIGGER_PATH}/done1" ]; do
        touch "${TRIGGER_FILE}"
        sleep 1;
      done
      stop_gantry_container "${TEST_NAME}"
      kill "${PID}"
      rm -r "${TRIGGER_PATH}"
    }
    BeforeEach "common_setup_no_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_trigger_TRIGGER_PATH_only "${TEST_NAME}" "${SERVICE_NAME}"
      The status should be success
      The stdout should satisfy display_output
      The stdout should satisfy spec_expect_no_message ".+"
      The stderr should satisfy display_output
      # Do not check START_WITHOUT_A_SQUARE_BRACKET because the kill command could cause a "Broken pipe" error.
      # The stderr should satisfy spec_expect_no_message "${START_WITHOUT_A_SQUARE_BRACKET}"
      The stderr should satisfy spec_expect_multiple_messages "${SKIP_UPDATING}.*${SERVICE_NAME}.*${SKIP_REASON_CURRENT_IS_LATEST}"
      The stderr should satisfy spec_expect_no_message "${PERFORM_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_SKIP_JOBS}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_INSPECT_FAILURE}"
      The stderr should satisfy spec_expect_multiple_messages "${NUM_SERVICES_NO_NEW_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATING}"
      The stderr should satisfy spec_expect_no_message "${ADDING_OPTIONS}"
      The stderr should satisfy spec_expect_no_message "${UPDATED}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_UPDATES}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLING_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLED_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_multiple_messages "${NO_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATE_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_INSPECT_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_ROLLBACK_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_ERRORS}"
      The stderr should satisfy spec_expect_multiple_messages "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_no_message "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${DONE_REMOVING_IMAGES}"
      # Check messages between iterations.
      The stderr should satisfy spec_expect_no_message "${SCHEDULE_NEXT_UPDATE_AT}"
      The stderr should satisfy spec_expect_no_message "${ALREADY_TIMES_UP}"
      The stderr should satisfy spec_expect_no_message "${SLEEP_SECONDS_BEFORE_NEXT_UPDATE}"
      The stderr should satisfy spec_expect_message    "${WATCH_CHANGES_IN}"
      The stderr should satisfy spec_expect_message    "${FOUND_CHANGES_IN}"
      The stderr should satisfy spec_expect_no_message "${RUNNING_SCHEDULED_UPDATE}"
    End
  End
  Describe "test_trigger_both_path_and_timer_by_path"
    TEST_NAME="test_trigger_both_path_and_timer_by_path"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    test_trigger_both_path_and_timer_by_path() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      local TRIGGER_PATH=
      TRIGGER_PATH=$(get_config_name)
      mkdir -p "${TRIGGER_PATH}"
      chmod 777 "${TRIGGER_PATH}"
      local TRIGGER_FILE="${TRIGGER_PATH}/trigger_file"
      reset_gantry_env "${SUITE_NAME}" "${SERVICE_NAME}"
      export GANTRY_TEST_HOST_TO_CONTAINER="${TRIGGER_PATH}"
      export GANTRY_SLEEP_SECONDS=$((SLEEP_SECONDS*10))
      export GANTRY_TRIGGER_PATH="${TRIGGER_PATH}"
      # Use GANTRY_POST_RUN_CMD to indicate that update is done.
      export GANTRY_POST_RUN_CMD="if [ -e \"${TRIGGER_PATH}/done0\" ]; then touch \"${TRIGGER_PATH}/done1\"; else touch \"${TRIGGER_PATH}/done0\"; fi; chmod -R 777 \"${TRIGGER_PATH}\";"
      # Run run_gantry in background.
      run_gantry "${SUITE_NAME}" "${TEST_NAME}" &
      local PID="${!}"
      while [ ! -e "${TRIGGER_PATH}/done0" ]; do sleep 1; done
      while [ ! -e "${TRIGGER_PATH}/done1" ]; do
        touch "${TRIGGER_FILE}"
        sleep 1;
      done
      stop_gantry_container "${TEST_NAME}"
      kill "${PID}"
      rm -r "${TRIGGER_PATH}"
    }
    BeforeEach "common_setup_no_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_trigger_both_path_and_timer_by_path "${TEST_NAME}" "${SERVICE_NAME}"
      The status should be success
      The stdout should satisfy display_output
      The stdout should satisfy spec_expect_no_message ".+"
      The stderr should satisfy display_output
      # Do not check START_WITHOUT_A_SQUARE_BRACKET because the kill command could cause a "Broken pipe" error.
      # The stderr should satisfy spec_expect_no_message "${START_WITHOUT_A_SQUARE_BRACKET}"
      The stderr should satisfy spec_expect_multiple_messages "${SKIP_UPDATING}.*${SERVICE_NAME}.*${SKIP_REASON_CURRENT_IS_LATEST}"
      The stderr should satisfy spec_expect_no_message "${PERFORM_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_SKIP_JOBS}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_INSPECT_FAILURE}"
      The stderr should satisfy spec_expect_multiple_messages "${NUM_SERVICES_NO_NEW_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATING}"
      The stderr should satisfy spec_expect_no_message "${ADDING_OPTIONS}"
      The stderr should satisfy spec_expect_no_message "${UPDATED}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_UPDATES}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLING_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLED_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_multiple_messages "${NO_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATE_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_INSPECT_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_ROLLBACK_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_ERRORS}"
      The stderr should satisfy spec_expect_multiple_messages "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_no_message "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${DONE_REMOVING_IMAGES}"
      # Check messages between iterations.
      The stderr should satisfy spec_expect_message    "${SCHEDULE_NEXT_UPDATE_AT}"
      The stderr should satisfy spec_expect_no_message "${ALREADY_TIMES_UP}"
      The stderr should satisfy spec_expect_message    "${SLEEP_SECONDS_BEFORE_NEXT_UPDATE}"
      The stderr should satisfy spec_expect_message    "${WATCH_CHANGES_IN}"
      The stderr should satisfy spec_expect_message    "${FOUND_CHANGES_IN}"
      The stderr should satisfy spec_expect_no_message "${RUNNING_SCHEDULED_UPDATE}"
    End
  End
  Describe "test_trigger_both_path_and_timer_by_timer"
    TEST_NAME="test_trigger_both_path_and_timer_by_timer"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    test_trigger_both_path_and_timer_by_timer() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      local TRIGGER_PATH=
      TRIGGER_PATH=$(get_config_name)
      mkdir -p "${TRIGGER_PATH}"
      chmod 777 "${TRIGGER_PATH}"
      reset_gantry_env "${SUITE_NAME}" "${SERVICE_NAME}"
      export GANTRY_TEST_HOST_TO_CONTAINER="${TRIGGER_PATH}"
      export GANTRY_SLEEP_SECONDS="${SLEEP_SECONDS}"
      export GANTRY_TRIGGER_PATH="${TRIGGER_PATH}"
      # Use GANTRY_POST_RUN_CMD to indicate that update is done.
      export GANTRY_POST_RUN_CMD="if [ -e \"${TRIGGER_PATH}/done0\" ]; then touch \"${TRIGGER_PATH}/done1\"; else touch \"${TRIGGER_PATH}/done0\"; fi; chmod -R 777 \"${TRIGGER_PATH}\";"
      # Run run_gantry in background.
      run_gantry "${SUITE_NAME}" "${TEST_NAME}" &
      local PID="${!}"
      while [ ! -e "${TRIGGER_PATH}/done1" ]; do sleep 1; done
      stop_gantry_container "${TEST_NAME}"
      kill "${PID}"
      rm -r "${TRIGGER_PATH}"
    }
    BeforeEach "common_setup_no_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_trigger_both_path_and_timer_by_timer "${TEST_NAME}" "${SERVICE_NAME}"
      The status should be success
      The stdout should satisfy display_output
      The stdout should satisfy spec_expect_no_message ".+"
      The stderr should satisfy display_output
      # Do not check START_WITHOUT_A_SQUARE_BRACKET because the kill command could cause a "Broken pipe" error.
      # The stderr should satisfy spec_expect_no_message "${START_WITHOUT_A_SQUARE_BRACKET}"
      The stderr should satisfy spec_expect_multiple_messages "${SKIP_UPDATING}.*${SERVICE_NAME}.*${SKIP_REASON_CURRENT_IS_LATEST}"
      The stderr should satisfy spec_expect_no_message "${PERFORM_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_SKIP_JOBS}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_INSPECT_FAILURE}"
      The stderr should satisfy spec_expect_multiple_messages "${NUM_SERVICES_NO_NEW_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATING}"
      The stderr should satisfy spec_expect_no_message "${ADDING_OPTIONS}"
      The stderr should satisfy spec_expect_no_message "${UPDATED}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_UPDATES}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLING_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLED_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_multiple_messages "${NO_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATE_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_INSPECT_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_ROLLBACK_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_ERRORS}"
      The stderr should satisfy spec_expect_multiple_messages "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_no_message "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${DONE_REMOVING_IMAGES}"
      # Check messages between iterations.
      The stderr should satisfy spec_expect_message    "${SCHEDULE_NEXT_UPDATE_AT}"
      The stderr should satisfy spec_expect_no_message "${ALREADY_TIMES_UP}"
      The stderr should satisfy spec_expect_message    "${SLEEP_SECONDS_BEFORE_NEXT_UPDATE}"
      The stderr should satisfy spec_expect_message    "${WATCH_CHANGES_IN}"
      The stderr should satisfy spec_expect_no_message "${FOUND_CHANGES_IN}"
      The stderr should satisfy spec_expect_message    "${RUNNING_SCHEDULED_UPDATE}"
    End
  End
  Describe "test_trigger_SLEEP_SECONDS"
    TEST_NAME="test_trigger_SLEEP_SECONDS"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    test_trigger_SLEEP_SECONDS() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      local TRIGGER_PATH=
      TRIGGER_PATH=$(get_config_name)
      mkdir -p "${TRIGGER_PATH}"
      chmod 777 "${TRIGGER_PATH}"
      reset_gantry_env "${SUITE_NAME}" "${SERVICE_NAME}"
      export GANTRY_TEST_HOST_TO_CONTAINER="${TRIGGER_PATH}"
      export GANTRY_SLEEP_SECONDS="${SLEEP_SECONDS}"
      # Use GANTRY_POST_RUN_CMD to indicate that update is done.
      export GANTRY_POST_RUN_CMD="if [ -e \"${TRIGGER_PATH}/done0\" ]; then touch \"${TRIGGER_PATH}/done1\"; else touch \"${TRIGGER_PATH}/done0\"; fi; chmod -R 777 \"${TRIGGER_PATH}\";"
      # Run run_gantry in background.
      run_gantry "${SUITE_NAME}" "${TEST_NAME}" &
      local PID="${!}"
      while [ ! -e "${TRIGGER_PATH}/done1" ]; do sleep 1; done
      stop_gantry_container "${TEST_NAME}"
      kill "${PID}"
      rm -r "${TRIGGER_PATH}"
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
      The stderr should satisfy spec_expect_no_message "${PERFORM_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_SKIP_JOBS}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_INSPECT_FAILURE}"
      The stderr should satisfy spec_expect_multiple_messages "${NUM_SERVICES_NO_NEW_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATING}"
      The stderr should satisfy spec_expect_no_message "${ADDING_OPTIONS}"
      The stderr should satisfy spec_expect_no_message "${UPDATED}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_UPDATES}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLING_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLED_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_multiple_messages "${NO_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATE_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_INSPECT_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_ROLLBACK_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_ERRORS}"
      The stderr should satisfy spec_expect_multiple_messages "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_no_message "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${DONE_REMOVING_IMAGES}"
      # Check messages between iterations.
      The stderr should satisfy spec_expect_message    "${SCHEDULE_NEXT_UPDATE_AT}"
      The stderr should satisfy spec_expect_no_message "${ALREADY_TIMES_UP}"
      The stderr should satisfy spec_expect_message    "${SLEEP_SECONDS_BEFORE_NEXT_UPDATE}"
      The stderr should satisfy spec_expect_no_message "${WATCH_CHANGES_IN}"
      The stderr should satisfy spec_expect_no_message "${FOUND_CHANGES_IN}"
      The stderr should satisfy spec_expect_no_message "${RUNNING_SCHEDULED_UPDATE}"
    End
  End
  Describe "test_trigger_SLEEP_SECONDS_small"
    TEST_NAME="test_trigger_SLEEP_SECONDS_small"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    test_trigger_SLEEP_SECONDS_small() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      local TRIGGER_PATH=
      TRIGGER_PATH=$(get_config_name)
      mkdir -p "${TRIGGER_PATH}"
      chmod 777 "${TRIGGER_PATH}"
      reset_gantry_env "${SUITE_NAME}" "${SERVICE_NAME}"
      export GANTRY_TEST_HOST_TO_CONTAINER="${TRIGGER_PATH}"
      export GANTRY_SLEEP_SECONDS="1"
      # Use GANTRY_POST_RUN_CMD to indicate that update is done.
      export GANTRY_POST_RUN_CMD="if [ -e \"${TRIGGER_PATH}/done0\" ]; then touch \"${TRIGGER_PATH}/done1\"; else touch \"${TRIGGER_PATH}/done0\"; fi; chmod -R 777 \"${TRIGGER_PATH}\";"
      # Run run_gantry in background.
      run_gantry "${SUITE_NAME}" "${TEST_NAME}" &
      local PID="${!}"
      while [ ! -e "${TRIGGER_PATH}/done1" ]; do sleep 1; done
      stop_gantry_container "${TEST_NAME}"
      kill "${PID}"
      rm -r "${TRIGGER_PATH}"
    }
    BeforeEach "common_setup_no_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_trigger_SLEEP_SECONDS_small "${TEST_NAME}" "${SERVICE_NAME}"
      The status should be success
      The stdout should satisfy display_output
      The stdout should satisfy spec_expect_no_message ".+"
      The stderr should satisfy display_output
      # Do not check START_WITHOUT_A_SQUARE_BRACKET because the kill command could cause a "Broken pipe" error.
      # The stderr should satisfy spec_expect_no_message "${START_WITHOUT_A_SQUARE_BRACKET}"
      The stderr should satisfy spec_expect_multiple_messages "${SKIP_UPDATING}.*${SERVICE_NAME}.*${SKIP_REASON_CURRENT_IS_LATEST}"
      The stderr should satisfy spec_expect_no_message "${PERFORM_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_SKIP_JOBS}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_INSPECT_FAILURE}"
      The stderr should satisfy spec_expect_multiple_messages "${NUM_SERVICES_NO_NEW_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATING}"
      The stderr should satisfy spec_expect_no_message "${ADDING_OPTIONS}"
      The stderr should satisfy spec_expect_no_message "${UPDATED}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_UPDATES}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLING_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLED_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_multiple_messages "${NO_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATE_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_INSPECT_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_ROLLBACK_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_ERRORS}"
      The stderr should satisfy spec_expect_multiple_messages "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_no_message "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${DONE_REMOVING_IMAGES}"
      # Check messages between iterations.
      The stderr should satisfy spec_expect_message    "${SCHEDULE_NEXT_UPDATE_AT}"
      The stderr should satisfy spec_expect_message    "${ALREADY_TIMES_UP}"
      The stderr should satisfy spec_expect_no_message "${SLEEP_SECONDS_BEFORE_NEXT_UPDATE}"
      The stderr should satisfy spec_expect_no_message "${WATCH_CHANGES_IN}"
      The stderr should satisfy spec_expect_no_message "${FOUND_CHANGES_IN}"
      The stderr should satisfy spec_expect_no_message "${RUNNING_SCHEDULED_UPDATE}"
    End
  End
End # Describe 'Single service'
