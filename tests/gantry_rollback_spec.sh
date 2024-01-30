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

Describe 'Rollback'
  SUITE_NAME="Rollback"
  BeforeAll "initialize_all_tests ${SUITE_NAME}"
  AfterAll "finish_all_tests ${SUITE_NAME}"
  Describe "test_rollback_due_to_timeout"
    TEST_NAME="test_rollback_due_to_timeout"
    IMAGE_WITH_TAG=$(get_image_with_tag)
    SERVICE_NAME="gantry-test-$(unique_id)"
    Before "common_setup_timeout ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    After "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_gantry'
      When call run_gantry "${TEST_NAME}"
      The status should be failure
      The stdout should satisfy display_output
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING_JOB}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_NEW_IMAGE}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${UPDATED}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_UPDATES}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${ROLLING_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${ROLLED_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${NO_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_UPDATE_FAILED}"
      The stderr should satisfy spec_expect_message    "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_no_message "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
    End
  End
  Describe "test_rollback_failed"
    TEST_NAME="test_rollback_failed"
    IMAGE_WITH_TAG=$(get_image_with_tag)
    SERVICE_NAME="gantry-test-$(unique_id)"
    test_rollback_failed() {
      local TEST_NAME=${1}
      # Rollback would fail due to the incorrect option.
      export GANTRY_ROLLBACK_OPTIONS="--incorrect-option"
      run_gantry "${TEST_NAME}"
    }
    Before "common_setup_timeout ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    After "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_gantry'
      When call test_rollback_failed "${TEST_NAME}"
      The status should be failure
      The stdout should satisfy display_output
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING_JOB}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_NEW_IMAGE}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${UPDATED}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_UPDATES}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${ADDING_OPTIONS}.*${GANTRY_ROLLBACK_OPTIONS}"
      The stderr should satisfy spec_expect_message    "${ROLLING_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLED_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${NO_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_UPDATE_FAILED}"
      The stderr should satisfy spec_expect_message    "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_no_message "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
    End
  End
  Describe "test_rollback_ROLLBACK_ON_FAILURE_false"
    TEST_NAME="test_rollback_ROLLBACK_ON_FAILURE_false"
    IMAGE_WITH_TAG=$(get_image_with_tag)
    SERVICE_NAME="gantry-test-$(unique_id)"
    test_rollback_ROLLBACK_ON_FAILURE_false() {
      local TEST_NAME=${1}
      export GANTRY_ROLLBACK_ON_FAILURE="false"
      run_gantry "${TEST_NAME}"
    }
    Before "common_setup_timeout ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    After "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_gantry'
      When call test_rollback_ROLLBACK_ON_FAILURE_false "${TEST_NAME}"
      The status should be failure
      The stdout should satisfy display_output
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING_JOB}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_NEW_IMAGE}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${UPDATED}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_UPDATES}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLING_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLED_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${NO_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_UPDATE_FAILED}"
      The stderr should satisfy spec_expect_message    "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_no_message "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
    End
  End
End # Describe 'Rollback'
