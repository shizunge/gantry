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

Describe 'common-options'
  SUITE_NAME="common-options"
  BeforeAll "initialize_all_tests ${SUITE_NAME}"
  AfterAll "finish_all_tests ${SUITE_NAME}"
  Describe "test_common_DOCKER_HOST_not_swarm_manager"
    TEST_NAME="test_common_DOCKER_HOST_not_swarm_manager"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    test_common_DOCKER_HOST_not_swarm_manager() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      reset_gantry_env "${SUITE_NAME}" "${SERVICE_NAME}"
      export GANTRY_TEST_DOCKER_HOST="8.8.8.8:53"
      run_gantry "${SUITE_NAME}" "${TEST_NAME}"
    }
    BeforeEach "common_setup_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_common_DOCKER_HOST_not_swarm_manager "${TEST_NAME}" "${SERVICE_NAME}"
      The status should be failure
      The stdout should satisfy display_output
      The stdout should satisfy spec_expect_no_message ".+"
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_no_message "${START_WITHOUT_A_SQUARE_BRACKET}"
      The stderr should satisfy spec_expect_message    "${SKIP_UPDATING_ALL}.*${SKIP_REASON_NOT_SWARM_MANAGER}"
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
  Describe "test_common_LOG_LEVEL_none"
    TEST_NAME="test_common_LOG_LEVEL_none"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    test_common_LOG_LEVEL_none() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      reset_gantry_env "${SUITE_NAME}" "${SERVICE_NAME}"
      # Same as test_new_image_yes, except set LOG_LEVEL to NONE
      export GANTRY_LOG_LEVEL=NONE
      run_gantry "${SUITE_NAME}" "${TEST_NAME}"
    }
    BeforeEach "common_setup_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_common_LOG_LEVEL_none "${TEST_NAME}" "${SERVICE_NAME}"
      The status should be success
      The stdout should satisfy display_output
      The stdout should satisfy spec_expect_no_message ".+"
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_no_message ".+"
    End
  End
  # Do not run test_common_no_new_env with the kcov, which alters the environment variables.
  Describe "test_common_no_new_env"
    # Check there is no new variable set,
    # to avoid errors like https://github.com/shizunge/gantry/issues/64#issuecomment-2475499085
    #
    # It makes no sense to run run this test using containers because we check env on the host, while the container test set env inside the container.
    # But it should not failed with a container. We are just testing GANTRY_LOG_LEVEL=WARN.
    TEST_NAME="test_common_no_new_env"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    test_common_no_new_env() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      local ENV_BEFORE_RUN=
      ENV_BEFORE_RUN=$(mktemp)
      local ENV_AFTER_RUN=
      ENV_AFTER_RUN=$(mktemp)

      reset_gantry_env "${SUITE_NAME}" "${SERVICE_NAME}"
      # There should be no warnings or errors. So it should work the same as LOG_LEVLE=NONE.
      export GANTRY_LOG_LEVEL=WARN
      declare -p > "${ENV_BEFORE_RUN}"
      run_gantry "${SUITE_NAME}" "${TEST_NAME}"
      declare -p > "${ENV_AFTER_RUN}"
      # Allow the 3 mismatches LOG_LEVEL NODE_NAME LOG_SCOPE used in log() function.
      # Allow the 2 mismatches LINENO _ for kcov coverage.
      for ALLOWED in LOG_LEVEL NODE_NAME LOG_SCOPE LINENO _; do
        sed -i "s/^declare .* ${ALLOWED}=.*//" "${ENV_BEFORE_RUN}"
        sed -i "s/^declare .* ${ALLOWED}=.*//" "${ENV_AFTER_RUN}"
      done
      diff --ignore-blank-lines "${ENV_BEFORE_RUN}" "${ENV_AFTER_RUN}"
      rm "${ENV_BEFORE_RUN}"
      rm "${ENV_AFTER_RUN}"
    }
    BeforeEach "common_setup_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_common_no_new_env "${TEST_NAME}" "${SERVICE_NAME}"
      The status should be success
      The stdout should satisfy display_output
      The stdout should satisfy spec_expect_no_message ".+"
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_no_message ".+"
    End
  End
  Describe "test_common_PRE_POST_RUN_CMD"
    TEST_NAME="test_common_PRE_POST_RUN_CMD"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    test_common_PRE_POST_RUN_CMD() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      reset_gantry_env "${SUITE_NAME}" "${SERVICE_NAME}"
      export GANTRY_UPDATE_OPTIONS=
      export GANTRY_CLEANUP_IMAGES=
      # Test that pre-run command can change the global configurations.
      export GANTRY_PRE_RUN_CMD="echo \"Pre update\"; GANTRY_UPDATE_OPTIONS=--detach=true; GANTRY_CLEANUP_IMAGES=false;"
      # This command outputs multiple lines.
      local POST_CMD="for I in \$(seq 3 5); do echo \"TEST_OUTPUT_MULTIPLE_LINES=\$I\"; done"
      # Test that the command returns a non-zero value.
      export GANTRY_POST_RUN_CMD="echo \"Post update\"; ${POST_CMD}; false;"
      run_gantry "${SUITE_NAME}" "${TEST_NAME}"
    }
    BeforeEach "common_setup_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_common_PRE_POST_RUN_CMD "${TEST_NAME}" "${SERVICE_NAME}"
      # Updating should be successful, but post-run comamnd failed.
      The status should be failure
      The stdout should satisfy display_output
      The stdout should satisfy spec_expect_no_message ".+"
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_no_message "${START_WITHOUT_A_SQUARE_BRACKET}"
      The stderr should satisfy spec_expect_message    "Pre update$"
      The stderr should satisfy spec_expect_message    "Finish pre-run command.$"
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${PERFORM_UPDATING}.*${SERVICE_NAME}.*${PERFORM_REASON_HAS_NEWER_IMAGE}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_SKIP_JOBS}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_INSPECT_FAILURE}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_NO_NEW_IMAGES}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_UPDATING}"
      The stderr should satisfy spec_expect_message    "${ADDING_OPTIONS}.*--detach=true.*${SERVICE_NAME}"
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
      The stderr should satisfy spec_expect_no_message "${REMOVED_IMAGE}.*"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*"
      The stderr should satisfy spec_expect_no_message "${DONE_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_message    "Post update$"
      The stderr should satisfy spec_expect_message    "TEST_OUTPUT_MULTIPLE_LINES=3$"
      The stderr should satisfy spec_expect_message    "TEST_OUTPUT_MULTIPLE_LINES=4$"
      The stderr should satisfy spec_expect_message    "TEST_OUTPUT_MULTIPLE_LINES=5$"
      The stderr should satisfy spec_expect_message    "Finish post-run command with a non-zero return value 1.$"
      The stderr should satisfy spec_expect_no_message "${SCHEDULE_NEXT_UPDATE_AT}"
      The stderr should satisfy spec_expect_no_message "${SLEEP_SECONDS_BEFORE_NEXT_UPDATE}"
    End
  End
  Describe "test_common_SLEEP_SECONDS"
    TEST_NAME="test_common_SLEEP_SECONDS"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    test_common_SLEEP_SECONDS() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      reset_gantry_env "${SUITE_NAME}" "${SERVICE_NAME}"
      export GANTRY_SLEEP_SECONDS="7"
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
      When run test_common_SLEEP_SECONDS "${TEST_NAME}" "${SERVICE_NAME}"
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
  Describe "test_common_SLEEP_SECONDS_not_a_number"
    TEST_NAME="test_common_SLEEP_SECONDS_not_a_number"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    test_common_SLEEP_SECONDS_not_a_number() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      reset_gantry_env "${SUITE_NAME}" "${SERVICE_NAME}"
      export GANTRY_SLEEP_SECONDS="NotANumber"
      run_gantry "${SUITE_NAME}" "${TEST_NAME}"
    }
    BeforeEach "common_setup_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_common_SLEEP_SECONDS_not_a_number "${TEST_NAME}" "${SERVICE_NAME}"
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
End # Describe 'Single service'
