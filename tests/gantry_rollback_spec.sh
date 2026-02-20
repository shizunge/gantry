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

Describe 'rollback'
  SUITE_NAME="rollback"
  BeforeAll "initialize_all_tests ${SUITE_NAME}"
  AfterAll "finish_all_tests ${SUITE_NAME}"
  Describe "test_rollback_due_to_timeout"
    TEST_NAME="test_rollback_due_to_timeout"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    TIMEOUT=1
    test_rollback_due_to_timeout() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      local TIMEOUT="${3}"
      reset_gantry_env "${SUITE_NAME}" "${SERVICE_NAME}"
      # Assume service update won't be done within TIMEOUT second.
      export GANTRY_UPDATE_TIMEOUT_SECONDS="${TIMEOUT}"
      run_gantry "${SUITE_NAME}" "${TEST_NAME}"
    }
    BeforeEach "common_setup_timeout ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME} ${TIMEOUT}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_rollback_due_to_timeout "${TEST_NAME}" "${SERVICE_NAME}" "${TIMEOUT}"
      The status should be failure
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
      The stderr should satisfy spec_expect_message    "${SET_TIMEOUT_TO} ${TIMEOUT}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${RETURN_VALUE_INDICATES_TIMEOUT}"
      The stderr should satisfy spec_expect_no_message "${UPDATED}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_UPDATES}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ADDING_OPTIONS}"
      The stderr should satisfy spec_expect_message    "${ROLLING_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${FROM_DOCKER_DOES_NOT_HAVE_A_PREVIOUS_SPEC}"
      The stderr should satisfy spec_expect_message    "${ROLLED_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${NO_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_UPDATE_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_ERRORS}"
      The stderr should satisfy spec_expect_message    "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_no_message "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${DONE_REMOVING_IMAGES}"
    End
  End
  Describe "test_rollback_failed"
    TEST_NAME="test_rollback_failed"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    TIMEOUT=1
    test_rollback_failed() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      local TIMEOUT="${3}"
      reset_gantry_env "${SUITE_NAME}" "${SERVICE_NAME}"
      # Assume service update won't be done within TIMEOUT second.
      export GANTRY_UPDATE_TIMEOUT_SECONDS="${TIMEOUT}"
      # Rollback would fail due to the incorrect option.
      # --with-registry-auth cannot be combined with --rollback.
      export GANTRY_ROLLBACK_OPTIONS="--with-registry-auth"
      run_gantry "${SUITE_NAME}" "${TEST_NAME}"
    }
    BeforeEach "common_setup_timeout ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME} ${TIMEOUT}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_rollback_failed "${TEST_NAME}" "${SERVICE_NAME}" "${TIMEOUT}"
      The status should be failure
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
      The stderr should satisfy spec_expect_message    "${SET_TIMEOUT_TO} ${TIMEOUT}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${RETURN_VALUE_INDICATES_TIMEOUT}"
      The stderr should satisfy spec_expect_no_message "${UPDATED}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_UPDATES}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${ADDING_OPTIONS}.*--with-registry-auth.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${ROLLING_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${FROM_DOCKER_DOES_NOT_HAVE_A_PREVIOUS_SPEC}"
      The stderr should satisfy spec_expect_no_message "${ROLLED_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${NO_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_UPDATE_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_ERRORS}"
      The stderr should satisfy spec_expect_message    "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_no_message "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${DONE_REMOVING_IMAGES}"
    End
  End
  Describe "test_rollback_ROLLBACK_ON_FAILURE_false"
    TEST_NAME="test_rollback_ROLLBACK_ON_FAILURE_false"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    TIMEOUT=1
    test_rollback_ROLLBACK_ON_FAILURE_false() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      local TIMEOUT="${3}"
      reset_gantry_env "${SUITE_NAME}" "${SERVICE_NAME}"
      # Assume service update won't be done within TIMEOUT second.
      export GANTRY_UPDATE_TIMEOUT_SECONDS="${TIMEOUT}"
      export GANTRY_ROLLBACK_ON_FAILURE="false"
      run_gantry "${SUITE_NAME}" "${TEST_NAME}"
    }
    BeforeEach "common_setup_timeout ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME} ${TIMEOUT}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_rollback_ROLLBACK_ON_FAILURE_false "${TEST_NAME}" "${SERVICE_NAME}" "${TIMEOUT}"
      The status should be failure
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
      The stderr should satisfy spec_expect_message    "${SET_TIMEOUT_TO} ${TIMEOUT}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${RETURN_VALUE_INDICATES_TIMEOUT}"
      The stderr should satisfy spec_expect_no_message "${UPDATED}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_UPDATES}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ADDING_OPTIONS}"
      The stderr should satisfy spec_expect_no_message "${ROLLING_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${FROM_DOCKER_DOES_NOT_HAVE_A_PREVIOUS_SPEC}"
      The stderr should satisfy spec_expect_no_message "${ROLLED_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${NO_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_UPDATE_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_ERRORS}"
      The stderr should satisfy spec_expect_message    "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_no_message "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${DONE_REMOVING_IMAGES}"
    End
  End
  Describe "test_rollback_label_failed"
    TEST_NAME="test_rollback_label_failed"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    TIMEOUT=1
    test_rollback_label_failed() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      local TIMEOUT="${3}"
      reset_gantry_env "${SUITE_NAME}" "${SERVICE_NAME}"
      # Assume service update won't be done within TIMEOUT second.
      export GANTRY_UPDATE_TIMEOUT_SECONDS="${TIMEOUT}"
      # label should override the global environment variable.
      export GANTRY_ROLLBACK_OPTIONS="--incorrect-option"
      # Rollback would fail due to the incorrect option.
      # --with-registry-auth cannot be combined with --rollback.
      local LABEL_AND_VALUE="gantry.rollback.options=--with-registry-auth"
      docker_service_update --label-add "${LABEL_AND_VALUE}" "${SERVICE_NAME}"
      run_gantry "${SUITE_NAME}" "${TEST_NAME}"
    }
    BeforeEach "common_setup_timeout ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME} ${TIMEOUT}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_rollback_label_failed "${TEST_NAME}" "${SERVICE_NAME}" "${TIMEOUT}"
      The status should be failure
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
      The stderr should satisfy spec_expect_message    "${SET_TIMEOUT_TO} ${TIMEOUT}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${RETURN_VALUE_INDICATES_TIMEOUT}"
      The stderr should satisfy spec_expect_no_message "${UPDATED}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_UPDATES}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${ADDING_OPTIONS}.*--with-registry-auth.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${ROLLING_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${FROM_DOCKER_DOES_NOT_HAVE_A_PREVIOUS_SPEC}"
      The stderr should satisfy spec_expect_no_message "${ROLLED_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${NO_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_UPDATE_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_ERRORS}"
      The stderr should satisfy spec_expect_message    "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_no_message "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${DONE_REMOVING_IMAGES}"
    End
  End
  Describe "test_rollback_label_ROLLBACK_ON_FAILURE_false"
    TEST_NAME="test_rollback_label_ROLLBACK_ON_FAILURE_false"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    TIMEOUT=1
    test_rollback_label_ROLLBACK_ON_FAILURE_false() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      local TIMEOUT="${3}"
      reset_gantry_env "${SUITE_NAME}" "${SERVICE_NAME}"
      # Assume service update won't be done within TIMEOUT second.
      export GANTRY_UPDATE_TIMEOUT_SECONDS="${TIMEOUT}"
      # label should override the global environment variable.
      local LABEL_AND_VALUE="gantry.rollback.on_failure=false"
      docker_service_update --label-add "${LABEL_AND_VALUE}" "${SERVICE_NAME}"
      run_gantry "${SUITE_NAME}" "${TEST_NAME}"
    }
    BeforeEach "common_setup_timeout ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME} ${TIMEOUT}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_rollback_label_ROLLBACK_ON_FAILURE_false "${TEST_NAME}" "${SERVICE_NAME}" "${TIMEOUT}"
      The status should be failure
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
      The stderr should satisfy spec_expect_message    "${SET_TIMEOUT_TO} ${TIMEOUT}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${RETURN_VALUE_INDICATES_TIMEOUT}"
      The stderr should satisfy spec_expect_no_message "${UPDATED}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_UPDATES}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ADDING_OPTIONS}"
      The stderr should satisfy spec_expect_no_message "${ROLLING_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${FROM_DOCKER_DOES_NOT_HAVE_A_PREVIOUS_SPEC}"
      The stderr should satisfy spec_expect_no_message "${ROLLED_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${NO_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_UPDATE_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_ERRORS}"
      The stderr should satisfy spec_expect_message    "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_no_message "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${DONE_REMOVING_IMAGES}"
    End
  End
  Describe "test_multiple_services_continue_on_failure"
    TEST_NAME="test_multiple_services_continue_on_failure"
    IMAGE_WITH_TAG0=$(get_image_with_tag "${SUITE_NAME}" 0)
    IMAGE_WITH_TAG1=$(get_image_with_tag "${SUITE_NAME}" 1)
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    SERVICE_NAME0="${SERVICE_NAME}-0"
    SERVICE_NAME1="${SERVICE_NAME}-1"
    TIMEOUT=1
    test_start() {
      local TEST_NAME="${1}"
      local IMAGE_WITH_TAG0="${2}"
      local IMAGE_WITH_TAG1="${3}"
      local SERVICE_NAME="${4}"
      local TIMEOUT="${5}"
      local SERVICE_NAME0="${SERVICE_NAME}-0"
      local SERVICE_NAME1="${SERVICE_NAME}-1"
      common_setup_timeout "${TEST_NAME}" "${IMAGE_WITH_TAG0}" "${SERVICE_NAME0}" "${TIMEOUT}"
      common_setup_new_image "${TEST_NAME} continue" "${IMAGE_WITH_TAG1}" "${SERVICE_NAME1}"
    }
    test_multiple_services_continue_on_failure() {
      # To test that failure on SERVICE_NAME0 should not block updating SERVICE_NAME1.
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      local TIMEOUT="${3}"
      local SERVICE_NAME0="${SERVICE_NAME}-0"
      local SERVICE_NAME1="${SERVICE_NAME}-1"
      reset_gantry_env "${SUITE_NAME}" "${SERVICE_NAME}"
      # Assume service update won't be done within TIMEOUT second.
      LABEL_AND_VALUE="gantry.update.timeout_seconds=${TIMEOUT}"
      docker_service_update --label-add "${LABEL_AND_VALUE}" "${SERVICE_NAME0}"
      run_gantry "${SUITE_NAME}" "${TEST_NAME}"
    }
    test_end() {
      local TEST_NAME="${1}"
      local IMAGE_WITH_TAG0="${2}"
      local IMAGE_WITH_TAG1="${3}"
      local SERVICE_NAME="${4}"
      stop_multiple_services "${SERVICE_NAME}" 0 1
      prune_local_test_image "${IMAGE_WITH_TAG0}"
      prune_local_test_image "${IMAGE_WITH_TAG1}"
      finalize_test "${TEST_NAME}"
    }
    BeforeEach "test_start ${TEST_NAME} ${IMAGE_WITH_TAG0} ${IMAGE_WITH_TAG1} ${SERVICE_NAME} ${TIMEOUT}"
    AfterEach "test_end ${TEST_NAME} ${IMAGE_WITH_TAG0} ${IMAGE_WITH_TAG1} ${SERVICE_NAME}"
    It 'run_test'
      When run test_multiple_services_continue_on_failure "${TEST_NAME}" "${SERVICE_NAME}" "${TIMEOUT}"
      The status should be failure
      The stdout should satisfy display_output
      The stdout should satisfy spec_expect_no_message ".+"
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_no_message "${START_WITHOUT_A_SQUARE_BRACKET}"
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.*${SERVICE_NAME0}"
      The stderr should satisfy spec_expect_message    "${PERFORM_UPDATING}.*${SERVICE_NAME0}.*${PERFORM_REASON_HAS_NEWER_IMAGE}"
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.*${SERVICE_NAME1}"
      The stderr should satisfy spec_expect_message    "${PERFORM_UPDATING}.*${SERVICE_NAME1}.*${PERFORM_REASON_HAS_NEWER_IMAGE}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_SKIP_JOBS}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_INSPECT_FAILURE}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_NO_NEW_IMAGES}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_UPDATING}"
      The stderr should satisfy spec_expect_message    "${SET_TIMEOUT_TO} ${TIMEOUT}.*${SERVICE_NAME0}"
      The stderr should satisfy spec_expect_message    "${RETURN_VALUE_INDICATES_TIMEOUT}"
      The stderr should satisfy spec_expect_no_message "${UPDATED}.*${SERVICE_NAME0}"
      The stderr should satisfy spec_expect_no_message "${NO_UPDATES}.*${SERVICE_NAME0}"
      The stderr should satisfy spec_expect_no_message "${ADDING_OPTIONS}"
      The stderr should satisfy spec_expect_message    "${ROLLING_BACK}.*${SERVICE_NAME0}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME0}"
      The stderr should satisfy spec_expect_no_message "${FROM_DOCKER_DOES_NOT_HAVE_A_PREVIOUS_SPEC}"
      The stderr should satisfy spec_expect_message    "${ROLLED_BACK}.*${SERVICE_NAME0}"
      The stderr should satisfy spec_expect_no_message "${SET_TIMEOUT_TO} ${TIMEOUT}.*${SERVICE_NAME1}"
      The stderr should satisfy spec_expect_message    "${UPDATED}.*${SERVICE_NAME1}"
      The stderr should satisfy spec_expect_no_message "${NO_UPDATES}.*${SERVICE_NAME1}"
      The stderr should satisfy spec_expect_no_message "${ROLLING_BACK}.*${SERVICE_NAME1}"
      The stderr should satisfy spec_expect_no_message "${ROLLED_BACK}.*${SERVICE_NAME1}"
      The stderr should satisfy spec_expect_no_message "${NO_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_message    "1 ${SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_UPDATE_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_ERRORS}"
      The stderr should satisfy spec_expect_no_message "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_message    "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG0}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG0}"
      The stderr should satisfy spec_expect_message    "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG1}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG1}"
      The stderr should satisfy spec_expect_message    "${DONE_REMOVING_IMAGES}"
    End
  End
End # Describe 'Rollback'
