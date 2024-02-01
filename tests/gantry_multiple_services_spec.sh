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

Describe 'Multiple_services'
  SUITE_NAME="Multiple_services"
  BeforeAll "initialize_all_tests ${SUITE_NAME}"
  AfterAll "finish_all_tests ${SUITE_NAME}"
  Describe "test_multiple_services_excluded_filters" "container_test:true"
    TEST_NAME="test_multiple_services_excluded_filters"
    IMAGE_WITH_TAG=$(get_image_with_tag)
    SERVICE_NAME="gantry-test-$(unique_id)"
    SERVICE_NAME0="${SERVICE_NAME}-0"
    SERVICE_NAME1="${SERVICE_NAME}-1"
    SERVICE_NAME2="${SERVICE_NAME}-2"
    SERVICE_NAME3="${SERVICE_NAME}-3"
    SERVICE_NAME4="${SERVICE_NAME}-4"
    SERVICE_NAME5="${SERVICE_NAME}-5"
    test_start() {
      local TEST_NAME=${1}
      local IMAGE_WITH_TAG=${2}
      local SERVICE_NAME=${3}
      local SERVICE_NAME0="${SERVICE_NAME}-0"
      local SERVICE_NAME1="${SERVICE_NAME}-1"
      local SERVICE_NAME2="${SERVICE_NAME}-2"
      local SERVICE_NAME3="${SERVICE_NAME}-3"
      local SERVICE_NAME4="${SERVICE_NAME}-4"
      local SERVICE_NAME5="${SERVICE_NAME}-5"

      initialize_test "${TEST_NAME}"
      build_and_push_test_image "${IMAGE_WITH_TAG}"
      start_replicated_service "${SERVICE_NAME0}" "${IMAGE_WITH_TAG}"
      start_replicated_service "${SERVICE_NAME1}" "${IMAGE_WITH_TAG}"
      start_replicated_service "${SERVICE_NAME2}" "${IMAGE_WITH_TAG}"
      start_replicated_service "${SERVICE_NAME3}" "${IMAGE_WITH_TAG}"
      build_and_push_test_image "${IMAGE_WITH_TAG}"
      start_replicated_service "${SERVICE_NAME4}" "${IMAGE_WITH_TAG}"
      start_replicated_service "${SERVICE_NAME5}" "${IMAGE_WITH_TAG}"

      export GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
      # test both the list of names and the filters
      export GANTRY_SERVICES_EXCLUDED="${SERVICE_NAME1}"
      export GANTRY_SERVICES_EXCLUDED_FILTERS="name=${SERVICE_NAME2}"
    }
    test_end() {
      local TEST_NAME=${1}
      local IMAGE_WITH_TAG=${2}
      local SERVICE_NAME=${3}
      local SERVICE_NAME0="${SERVICE_NAME}-0"
      local SERVICE_NAME1="${SERVICE_NAME}-1"
      local SERVICE_NAME2="${SERVICE_NAME}-2"
      local SERVICE_NAME3="${SERVICE_NAME}-3"
      local SERVICE_NAME4="${SERVICE_NAME}-4"
      local SERVICE_NAME5="${SERVICE_NAME}-5"
      stop_service "${SERVICE_NAME5}"
      stop_service "${SERVICE_NAME4}"
      stop_service "${SERVICE_NAME3}"
      stop_service "${SERVICE_NAME2}"
      stop_service "${SERVICE_NAME1}"
      stop_service "${SERVICE_NAME0}"
      prune_local_test_image "${IMAGE_WITH_TAG}"
      finalize_test "${TEST_NAME}"
    }
    Before "test_start ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    After "test_end ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_gantry'
      When call run_gantry "${TEST_NAME}"
      The status should be success
      The stdout should satisfy display_output
      The stderr should satisfy display_output
      # Service 0 and 3 should get updated.
      # Service 1 and 2 should be excluded.
      # Service 4 and 5 created with new image, no update.
      # Failed to remove the image as service 1 and 2 are still using it.
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING_JOB}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${PERFORM_UPDATING}.*${SERVICE_NAME0}.*${REASON_HAS_NEWER_IMAGE}"
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.*${SERVICE_NAME1}"
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.*${SERVICE_NAME2}"
      The stderr should satisfy spec_expect_message    "${PERFORM_UPDATING}.*${SERVICE_NAME3}.*${REASON_KNOWN_NEWER_IMAGE}"
      The stderr should satisfy spec_expect_message    "${SKIP_UPDATING}.*${SERVICE_NAME4}.*${REASON_CURRENT_IS_LATEST}"
      The stderr should satisfy spec_expect_message    "${SKIP_UPDATING}.*${SERVICE_NAME5}.*${REASON_NO_KNOWN_NEWER_IMAGE}"
      The stderr should satisfy spec_expect_no_message "${SERVICE_NAME0}.*${NO_NEW_IMAGE}"
      The stderr should satisfy spec_expect_no_message "${SERVICE_NAME1}.*${NO_NEW_IMAGE}"
      The stderr should satisfy spec_expect_no_message "${SERVICE_NAME2}.*${NO_NEW_IMAGE}"
      The stderr should satisfy spec_expect_no_message "${SERVICE_NAME3}.*${NO_NEW_IMAGE}"
      The stderr should satisfy spec_expect_message    "${SERVICE_NAME4}.*${NO_NEW_IMAGE}"
      The stderr should satisfy spec_expect_message    "${SERVICE_NAME5}.*${NO_NEW_IMAGE}"
      The stderr should satisfy spec_expect_message    "${SERVICE_NAME0}.*${UPDATED}"
      The stderr should satisfy spec_expect_no_message "${SERVICE_NAME1}.*${UPDATED}"
      The stderr should satisfy spec_expect_no_message "${SERVICE_NAME2}.*${UPDATED}"
      The stderr should satisfy spec_expect_message    "${SERVICE_NAME3}.*${UPDATED}"
      The stderr should satisfy spec_expect_no_message "${SERVICE_NAME4}.*${UPDATED}"
      The stderr should satisfy spec_expect_no_message "${SERVICE_NAME5}.*${UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NO_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATE_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_message    "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_message    "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
    End
  End
End # Describe 'Multiple services'
