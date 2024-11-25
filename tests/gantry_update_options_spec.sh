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

_read_service_label() {
  local SERVICE_NAME="${1}"
  local LABEL="${2}"
  docker service inspect -f "{{index .Spec.Labels \"${LABEL}\"}}" "${SERVICE_NAME}"
}

Describe 'update-options'
  SUITE_NAME="update-options"
  BeforeAll "initialize_all_tests ${SUITE_NAME}"
  AfterAll "finish_all_tests ${SUITE_NAME}"
  Describe "test_update_UPDATE_OPTIONS"
    TEST_NAME="test_update_UPDATE_OPTIONS"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    test_update_UPDATE_OPTIONS() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      local LABEL="gantry.test"
      local LABEL_AND_VALUE=
      LABEL_AND_VALUE=$(_read_service_label "${SERVICE_NAME}" "${LABEL}")
      echo "Before updating: LABEL_AND_VALUE=${LABEL_AND_VALUE}"
      reset_gantry_env "${SERVICE_NAME}"
      export GANTRY_UPDATE_OPTIONS="--label-add=${LABEL}=${SERVICE_NAME}"
      local RETURN_VALUE=
      run_gantry "${TEST_NAME}"
      RETURN_VALUE="${?}"
      LABEL_AND_VALUE=$(_read_service_label "${SERVICE_NAME}" "${LABEL}")
      echo "After updating: LABEL_AND_VALUE=${LABEL_AND_VALUE}"
      return "${RETURN_VALUE}"
    }
    BeforeEach "common_setup_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_update_UPDATE_OPTIONS "${TEST_NAME}" "${SERVICE_NAME}"
      The status should be success
      The stdout should satisfy display_output
      # Check an observable difference before and after applying UPDATE_OPTIONS.
      The stdout should satisfy spec_expect_no_message "Before updating: LABEL_AND_VALUE=.*${SERVICE_NAME}"
      The stdout should satisfy spec_expect_message    "After updating: LABEL_AND_VALUE=.*${SERVICE_NAME}"
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_no_message "${START_WITHOUT_A_SQUARE_BRACKET}"
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${PERFORM_UPDATING}.*${SERVICE_NAME}.*${PERFORM_REASON_HAS_NEWER_IMAGE}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_SKIP_JOBS}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_INSPECT_FAILURE}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_NO_NEW_IMAGES}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_UPDATING}"
      The stderr should satisfy spec_expect_message    "${ADDING_OPTIONS}.*--label-add=gantry.test=${SERVICE_NAME}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${SET_TIMEOUT_TO}"
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
      The stderr should satisfy spec_expect_message    "${DONE_REMOVING_IMAGES}"
    End
  End
  Describe "test_update_label_UPDATE_OPTIONS"
    TEST_NAME="test_update_label_UPDATE_OPTIONS"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    test_update_label_UPDATE_OPTIONS() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      local LABEL="gantry.test"
      local LABEL_AND_VALUE=
      LABEL_AND_VALUE=$(_read_service_label "${SERVICE_NAME}" "${LABEL}")
      echo "Before updating: LABEL_AND_VALUE=${LABEL_AND_VALUE}"
      reset_gantry_env "${SERVICE_NAME}"
      # label should override the global environment variable.
      export GANTRY_UPDATE_OPTIONS="--incorrect-option"
      local LABEL_AND_VALUE="gantry.update.options=--label-add=${LABEL}=${SERVICE_NAME}"
      docker_service_update --label-add "${LABEL_AND_VALUE}" "${SERVICE_NAME}"
      local RETURN_VALUE=
      run_gantry "${TEST_NAME}"
      RETURN_VALUE="${?}"
      LABEL_AND_VALUE=$(_read_service_label "${SERVICE_NAME}" "${LABEL}")
      echo "After updating: LABEL_AND_VALUE=${LABEL_AND_VALUE}"
      return "${RETURN_VALUE}"
    }
    BeforeEach "common_setup_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_update_label_UPDATE_OPTIONS "${TEST_NAME}" "${SERVICE_NAME}"
      The status should be success
      The stdout should satisfy display_output
      # Check an observable difference before and after applying UPDATE_OPTIONS.
      The stdout should satisfy spec_expect_no_message "Before updating: LABEL_AND_VALUE=.*${SERVICE_NAME}"
      The stdout should satisfy spec_expect_message    "After updating: LABEL_AND_VALUE=.*${SERVICE_NAME}"
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_no_message "${START_WITHOUT_A_SQUARE_BRACKET}"
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${PERFORM_UPDATING}.*${SERVICE_NAME}.*${PERFORM_REASON_HAS_NEWER_IMAGE}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_SKIP_JOBS}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_INSPECT_FAILURE}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_NO_NEW_IMAGES}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_UPDATING}"
      The stderr should satisfy spec_expect_message    "${ADDING_OPTIONS}.*--label-add=gantry.test=${SERVICE_NAME}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${SET_TIMEOUT_TO}"
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
      The stderr should satisfy spec_expect_message    "${DONE_REMOVING_IMAGES}"
    End
  End
  Describe "test_update_UPDATE_TIMEOUT_SECONDS_not_a_number"
    TEST_NAME="test_update_UPDATE_TIMEOUT_SECONDS_not_a_number"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    test_update_UPDATE_TIMEOUT_SECONDS_not_a_number() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      reset_gantry_env "${SERVICE_NAME}"
      export GANTRY_UPDATE_TIMEOUT_SECONDS="NotANumber"
      run_gantry "${TEST_NAME}"
    }
    BeforeEach "common_setup_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_update_UPDATE_TIMEOUT_SECONDS_not_a_number "${TEST_NAME}" "${SERVICE_NAME}"
      The status should be failure
      The stdout should satisfy display_output
      The stdout should satisfy spec_expect_no_message ".+"
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_no_message "${START_WITHOUT_A_SQUARE_BRACKET}"
      The stderr should satisfy spec_expect_message    "UPDATE_TIMEOUT_SECONDS ${MUST_BE_A_NUMBER}.*"
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${PERFORM_UPDATING}.*${SERVICE_NAME}.*${PERFORM_REASON_HAS_NEWER_IMAGE}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_SKIP_JOBS}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_INSPECT_FAILURE}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_NO_NEW_IMAGES}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_UPDATING}"
      The stderr should satisfy spec_expect_no_message "${SET_TIMEOUT_TO}"
      The stderr should satisfy spec_expect_no_message "${UPDATED}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_UPDATES}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLING_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLED_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${NO_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATE_FAILED}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_ERRORS}"
      The stderr should satisfy spec_expect_message    "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_no_message "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${DONE_REMOVING_IMAGES}"
    End
  End
  Describe "test_update_lable_UPDATE_TIMEOUT_SECONDS"
    TEST_NAME="test_update_lable_UPDATE_TIMEOUT_SECONDS"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    TIMEOUT=300
    test_update_lable_UPDATE_TIMEOUT_SECONDS() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      local TIMEOUT="${3}"
      local LABEL="gantry.test"
      local LABEL_AND_VALUE=
      LABEL_AND_VALUE=$(_read_service_label "${SERVICE_NAME}" "${LABEL}")
      echo "Before updating: LABEL_AND_VALUE=${LABEL_AND_VALUE}"
      reset_gantry_env "${SERVICE_NAME}"
      export GANTRY_UPDATE_OPTIONS="--label-add=${LABEL}=${SERVICE_NAME}"
      # label should override the global environment variable.
      export GANTRY_UPDATE_TIMEOUT_SECONDS="NotANumber"
      # Assume that the update will finish within TIMEOUT.
      LABEL_AND_VALUE="gantry.update.timeout_seconds=${TIMEOUT}"
      docker_service_update --label-add "${LABEL_AND_VALUE}" "${SERVICE_NAME}"
      local RETURN_VALUE=
      run_gantry "${TEST_NAME}"
      RETURN_VALUE="${?}"
      LABEL_AND_VALUE=$(_read_service_label "${SERVICE_NAME}" "${LABEL}")
      echo "After updating: LABEL_AND_VALUE=${LABEL_AND_VALUE}"
      return "${RETURN_VALUE}"
    }
    BeforeEach "common_setup_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_update_lable_UPDATE_TIMEOUT_SECONDS "${TEST_NAME}" "${SERVICE_NAME}" "${TIMEOUT}"
      The status should be success
      The stdout should satisfy display_output
      # Check an observable difference before and after applying UPDATE_OPTIONS.
      The stdout should satisfy spec_expect_no_message "Before updating: LABEL_AND_VALUE=.*${SERVICE_NAME}"
      The stdout should satisfy spec_expect_message    "After updating: LABEL_AND_VALUE=.*${SERVICE_NAME}"
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_no_message "${START_WITHOUT_A_SQUARE_BRACKET}"
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${PERFORM_UPDATING}.*${SERVICE_NAME}.*${PERFORM_REASON_HAS_NEWER_IMAGE}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_SKIP_JOBS}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_INSPECT_FAILURE}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_NO_NEW_IMAGES}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_UPDATING}"
      The stderr should satisfy spec_expect_message    "${ADDING_OPTIONS}.*--label-add=gantry.test=${SERVICE_NAME}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${SET_TIMEOUT_TO} ${TIMEOUT}.*${SERVICE_NAME}"
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
      The stderr should satisfy spec_expect_message    "${DONE_REMOVING_IMAGES}"
    End
  End
End # Describe 'update-options'
