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

# Test cleanup images related options.
Describe 'Cleanup_images'
  SUITE_NAME="Cleanup_images"
  BeforeAll "initialize_all_tests ${SUITE_NAME}"
  AfterAll "finish_all_tests ${SUITE_NAME}"
  Describe "test_CLEANUP_IMAGES_false" "container_test:true"
    TEST_NAME="test_CLEANUP_IMAGES_false"
    IMAGE_WITH_TAG=$(get_image_with_tag)
    SERVICE_NAME="gantry-test-$(unique_id)"
    test_CLEANUP_IMAGES_false() {
      local TEST_NAME=${1}
      export GANTRY_CLEANUP_IMAGES="false"
      run_gantry "${TEST_NAME}"
    }
    Before "common_setup_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    After "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_gantry'
      When call test_CLEANUP_IMAGES_false "${TEST_NAME}"
      The status should be success
      The stdout should satisfy display_output
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${PERFORM_UPDATING}.*${SERVICE_NAME}.*${PERFORM_REASON_HAS_NEWER_IMAGE}"
      The stderr should satisfy spec_expect_no_message "${NO_NEW_IMAGE}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${UPDATED}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_UPDATES}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLING_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLED_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATE_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_no_message "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_message    "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
    End
  End
  Describe "test_CLEANUP_IMAGES_OPTIONS_bad" "container_test:true"
    TEST_NAME="test_CLEANUP_IMAGES_OPTIONS_bad"
    IMAGE_WITH_TAG=$(get_image_with_tag)
    SERVICE_NAME="gantry-test-$(unique_id)"
    test_CLEANUP_IMAGES_OPTIONS_bad() {
      local TEST_NAME=${1}
      export GANTRY_CLEANUP_IMAGES="true"
      # Image remover would fail due to the incorrect option.
      export GANTRY_CLEANUP_IMAGES_OPTIONS="--incorrect-option"
      run_gantry "${TEST_NAME}"
    }
    Before "common_setup_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    After "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_gantry'
      When call test_CLEANUP_IMAGES_OPTIONS_bad "${TEST_NAME}"
      The status should be success
      The stdout should satisfy display_output
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${PERFORM_UPDATING}.*${SERVICE_NAME}.*${PERFORM_REASON_HAS_NEWER_IMAGE}"
      The stderr should satisfy spec_expect_no_message "${NO_NEW_IMAGE}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${UPDATED}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_UPDATES}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLING_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLED_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATE_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_message    "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_message    "${ADDING_OPTIONS}.*${GANTRY_CLEANUP_IMAGES_OPTIONS}"
      The stderr should satisfy spec_expect_message    "${FAILED_TO_REMOVE_IMAGE}.*${GANTRY_CLEANUP_IMAGES_OPTIONS}"
      The stderr should satisfy spec_expect_no_message "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
    End
  End
  Describe "test_CLEANUP_IMAGES_OPTIONS_good" "container_test:true"
    TEST_NAME="test_CLEANUP_IMAGES_OPTIONS_good"
    IMAGE_WITH_TAG=$(get_image_with_tag)
    SERVICE_NAME="gantry-test-$(unique_id)"
    test_CLEANUP_IMAGES_OPTIONS_good() {
      local TEST_NAME=${1}
      export GANTRY_CLEANUP_IMAGES="true"
      export GANTRY_CLEANUP_IMAGES_OPTIONS="--container-label=test"
      run_gantry "${TEST_NAME}"
    }
    Before "common_setup_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    After "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_gantry'
      When call test_CLEANUP_IMAGES_OPTIONS_good "${TEST_NAME}"
      The status should be success
      The stdout should satisfy display_output
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${PERFORM_UPDATING}.*${SERVICE_NAME}.*${PERFORM_REASON_HAS_NEWER_IMAGE}"
      The stderr should satisfy spec_expect_no_message "${NO_NEW_IMAGE}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${UPDATED}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_UPDATES}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLING_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLED_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATE_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_message    "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_message    "${ADDING_OPTIONS}.*${GANTRY_CLEANUP_IMAGES_OPTIONS}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*${GANTRY_CLEANUP_IMAGES_OPTIONS}"
      The stderr should satisfy spec_expect_message    "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
    End
  End
End # Describe 'Single service'
