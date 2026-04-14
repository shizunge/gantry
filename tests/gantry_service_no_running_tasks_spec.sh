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

docker_service_replicas() {
  local SERVICE_NAME="${1}"
  local REPLICAS=
  if ! REPLICAS=$(run_cmd docker service ls --filter "name=${SERVICE_NAME}" --format '{{.Replicas}} {{.Name}}'); then
    echo "docker service ls failed. ${REPLICAS}"
    return 1
  fi
  # For `docker service ls --filter`, the name filter matches on all or the prefix of a service's name
  # See https://docs.docker.com/engine/reference/commandline/service_ls/#name
  # It does not do the exact match of the name. See https://github.com/moby/moby/issues/32985
  # We do an extra step to to perform the exact match.
  echo "${REPLICAS}" | sed -n -E "s/(.*) ${SERVICE_NAME}$/\1/p"
}

Describe "service-no-running-tasks"
  SUITE_NAME="service-no-running-tasks"
  BeforeAll "initialize_all_tests ${SUITE_NAME}"
  AfterAll "finish_all_tests ${SUITE_NAME}"
  Describe "test_no_running_tasks_replicated"
    # For `docker service ls --filter`, the name filter matches on all or the prefix of a service's name
    # See https://docs.docker.com/engine/reference/commandline/service_ls/#name
    # It does not do the exact match of the name. See https://github.com/moby/moby/issues/32985
    # This test also checks whether we do an extra step to to perform the exact match.
    TEST_NAME="test_no_running_tasks_replicated"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    SERVICE_NAME_SUFFIX="${SERVICE_NAME}-suffix"
    test_start() {
      local TEST_NAME="${1}"
      local IMAGE_WITH_TAG="${2}"
      local SERVICE_NAME="${3}"
      local SERVICE_NAME_SUFFIX="${SERVICE_NAME}-suffix"
      initialize_test "${TEST_NAME}"
      build_and_push_test_image "${IMAGE_WITH_TAG}"
      start_replicated_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
      start_replicated_service "${SERVICE_NAME_SUFFIX}" "${IMAGE_WITH_TAG}"
      build_and_push_test_image "${IMAGE_WITH_TAG}"
      # Set running tasks to 0 for SERVICE_NAME.
      # But keep tasks running for SERVICE_NAME_SUFFIX.
      docker_service_update --replicas=0 "${SERVICE_NAME}"
      wait_zero_running_tasks "${SERVICE_NAME}"
    }
    test_no_running_tasks_replicated() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      local REPLICAS_BEFORE=
      REPLICAS_BEFORE=$(docker_service_replicas "${SERVICE_NAME}")
      echo "Before updating: REPLICAS_BEFORE=${REPLICAS_BEFORE}"
      reset_gantry_env "${SUITE_NAME}" "${SERVICE_NAME}"
      local RETURN_VALUE=
      run_gantry "${SUITE_NAME}" "${TEST_NAME}"
      RETURN_VALUE="${?}"
      local REPLICAS_AFTER=
      REPLICAS_AFTER=$(docker_service_replicas "${SERVICE_NAME}")
      echo "After updating: REPLICAS_AFTER=${REPLICAS_AFTER}"
      return "${RETURN_VALUE}"
    }
    test_end() {
      local TEST_NAME="${1}"
      local IMAGE_WITH_TAG="${2}"
      local SERVICE_NAME="${3}"
      local SERVICE_NAME_SUFFIX="${SERVICE_NAME}-suffix"
      stop_service "${SERVICE_NAME}"
      stop_service "${SERVICE_NAME_SUFFIX}"
      prune_local_test_image "${IMAGE_WITH_TAG}"
      finalize_test "${TEST_NAME}"
    }
    BeforeEach "test_start ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "test_end ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_no_running_tasks_replicated "${TEST_NAME}" "${SERVICE_NAME}"
      The status should be success
      The stdout should satisfy display_output
      The stdout should satisfy spec_expect_message    "Before updating: REPLICAS_BEFORE=0/0"
      The stdout should satisfy spec_expect_message    "After updating: REPLICAS_AFTER=0/0"
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_no_message "${START_WITHOUT_A_SQUARE_BRACKET}"
      # Add "--detach=true" when there is no running tasks.
      # https://github.com/docker/cli/issues/627
      The stderr should satisfy spec_expect_message    "${ADDING_OPTIONS}.*--detach=true.*${AUTOMATICALLY}.*${SERVICE_NAME}\."
      The stderr should satisfy spec_expect_no_message "${ADDING_OPTIONS}.*--replicas=.*${SERVICE_NAME}\."
      The stderr should satisfy spec_expect_no_message "${ADDING_OPTIONS}.*--detach.*${SERVICE_NAME_SUFFIX}"
      The stderr should satisfy spec_expect_no_message "${ADDING_OPTIONS}.*--replicas.*${SERVICE_NAME_SUFFIX}"
      The stderr should satisfy spec_expect_message    "${SERVICE_NAME}.*${REPLICATED_MODE_NO_RUNNING_TASK}"
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${PERFORM_UPDATING}.*${SERVICE_NAME}.*${PERFORM_REASON_HAS_NEWER_IMAGE}"
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.*${SERVICE_NAME_SUFFIX}"
      The stderr should satisfy spec_expect_message    "${PERFORM_UPDATING}.*${SERVICE_NAME_SUFFIX}.*${PERFORM_REASON_KNOWN_NEWER_IMAGE}"
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
      The stderr should satisfy spec_expect_message    "2 ${SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATE_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_INSPECT_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_ROLLBACK_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_ERRORS}"
      The stderr should satisfy spec_expect_no_message "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_message    "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_message    "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_message    "${DONE_REMOVING_IMAGES}"
    End
  End
  Describe "test_no_running_tasks_replicated_user_replicas"
    # For `docker service ls --filter`, the name filter matches on all or the prefix of a service's name
    # See https://docs.docker.com/engine/reference/commandline/service_ls/#name
    # It does not do the exact match of the name. See https://github.com/moby/moby/issues/32985
    # This test also checks whether we do an extra step to to perform the exact match.
    TEST_NAME="test_no_running_tasks_replicated_user_replicas"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    SERVICE_NAME_SUFFIX="${SERVICE_NAME}-suffix"
    test_start() {
      local TEST_NAME="${1}"
      local IMAGE_WITH_TAG="${2}"
      local SERVICE_NAME="${3}"
      local SERVICE_NAME_SUFFIX="${SERVICE_NAME}-suffix"
      initialize_test "${TEST_NAME}"
      build_and_push_test_image "${IMAGE_WITH_TAG}"
      start_replicated_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
      start_replicated_service "${SERVICE_NAME_SUFFIX}" "${IMAGE_WITH_TAG}"
      build_and_push_test_image "${IMAGE_WITH_TAG}"
      # Set running tasks to 0 for SERVICE_NAME.
      # But keep tasks running for SERVICE_NAME_SUFFIX.
      docker_service_update --replicas=0 "${SERVICE_NAME}"
      wait_zero_running_tasks "${SERVICE_NAME}"
    }
    test_no_running_tasks_replicated_user_replicas() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      local REPLICAS_BEFORE=
      REPLICAS_BEFORE=$(docker_service_replicas "${SERVICE_NAME}")
      echo "Before updating: REPLICAS_BEFORE=${REPLICAS_BEFORE}"
      reset_gantry_env "${SUITE_NAME}" "${SERVICE_NAME}"
      # The user specified option "--replicas=" prevents a warning.
      local LABEL_AND_VALUE="gantry.update.options=--replicas=1"
      docker_service_update --label-add "${LABEL_AND_VALUE}" "${SERVICE_NAME}"
      local RETURN_VALUE=
      run_gantry "${SUITE_NAME}" "${TEST_NAME}"
      RETURN_VALUE="${?}"
      local REPLICAS_AFTER=
      REPLICAS_AFTER=$(docker_service_replicas "${SERVICE_NAME}")
      echo "After updating: REPLICAS_AFTER=${REPLICAS_AFTER}"
      return "${RETURN_VALUE}"
    }
    test_end() {
      local TEST_NAME="${1}"
      local IMAGE_WITH_TAG="${2}"
      local SERVICE_NAME="${3}"
      local SERVICE_NAME_SUFFIX="${SERVICE_NAME}-suffix"
      stop_service "${SERVICE_NAME}"
      stop_service "${SERVICE_NAME_SUFFIX}"
      prune_local_test_image "${IMAGE_WITH_TAG}"
      finalize_test "${TEST_NAME}"
    }
    BeforeEach "test_start ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "test_end ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_no_running_tasks_replicated_user_replicas "${TEST_NAME}" "${SERVICE_NAME}"
      The status should be success
      The stdout should satisfy display_output
      The stdout should satisfy spec_expect_message    "Before updating: REPLICAS_BEFORE=0/0"
      The stdout should satisfy spec_expect_message    "After updating: REPLICAS_AFTER=1/1"
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_no_message "${START_WITHOUT_A_SQUARE_BRACKET}"
      # Add "--detach=true" when there is no running tasks.
      # https://github.com/docker/cli/issues/627
      The stderr should satisfy spec_expect_message    "${ADDING_OPTIONS}.*--detach=true.*${AUTOMATICALLY}.*${SERVICE_NAME}\."
      The stderr should satisfy spec_expect_message    "${ADDING_OPTIONS}.*--replicas=1.*${SPECIFIED_BY_USER}.*${SERVICE_NAME}\."
      The stderr should satisfy spec_expect_no_message "${ADDING_OPTIONS}.*--detach.*${SERVICE_NAME_SUFFIX}"
      The stderr should satisfy spec_expect_no_message "${ADDING_OPTIONS}.*--replicas.*${SERVICE_NAME_SUFFIX}"
      The stderr should satisfy spec_expect_no_message "${SERVICE_NAME}.*${REPLICATED_MODE_NO_RUNNING_TASK}"
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${PERFORM_UPDATING}.*${SERVICE_NAME}.*${PERFORM_REASON_HAS_NEWER_IMAGE}"
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.*${SERVICE_NAME_SUFFIX}"
      The stderr should satisfy spec_expect_message    "${PERFORM_UPDATING}.*${SERVICE_NAME_SUFFIX}.*${PERFORM_REASON_KNOWN_NEWER_IMAGE}"
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
      The stderr should satisfy spec_expect_message    "2 ${SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATE_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_INSPECT_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_ROLLBACK_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_ERRORS}"
      The stderr should satisfy spec_expect_no_message "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_message    "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_message    "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_message    "${DONE_REMOVING_IMAGES}"
    End
  End
  Describe "test_no_running_tasks_global"
    TEST_NAME="test_no_running_tasks_global"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    test_start() {
      local TEST_NAME="${1}"
      local IMAGE_WITH_TAG="${2}"
      local SERVICE_NAME="${3}"
      local TASK_SECONDS=15
      local TIMEOUT_SECONDS=1
      initialize_test "${TEST_NAME}"
      # The task will finish in ${TASK_SECONDS} seconds
      build_and_push_test_image "${IMAGE_WITH_TAG}" "${TASK_SECONDS}"
      start_global_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}" "${TIMEOUT_SECONDS}"
      build_and_push_test_image "${IMAGE_WITH_TAG}"
      # The tasks should exit after TASK_SECONDS seconds sleep. Then it will have 0 running tasks.
      wait_zero_running_tasks "${SERVICE_NAME}"
    }
    test_no_running_tasks_global() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      reset_gantry_env "${SUITE_NAME}" "${SERVICE_NAME}"
      run_gantry "${SUITE_NAME}" "${TEST_NAME}"
    }
    BeforeEach "test_start ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_no_running_tasks_global "${TEST_NAME}" "${SERVICE_NAME}"
      The status should be success
      The stdout should satisfy display_output
      The stdout should satisfy spec_expect_no_message ".+"
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_no_message "${START_WITHOUT_A_SQUARE_BRACKET}"
      # Add "--detach=true" when there is no running tasks.
      # https://github.com/docker/cli/issues/627
      The stderr should satisfy spec_expect_message    "${ADDING_OPTIONS}.*--detach=true.*${AUTOMATICALLY}.*${SERVICE_NAME}"
      # Cannot add "--replicas" to global mode
      The stderr should satisfy spec_expect_no_message "${ADDING_OPTIONS}.*--replicas"
      The stderr should satisfy spec_expect_no_message "${SERVICE_NAME}.*${REPLICATED_MODE_NO_RUNNING_TASK}"
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
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_INSPECT_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_ROLLBACK_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_ERRORS}"
      The stderr should satisfy spec_expect_no_message "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_message    "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_message    "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_message    "${DONE_REMOVING_IMAGES}"
    End
  End
End # Describe "No Running Tasks"
