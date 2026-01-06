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

Describe 'service-multiple-services'
  SUITE_NAME="service-multiple-services"
  BeforeAll "initialize_all_tests ${SUITE_NAME}"
  AfterAll "finish_all_tests ${SUITE_NAME}"
  Describe "test_multiple_services_excluded_filters"
    TEST_NAME="test_multiple_services_excluded_filters"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    SERVICE_NAME0="${SERVICE_NAME}-0"
    SERVICE_NAME1="${SERVICE_NAME}-1"
    SERVICE_NAME2="${SERVICE_NAME}-2"
    SERVICE_NAME3="${SERVICE_NAME}-3"
    SERVICE_NAME4="${SERVICE_NAME}-4"
    SERVICE_NAME5="${SERVICE_NAME}-5"
    test_start() {
      local TEST_NAME="${1}"
      local IMAGE_WITH_TAG="${2}"
      local SERVICE_NAME="${3}"
      initialize_test "${TEST_NAME}"
      build_and_push_test_image "${IMAGE_WITH_TAG}"
      start_multiple_replicated_services "${SERVICE_NAME}" "${IMAGE_WITH_TAG}" 0 3
      build_and_push_test_image "${IMAGE_WITH_TAG}"
      start_multiple_replicated_services "${SERVICE_NAME}" "${IMAGE_WITH_TAG}" 4 5
    }
    test_multiple_services_excluded_filters() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      local SERVICE_NAME1="${SERVICE_NAME}-1"
      local SERVICE_NAME2="${SERVICE_NAME}-2"
      reset_gantry_env "${SUITE_NAME}" "${SERVICE_NAME}"
      # test both the list of names and the filters
      export GANTRY_SERVICES_EXCLUDED="${SERVICE_NAME1}"
      export GANTRY_SERVICES_EXCLUDED_FILTERS="name=${SERVICE_NAME2}"
      run_gantry "${SUITE_NAME}" "${TEST_NAME}"
    }
    test_end() {
      local TEST_NAME="${1}"
      local IMAGE_WITH_TAG="${2}"
      local SERVICE_NAME="${3}"
      stop_multiple_services "${SERVICE_NAME}" 0 5
      prune_local_test_image "${IMAGE_WITH_TAG}"
      finalize_test "${TEST_NAME}"
    }
    BeforeEach "test_start ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "test_end ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_multiple_services_excluded_filters "${TEST_NAME}" "${SERVICE_NAME}"
      The status should be success
      The stdout should satisfy display_output
      The stdout should satisfy spec_expect_no_message ".+"
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_no_message "${START_WITHOUT_A_SQUARE_BRACKET}"
      # Service 0 and 3 should get updated.
      # Service 1 and 2 should be excluded.
      # Service 4 and 5 created with new image, no update.
      # Failed to remove the image as service 1 and 2 are still using it.
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.*${SERVICE_NAME0}"
      The stderr should satisfy spec_expect_message    "${PERFORM_UPDATING}.*${SERVICE_NAME0}.*${PERFORM_REASON_HAS_NEWER_IMAGE}"
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.*${SERVICE_NAME1}"
      The stderr should satisfy spec_expect_no_message "${PERFORM_UPDATING}.*${SERVICE_NAME1}"
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.*${SERVICE_NAME2}"
      The stderr should satisfy spec_expect_no_message "${PERFORM_UPDATING}.*${SERVICE_NAME2}"
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.*${SERVICE_NAME3}"
      The stderr should satisfy spec_expect_message    "${PERFORM_UPDATING}.*${SERVICE_NAME3}.*${PERFORM_REASON_KNOWN_NEWER_IMAGE}"
      The stderr should satisfy spec_expect_message    "${SKIP_UPDATING}.*${SERVICE_NAME4}.*${SKIP_REASON_CURRENT_IS_LATEST}"
      The stderr should satisfy spec_expect_no_message "${PERFORM_UPDATING}.*${SERVICE_NAME4}"
      The stderr should satisfy spec_expect_message    "${SKIP_UPDATING}.*${SERVICE_NAME5}.*${SKIP_REASON_NO_KNOWN_NEWER_IMAGE}"
      The stderr should satisfy spec_expect_no_message "${PERFORM_UPDATING}.*${SERVICE_NAME5}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_SKIP_JOBS}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_INSPECT_FAILURE}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_NO_NEW_IMAGES}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_UPDATING}"
      The stderr should satisfy spec_expect_no_message "${ADDING_OPTIONS}"
      The stderr should satisfy spec_expect_no_message "${SET_TIMEOUT_TO}"
      The stderr should satisfy spec_expect_no_message "${RETURN_VALUE_INDICATES_TIMEOUT}"
      The stderr should satisfy spec_expect_no_message "${DOES_NOT_HAVE_A_DIGEST}"
      The stderr should satisfy spec_expect_message    "${UPDATED}.*${SERVICE_NAME0}"
      The stderr should satisfy spec_expect_no_message "${UPDATED}.*${SERVICE_NAME1}"
      The stderr should satisfy spec_expect_no_message "${UPDATED}.*${SERVICE_NAME2}"
      The stderr should satisfy spec_expect_message    "${UPDATED}.*${SERVICE_NAME3}"
      The stderr should satisfy spec_expect_no_message "${UPDATED}.*${SERVICE_NAME4}"
      The stderr should satisfy spec_expect_no_message "${UPDATED}.*${SERVICE_NAME5}"
      The stderr should satisfy spec_expect_no_message "${ROLLING_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLED_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_message    "2 ${SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATE_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_ERRORS}"
      The stderr should satisfy spec_expect_no_message "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_message    "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_message    "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
    End
  End
  Describe "test_multiple_services_update_twice"
    TEST_NAME="test_multiple_services_update_twice"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    SERVICE_NAME0="${SERVICE_NAME}-0"
    SERVICE_NAME1="${SERVICE_NAME}-1"
    SERVICE_NAME2="${SERVICE_NAME}-2"
    test_start() {
      local TEST_NAME="${1}"
      local IMAGE_WITH_TAG="${2}"
      local SERVICE_NAME="${3}"
      initialize_test "${TEST_NAME}"
      build_and_push_test_image "${IMAGE_WITH_TAG}"
      start_multiple_replicated_services "${SERVICE_NAME}" "${IMAGE_WITH_TAG}" 0 2
      build_and_push_test_image "${IMAGE_WITH_TAG}"
    }
    test_multiple_services_update_twice() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      local IMAGE_WITH_TAG="${3}"
      reset_gantry_env "${SUITE_NAME}" "${SERVICE_NAME}"
      run_gantry "${SUITE_NAME}" "${TEST_NAME}"
      build_and_push_test_image "${IMAGE_WITH_TAG}" >/dev/null 2>&1
      # Update the same service twice.
      run_gantry "${SUITE_NAME}" "${TEST_NAME}"
    }
    test_end() {
      local TEST_NAME="${1}"
      local IMAGE_WITH_TAG="${2}"
      local SERVICE_NAME="${3}"
      stop_multiple_services "${SERVICE_NAME}" 0 2
      prune_local_test_image "${IMAGE_WITH_TAG}"
      finalize_test "${TEST_NAME}"
    }
    BeforeEach "test_start ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "test_end ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_multiple_services_update_twice "${TEST_NAME}" "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
      The status should be success
      The stdout should satisfy display_output
      The stdout should satisfy spec_expect_no_message ".+"
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_no_message "${START_WITHOUT_A_SQUARE_BRACKET}"
      # Service 0 and 3 should get updated.
      # Service 1 and 2 should be excluded.
      # Failed to remove the image as service 1 and 2 are still using it.
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.*${SERVICE_NAME0}"
      The stderr should satisfy spec_expect_message    "${PERFORM_UPDATING}.*${SERVICE_NAME0}.*${PERFORM_REASON_HAS_NEWER_IMAGE}"
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.*${SERVICE_NAME1}"
      The stderr should satisfy spec_expect_message    "${PERFORM_UPDATING}.*${SERVICE_NAME1}.*${PERFORM_REASON_KNOWN_NEWER_IMAGE}"
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.*${SERVICE_NAME2}"
      The stderr should satisfy spec_expect_message    "${PERFORM_UPDATING}.*${SERVICE_NAME2}.*${PERFORM_REASON_KNOWN_NEWER_IMAGE}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_SKIP_JOBS}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_INSPECT_FAILURE}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_NO_NEW_IMAGES}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_UPDATING}"
      The stderr should satisfy spec_expect_no_message "${ADDING_OPTIONS}"
      The stderr should satisfy spec_expect_no_message "${SET_TIMEOUT_TO}"
      The stderr should satisfy spec_expect_no_message "${RETURN_VALUE_INDICATES_TIMEOUT}"
      The stderr should satisfy spec_expect_no_message "${DOES_NOT_HAVE_A_DIGEST}"
      The stderr should satisfy spec_expect_message    "${UPDATED}.*${SERVICE_NAME0}"
      The stderr should satisfy spec_expect_message    "${UPDATED}.*${SERVICE_NAME1}"
      The stderr should satisfy spec_expect_message    "${UPDATED}.*${SERVICE_NAME2}"
      The stderr should satisfy spec_expect_no_message "${ROLLING_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLED_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_message    "3 ${SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATE_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_ERRORS}"
      The stderr should satisfy spec_expect_no_message "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_message    "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_message    "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
    End
  End
End # Describe 'Multiple services'
