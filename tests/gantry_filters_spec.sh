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

Describe 'filters'
  SUITE_NAME="filters"
  BeforeAll "initialize_all_tests ${SUITE_NAME}"
  AfterAll "finish_all_tests ${SUITE_NAME}"
  Describe "test_SERVICES_FILTERS_bad"
    TEST_NAME="test_SERVICES_FILTERS_bad"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    test_SERVICES_FILTERS_bad() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      reset_gantry_env "${SERVICE_NAME}"
      export GANTRY_SERVICES_FILTERS="BadFilterValue"
      run_gantry "${TEST_NAME}"
    }
    BeforeEach "common_setup_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_SERVICES_FILTERS_bad "${TEST_NAME}" "${SERVICE_NAME}"
      The status should be failure
      The stdout should satisfy display_output
      The stdout should satisfy spec_expect_no_message ".+"
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_no_message "${START_WITHOUT_A_SQUARE_BRACKET}"
      The stderr should satisfy spec_expect_message    "Failed to obtain services list.*"
      The stderr should satisfy spec_expect_message    "${SKIP_UPDATING_ALL}.*${SKIP_REASON_PREVIOUS_ERRORS}"
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
      The stderr should satisfy spec_expect_message    "${NO_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATE_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_ERRORS}"
      The stderr should satisfy spec_expect_message    "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_no_message "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${DONE_REMOVING_IMAGES}"
    End
  End
  Describe "test_SERVICES_EXCLUDED_multiple_services"
    TEST_NAME="test_SERVICES_EXCLUDED_multiple_services"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    MAX_SERVICES_NUM=10
    test_SERVICES_EXCLUDED_multiple_services() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      local MAX_SERVICES_NUM="${3}"
      local NUM_SERVICES_EXCLUDED=$((MAX_SERVICES_NUM/2))
      local NUM_SERVICES_EXCLUDED_FILTER_START=$((NUM_SERVICES_EXCLUDED+1))
      reset_gantry_env "${SERVICE_NAME}"
      for NUM in $(seq 0 "${NUM_SERVICES_EXCLUDED}"); do
        local SERVICE_NAME_NUM="${SERVICE_NAME}-${NUM}"
        export GANTRY_SERVICES_EXCLUDED="${GANTRY_SERVICES_EXCLUDED} ${SERVICE_NAME_NUM}"
      done
      local LABEL="gantry.test"
      for NUM in $(seq "${NUM_SERVICES_EXCLUDED_FILTER_START}" "${MAX_SERVICES_NUM}"); do
        local SERVICE_NAME_NUM="${SERVICE_NAME}-${NUM}"
        docker_service_update --label-add "${LABEL}=true" "${SERVICE_NAME_NUM}"
      done
      export GANTRY_SERVICES_EXCLUDED_FILTERS="label=${LABEL}=true"
      run_gantry "${TEST_NAME}"
    }
    BeforeEach "common_setup_new_image_multiple ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME} ${MAX_SERVICES_NUM}"
    AfterEach "common_cleanup_multiple ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME} ${MAX_SERVICES_NUM}"
    It 'run_test'
      When run test_SERVICES_EXCLUDED_multiple_services "${TEST_NAME}" "${SERVICE_NAME}" "${MAX_SERVICES_NUM}"
      The status should be success
      The stdout should satisfy display_output
      The stdout should satisfy spec_expect_no_message ".+"
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_no_message "${START_WITHOUT_A_SQUARE_BRACKET}"
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING_ALL}"
      The stderr should satisfy spec_expect_multiple_messages "${EXCLUDE_SERVICE}.*${SERVICE_NAME}"
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
      The stderr should satisfy spec_expect_message    "${NO_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATE_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_ERRORS}"
      The stderr should satisfy spec_expect_message    "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_no_message "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${DONE_REMOVING_IMAGES}"
    End
  End
  Describe "test_SERVICES_EXCLUDED_FILTERS_default"
    TEST_NAME="test_SERVICES_EXCLUDED_FILTERS_default"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    MAX_SERVICES_NUM=10
    test_SERVICES_EXCLUDED_FILTERS_default() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      local MAX_SERVICES_NUM="${3}"
      reset_gantry_env "${SERVICE_NAME}"
      local LABEL="gantry.services.excluded"
      for NUM in $(seq 0 "${MAX_SERVICES_NUM}"); do
        local SERVICE_NAME_NUM="${SERVICE_NAME}-${NUM}"
        docker_service_update --label-add "${LABEL}=true" "${SERVICE_NAME_NUM}"
      done
      # Do not set GANTRY_SERVICES_EXCLUDED_FILTERS, check the default one is working.
      run_gantry "${TEST_NAME}"
    }
    BeforeEach "common_setup_new_image_multiple ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME} ${MAX_SERVICES_NUM}"
    AfterEach "common_cleanup_multiple ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME} ${MAX_SERVICES_NUM}"
    It 'run_test'
      When run test_SERVICES_EXCLUDED_FILTERS_default "${TEST_NAME}" "${SERVICE_NAME}" "${MAX_SERVICES_NUM}"
      The status should be success
      The stdout should satisfy display_output
      The stdout should satisfy spec_expect_no_message ".+"
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_no_message "${START_WITHOUT_A_SQUARE_BRACKET}"
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
      The stderr should satisfy spec_expect_message    "${NO_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATE_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_ERRORS}"
      The stderr should satisfy spec_expect_message    "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_no_message "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${DONE_REMOVING_IMAGES}"
    End
  End
  Describe "test_SERVICES_EXCLUDED_FILTERS_bad"
    TEST_NAME="test_SERVICES_EXCLUDED_FILTERS_bad"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    test_SERVICES_EXCLUDED_FILTERS_bad() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      reset_gantry_env "${SERVICE_NAME}"
      export GANTRY_SERVICES_EXCLUDED_FILTERS="BadFilterValue"
      run_gantry "${TEST_NAME}"
    }
    BeforeEach "common_setup_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_SERVICES_EXCLUDED_FILTERS_bad "${TEST_NAME}" "${SERVICE_NAME}"
      The status should be failure
      The stdout should satisfy display_output
      The stdout should satisfy spec_expect_no_message ".+"
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_no_message "${START_WITHOUT_A_SQUARE_BRACKET}"
      The stderr should satisfy spec_expect_message    "Failed to obtain services list.*"
      The stderr should satisfy spec_expect_message    "${SKIP_UPDATING_ALL}.*${SKIP_REASON_PREVIOUS_ERRORS}"
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
      The stderr should satisfy spec_expect_message    "${NO_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATE_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_ERRORS}"
      The stderr should satisfy spec_expect_message    "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_no_message "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${DONE_REMOVING_IMAGES}"
    End
  End
End # Describe 'Filters'