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

Describe 'service-parallel'
  SUITE_NAME="service-parallel"
  BeforeAll "initialize_all_tests ${SUITE_NAME}"
  AfterAll "finish_all_tests ${SUITE_NAME}"
  Describe "test_parallel_less_workers" "container_test:true"
    TEST_NAME="test_parallel_less_workers"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME="gantry-test-$(unique_id)"
    MANIFEST_NUM_WORKERS=2
    MAX_SERVICES_NUM=6
    MAX_NO_NEW_IMAGE=3
    test_start() {
      local TEST_NAME="${1}"
      local IMAGE_WITH_TAG="${2}"
      local SERVICE_NAME="${3}"
      local MAX_SERVICES_NUM="${4}"
      local MAX_NO_NEW_IMAGE="${5}"
      common_setup_new_image_multiple "${TEST_NAME}" "${IMAGE_WITH_TAG}" "${SERVICE_NAME}" "${MAX_SERVICES_NUM}"
      local NO_NEW_IAMGE_START=$((MAX_SERVICES_NUM+1))
      local NO_NEW_IAMGE_END=$((MAX_SERVICES_NUM+MAX_NO_NEW_IMAGE))
      local NUM=
      local PIDS=
      for NUM in $(seq "${NO_NEW_IAMGE_START}" "${NO_NEW_IAMGE_END}"); do
        local SERVICE_NAME_NUM="${SERVICE_NAME}-${NUM}"
        start_replicated_service "${SERVICE_NAME_NUM}" "${IMAGE_WITH_TAG}" &
        PIDS="${!} ${PIDS}"
      done
      # SC2086 (info): Double quote to prevent globbing and word splitting.
      # shellcheck disable=SC2086
      wait ${PIDS}
    }
    test_parallel_less_workers() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      local MAX_SERVICES_NUM="${3}"
      reset_gantry_env "${SERVICE_NAME}"
      export GANTRY_MANIFEST_NUM_WORKERS="${MANIFEST_NUM_WORKERS}"
      export GANTRY_UPDATE_NUM_WORKERS=$((MAX_SERVICES_NUM/2+1))
      run_gantry "${TEST_NAME}"
    }
    BeforeEach "test_start ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME} ${MAX_SERVICES_NUM} ${MAX_NO_NEW_IMAGE}"
    AfterEach "common_cleanup_multiple ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME} $((MAX_SERVICES_NUM+MAX_NO_NEW_IMAGE))"
    It 'run_test'
      When run test_parallel_less_workers "${TEST_NAME}" "${SERVICE_NAME}" "${MAX_SERVICES_NUM}"
      The status should be success
      The stdout should satisfy display_output
      The stderr should satisfy display_output
      for NUM in $(seq 0 "${MAX_SERVICES_NUM}"); do
        SERVICE_NAME_NUM="${SERVICE_NAME}-${NUM}"
        The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.* ${SERVICE_NAME_NUM} "
        # Since we set GANTRY_MANIFEST_NUM_WORKERS larger than 1, we do not check reason here.
        The stderr should satisfy spec_expect_message    "${PERFORM_UPDATING}.* ${SERVICE_NAME_NUM}"
        The stderr should satisfy spec_expect_message    "${UPDATED}.* ${SERVICE_NAME_NUM}"
      done
      for NUM in $(seq "$((MAX_SERVICES_NUM+1))" "$((MAX_SERVICES_NUM+MAX_NO_NEW_IMAGE))"); do
        SERVICE_NAME_NUM="${SERVICE_NAME}-${NUM}"
        # Since we set GANTRY_MANIFEST_NUM_WORKERS larger than 1, we do not check reason here.
        The stderr should satisfy spec_expect_message    "${SKIP_UPDATING}.* ${SERVICE_NAME_NUM}"
        The stderr should satisfy spec_expect_no_message "${PERFORM_UPDATING}.* ${SERVICE_NAME_NUM} "
        The stderr should satisfy spec_expect_no_message "${UPDATED}.* ${SERVICE_NAME_NUM} "
      done
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_SKIP_JOBS}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_INSPECT_FAILURE}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_NO_NEW_IMAGES}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_UPDATING}"
      The stderr should satisfy spec_expect_no_message "${NO_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_message    "$((MAX_SERVICES_NUM+1)) ${SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATE_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_ERRORS}"
      The stderr should satisfy spec_expect_no_message "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_message    "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_message    "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
    End
  End
  Describe "test_parallel_more_workers" "container_test:true"
    TEST_NAME="test_parallel_more_workers"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME="gantry-test-$(unique_id)"
    MANIFEST_NUM_WORKERS=2
    MAX_SERVICES_NUM=10
    test_parallel_more_workers() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      local MAX_SERVICES_NUM="${3}"
      reset_gantry_env "${SERVICE_NAME}"
      export GANTRY_MANIFEST_NUM_WORKERS="${MANIFEST_NUM_WORKERS}"
      export GANTRY_UPDATE_NUM_WORKERS=$((MAX_SERVICES_NUM*3))
      run_gantry "${TEST_NAME}"
    }
    BeforeEach "common_setup_new_image_multiple ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME} ${MAX_SERVICES_NUM}"
    AfterEach "common_cleanup_multiple ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME} ${MAX_SERVICES_NUM}"
    It 'run_test'
      When run test_parallel_more_workers "${TEST_NAME}" "${SERVICE_NAME}" "${MAX_SERVICES_NUM}"
      The status should be success
      The stdout should satisfy display_output
      The stderr should satisfy display_output
      for NUM in $(seq 0 "${MAX_SERVICES_NUM}"); do
        SERVICE_NAME_NUM="${SERVICE_NAME}-${NUM}"
        The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.* ${SERVICE_NAME_NUM} "
        # Since we set GANTRY_MANIFEST_NUM_WORKERS larger than 1, we do not check reason here.
        The stderr should satisfy spec_expect_message    "${PERFORM_UPDATING}.* ${SERVICE_NAME_NUM}"
        The stderr should satisfy spec_expect_message    "${UPDATED}.* ${SERVICE_NAME_NUM}"
      done
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_SKIP_JOBS}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_INSPECT_FAILURE}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_NO_NEW_IMAGES}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_UPDATING}"
      The stderr should satisfy spec_expect_no_message "${NO_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_message    "$((MAX_SERVICES_NUM+1)) ${SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATE_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_ERRORS}"
      The stderr should satisfy spec_expect_no_message "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_message    "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_message    "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
    End
  End
  Describe "test_parallel_GANTRY_MANIFEST_NUM_WORKERS_not_a_number" "container_test:false"
    TEST_NAME="test_parallel_GANTRY_MANIFEST_NUM_WORKERS_not_a_number"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME="gantry-test-$(unique_id)"
    test_parallel_GANTRY_MANIFEST_NUM_WORKERS_not_a_number() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      reset_gantry_env "${SERVICE_NAME}"
      export GANTRY_MANIFEST_NUM_WORKERS="NotANumber"
      run_gantry "${TEST_NAME}"
    }
    BeforeEach "common_setup_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_parallel_GANTRY_MANIFEST_NUM_WORKERS_not_a_number "${TEST_NAME}" "${SERVICE_NAME}"
      The status should be failure
      The stdout should satisfy display_output
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_message    "GANTRY_MANIFEST_NUM_WORKERS ${MUST_BE_A_NUMBER}.*"
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${PERFORM_UPDATING}.*${SERVICE_NAME}.*${PERFORM_REASON_HAS_NEWER_IMAGE}"
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
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_ERRORS}"
      The stderr should satisfy spec_expect_message    "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_no_message "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
    End
  End
  Describe "test_parallel_GANTRY_UPDATE_NUM_WORKERS_not_a_number" "container_test:false"
    TEST_NAME="test_parallel_GANTRY_UPDATE_NUM_WORKERS_not_a_number"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME="gantry-test-$(unique_id)"
    test_parallel_GANTRY_UPDATE_NUM_WORKERS_not_a_number() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      reset_gantry_env "${SERVICE_NAME}"
      export GANTRY_UPDATE_NUM_WORKERS="NotANumber"
      run_gantry "${TEST_NAME}"
    }
    BeforeEach "common_setup_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_parallel_GANTRY_UPDATE_NUM_WORKERS_not_a_number "${TEST_NAME}" "${SERVICE_NAME}"
      The status should be failure
      The stdout should satisfy display_output
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_message    "GANTRY_UPDATE_NUM_WORKERS ${MUST_BE_A_NUMBER}.*"
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${PERFORM_UPDATING}.*${SERVICE_NAME}.*${PERFORM_REASON_HAS_NEWER_IMAGE}"
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
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_ERRORS}"
      The stderr should satisfy spec_expect_message    "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_no_message "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
    End
  End
End # Describe 'Multiple services'
