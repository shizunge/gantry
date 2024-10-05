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
  Describe "test_common_DOCKER_HOST_not_swarm_manager" "container_test:false"
    TEST_NAME="test_common_DOCKER_HOST_not_swarm_manager"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME="gantry-test-$(unique_id)"
    test_common_DOCKER_HOST_not_swarm_manager() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      reset_gantry_env "${SERVICE_NAME}"
      export DOCKER_HOST="8.8.8.8:53"
      local RETURN_VALUE=0
      run_gantry "${TEST_NAME}"
      RETURN_VALUE="${?}"
      export DOCKER_HOST=
      return "${RETURN_VALUE}"
    }
    BeforeEach "common_setup_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_common_DOCKER_HOST_not_swarm_manager "${TEST_NAME}" "${SERVICE_NAME}"
      The status should be failure
      The stdout should satisfy display_output
      The stderr should satisfy display_output
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
      The stderr should satisfy spec_expect_no_message "${SCHEDULE_NEXT_UPDATE_AT}"
      The stderr should satisfy spec_expect_no_message "${SLEEP_SECONDS_BEFORE_NEXT_UPDATE}"
    End
  End
  Describe "test_common_LOG_LEVEL_none" "container_test:true"
    TEST_NAME="test_common_LOG_LEVEL_none"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME="gantry-test-$(unique_id)"
    test_common_LOG_LEVEL_none() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      reset_gantry_env "${SERVICE_NAME}"
      # Same as test_new_image_yes, except set LOG_LEVEL to NONE
      export GANTRY_LOG_LEVEL=NONE
      run_gantry "${TEST_NAME}"
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
  Describe "test_common_PRE_POST_RUN_CMD" "container_test:true"
    TEST_NAME="test_common_PRE_POST_RUN_CMD"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME="gantry-test-$(unique_id)"
    test_common_PRE_POST_RUN_CMD() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      reset_gantry_env "${SERVICE_NAME}"
      export GANTRY_PRE_RUN_CMD="echo \"Pre update\""
      export GANTRY_POST_RUN_CMD="echo \"Post update\""
      run_gantry "${TEST_NAME}"
    }
    BeforeEach "common_setup_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_common_PRE_POST_RUN_CMD "${TEST_NAME}" "${SERVICE_NAME}"
      The status should be success
      The stdout should satisfy display_output
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_message    "Pre update"
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
      The stderr should satisfy spec_expect_message    "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_message    "Post update"
      The stderr should satisfy spec_expect_no_message "${SCHEDULE_NEXT_UPDATE_AT}"
      The stderr should satisfy spec_expect_no_message "${SLEEP_SECONDS_BEFORE_NEXT_UPDATE}"
    End
  End
  # run_gantry prints logs after gantry exists, while testing a container.
  # In thes test, gantry never exit, but will be killed, thus there is no log.
  # Therefore we disable the container test for this test.
  Describe "test_common_SLEEP_SECONDS" "container_test:false"
    TEST_NAME="test_common_SLEEP_SECONDS"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME="gantry-test-$(unique_id)"
    test_common_SLEEP_SECONDS() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      reset_gantry_env "${SERVICE_NAME}"
      export GANTRY_SLEEP_SECONDS="5"
      run_gantry ${TEST_NAME} &
      local PID="${!}"
      sleep 15
      kill "${PID}"
    }
    BeforeEach "common_setup_no_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_common_SLEEP_SECONDS "${TEST_NAME}" "${SERVICE_NAME}"
      The status should be success
      The stdout should satisfy display_output
      The stderr should satisfy display_output
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
      # Check messages between iterations.
      The stderr should satisfy spec_expect_message           "${SCHEDULE_NEXT_UPDATE_AT}"
      The stderr should satisfy spec_expect_message           "${SLEEP_SECONDS_BEFORE_NEXT_UPDATE}"
    End
  End
  Describe "test_common_SLEEP_SECONDS_not_a_number" "container_test:false"
    TEST_NAME="test_common_SLEEP_SECONDS_not_a_number"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME="gantry-test-$(unique_id)"
    test_common_SLEEP_SECONDS_not_a_number() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      reset_gantry_env "${SERVICE_NAME}"
      export GANTRY_SLEEP_SECONDS="NotANumber"
      run_gantry "${TEST_NAME}"
    }
    BeforeEach "common_setup_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_common_SLEEP_SECONDS_not_a_number "${TEST_NAME}" "${SERVICE_NAME}"
      The status should be failure
      The stdout should satisfy display_output
      The stderr should satisfy display_output
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
      The stderr should satisfy spec_expect_no_message "${SCHEDULE_NEXT_UPDATE_AT}"
      The stderr should satisfy spec_expect_no_message "${SLEEP_SECONDS_BEFORE_NEXT_UPDATE}"
    End
  End
End # Describe 'Single service'
