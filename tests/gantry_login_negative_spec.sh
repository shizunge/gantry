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

Describe 'login-negative'
  SUITE_NAME="login-negative"
  BeforeAll "initialize_all_tests ${SUITE_NAME} ENFORCE_LOGIN"
  AfterAll "finish_all_tests ${SUITE_NAME} ENFORCE_LOGIN"
  Describe "test_login_no_login"
    TEST_NAME="test_login_no_login"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    # When running with an Gantry image, docker buildx writes files to this folder which are owned by root.
    # Using a relative path, this the container will not write to the folder on the host.
    # So do not use an absolute path, otherwise we cannot remove this folder on the host.
    AUTH_CONFIG="C$(unique_id)"
    TEST_REGISTRY=$(load_test_registry "${SUITE_NAME}") || return 1
    test_login_no_login() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      reset_gantry_env "${SERVICE_NAME}"
      run_gantry "${TEST_NAME}"
    }
    BeforeEach "common_setup_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_login_no_login "${TEST_NAME}" "${SERVICE_NAME}" "${AUTH_CONFIG}" "${TEST_REGISTRY}" "${TEST_USERNAME}" "${TEST_PASSWORD}"
      The status should be failure
      The stdout should satisfy display_output
      The stdout should satisfy spec_expect_no_message ".+"
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_no_message "${START_WITHOUT_A_SQUARE_BRACKET}"
      The stderr should satisfy spec_expect_no_message "${LOGGED_INTO_REGISTRY}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_LOGIN_TO_REGISTRY}"
      The stderr should satisfy spec_expect_no_message "${CONFIG_IS_NOT_A_DIRECTORY}"
      The stderr should satisfy spec_expect_no_message "${ADDING_OPTIONS}.*--config.*"
      The stderr should satisfy spec_expect_message    "${SKIP_UPDATING}.*${SERVICE_NAME}.*${SKIP_REASON_MANIFEST_FAILURE}"
      The stderr should satisfy spec_expect_no_message "${PERFORM_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_SKIP_JOBS}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_INSPECT_FAILURE}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_NO_NEW_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATING}"
      # No --with-registry-auth, because no login.
      The stderr should satisfy spec_expect_no_message "${ADDING_OPTIONS_WITH_REGISTRY_AUTH}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${THERE_ARE_ADDITIONAL_MESSAGES}.*${SERVICE_NAME}.*"
      The stderr should satisfy spec_expect_no_message "${UPDATED}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_UPDATES}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLING_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLED_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${NO_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${SERVICES_UPDATED}"
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
  Describe "test_login_incorrect_password"
    TEST_NAME="test_login_incorrect_password"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    # When running with an Gantry image, docker buildx writes files to this folder which are owned by root.
    # Using a relative path, this the container will not write to the folder on the host.
    # So do not use an absolute path, otherwise we cannot remove this folder on the host.
    AUTH_CONFIG="C$(unique_id)"
    TEST_REGISTRY=$(load_test_registry "${SUITE_NAME}") || return 1
    test_login_incorrect_password() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      local CONFIG="${3}"
      local REGISTRY="${4}"
      local USERNAME="${5}"
      local PASSWORD="${6}"
      check_login_input "${REGISTRY}" "${USERNAME}" "${PASSWORD}" || return 1;
      local INCORRECT_PASSWORD="${PASSWORD}-incorrect-password"
      local USER_FILE=; USER_FILE=$(mktemp); echo "${USERNAME}" > "${USER_FILE}";
      local PASS_FILE=; PASS_FILE=$(mktemp); echo "${INCORRECT_PASSWORD}" > "${PASS_FILE}";
      docker_service_update --label-add "${GANTRY_AUTH_CONFIG_LABEL}=${CONFIG}" "${SERVICE_NAME}"
      reset_gantry_env "${SERVICE_NAME}"
      export GANTRY_REGISTRY_CONFIG="${CONFIG}"
      export GANTRY_REGISTRY_HOST="${REGISTRY}"
      export GANTRY_REGISTRY_PASSWORD_FILE="${PASS_FILE}"
      export GANTRY_REGISTRY_USER_FILE="${USER_FILE}"
      local RETURN_VALUE=
      run_gantry "${TEST_NAME}"
      RETURN_VALUE="${?}"
      rm "${USER_FILE}"
      rm "${PASS_FILE}"
      [ -d "${CONFIG}" ] && rm -r "${CONFIG}"
      return "${RETURN_VALUE}"
    }
    BeforeEach "common_setup_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_login_incorrect_password "${TEST_NAME}" "${SERVICE_NAME}" "${AUTH_CONFIG}" "${TEST_REGISTRY}" "${TEST_USERNAME}" "${TEST_PASSWORD}"
      The status should be failure
      The stdout should satisfy display_output
      The stdout should satisfy spec_expect_no_message ".+"
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_no_message "${START_WITHOUT_A_SQUARE_BRACKET}"
      The stderr should satisfy spec_expect_no_message "${LOGGED_INTO_REGISTRY}"
      The stderr should satisfy spec_expect_message    "${FAILED_TO_LOGIN_TO_REGISTRY}.*${TEST_REGISTRY}.*${AUTH_CONFIG}"
      The stderr should satisfy spec_expect_no_message "${CONFIG_IS_NOT_A_DIRECTORY}"
      The stderr should satisfy spec_expect_message    "${SKIP_UPDATING_ALL}.*${SKIP_REASON_PREVIOUS_ERRORS}"
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${PERFORM_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_SKIP_JOBS}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_INSPECT_FAILURE}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_NO_NEW_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATING}"
      The stderr should satisfy spec_expect_no_message "${ADDING_OPTIONS}"
      The stderr should satisfy spec_expect_no_message "${THERE_ARE_ADDITIONAL_MESSAGES}.*${SERVICE_NAME}.*"
      The stderr should satisfy spec_expect_no_message "${UPDATED}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_UPDATES}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLING_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLED_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${NO_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${SERVICES_UPDATED}"
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
  Describe "test_login_read_only_file"
    TEST_NAME="test_login_read_only_file"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    AUTH_CONFIG=$(mktemp -d)
    TEST_REGISTRY=$(load_test_registry "${SUITE_NAME}") || return 1
    test_login_read_only_file() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      local CONFIG="${3}"
      local REGISTRY="${4}"
      local USERNAME="${5}"
      local PASSWORD="${6}"
      check_login_input "${REGISTRY}" "${USERNAME}" "${PASSWORD}" || return 1;
      # When running with an image, we are not changing the folder inside the contianer.
      # So do not run the test with a container/image.
      mkdir -p "${CONFIG}"
      chmod 444 "${CONFIG}"
      local USER_FILE=; USER_FILE=$(mktemp); echo "${USERNAME}" > "${USER_FILE}";
      local PASS_FILE=; PASS_FILE=$(mktemp); echo "${PASSWORD}" > "${PASS_FILE}";
      docker_service_update --label-add "${GANTRY_AUTH_CONFIG_LABEL}=${CONFIG}" "${SERVICE_NAME}"
      reset_gantry_env "${SERVICE_NAME}"
      # Use GANTRY_TEST_HOST_TO_CONTAINER to mount the file from host to the container.
      export GANTRY_TEST_HOST_TO_CONTAINER="${CONFIG}"
      export GANTRY_REGISTRY_CONFIG="${CONFIG}"
      export GANTRY_REGISTRY_HOST="${REGISTRY}"
      export GANTRY_REGISTRY_PASSWORD_FILE="${PASS_FILE}"
      export GANTRY_REGISTRY_USER_FILE="${USER_FILE}"
      local RETURN_VALUE=
      run_gantry "${TEST_NAME}"
      RETURN_VALUE="${?}"
      rm "${USER_FILE}"
      rm "${PASS_FILE}"
      # [ -d "${CONFIG}" ] && chmod 777 "${CONFIG}" && rm -r "${CONFIG}"
      return "${RETURN_VALUE}"
    }
    BeforeEach "common_setup_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_login_read_only_file "${TEST_NAME}" "${SERVICE_NAME}" "${AUTH_CONFIG}" "${TEST_REGISTRY}" "${TEST_USERNAME}" "${TEST_PASSWORD}"
      The status should be failure
      The stdout should satisfy display_output
      The stdout should satisfy spec_expect_no_message ".+"
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_no_message "${START_WITHOUT_A_SQUARE_BRACKET}"
      The stderr should satisfy spec_expect_no_message "${LOGGED_INTO_REGISTRY}"
      The stderr should satisfy spec_expect_message    "${FAILED_TO_LOGIN_TO_REGISTRY}.*${TEST_REGISTRY}.*${AUTH_CONFIG}"
      The stderr should satisfy spec_expect_no_message "${CONFIG_IS_NOT_A_DIRECTORY}"
      The stderr should satisfy spec_expect_message    "${SKIP_UPDATING_ALL}.*${SKIP_REASON_PREVIOUS_ERRORS}"
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${PERFORM_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_SKIP_JOBS}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_INSPECT_FAILURE}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_NO_NEW_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATING}"
      The stderr should satisfy spec_expect_no_message "${ADDING_OPTIONS}"
      The stderr should satisfy spec_expect_no_message "${THERE_ARE_ADDITIONAL_MESSAGES}.*${SERVICE_NAME}.*"
      The stderr should satisfy spec_expect_no_message "${UPDATED}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_UPDATES}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLING_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLED_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${NO_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${SERVICES_UPDATED}"
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
  Describe "test_login_config_mismatch_default"
    TEST_NAME="test_login_config_mismatch_default"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    # When running with an Gantry image, docker buildx writes files to this folder which are owned by root.
    # Using a relative path, this the container will not write to the folder on the host.
    # So do not use an absolute path, otherwise we cannot remove this folder on the host.
    AUTH_CONFIG="C$(unique_id)"
    TEST_REGISTRY=$(load_test_registry "${SUITE_NAME}") || return 1
    test_login_config_mismatch_default() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      local CONFIG="${3}"
      local REGISTRY="${4}"
      local USERNAME="${5}"
      local PASSWORD="${6}"
      check_login_input "${REGISTRY}" "${USERNAME}" "${PASSWORD}" || return 1;
      local INCORRECT_CONFIG="incorrect-${CONFIG}"
      local USER_FILE=; USER_FILE=$(mktemp); echo "${USERNAME}" > "${USER_FILE}";
      local PASS_FILE=; PASS_FILE=$(mktemp); echo "${PASSWORD}" > "${PASS_FILE}";
      # Also use CONFIGS_FILE to test a explicitly-set config.
      local CONFIGS_FILE=
      CONFIGS_FILE=$(mktemp)
      echo "${CONFIG} ${REGISTRY} ${USERNAME} ${PASSWORD}" >> "${CONFIGS_FILE}"
      # The config name on the service is different from the config name used in GANTRY_REGISTRY_CONFIG
      docker_service_update --label-add "${GANTRY_AUTH_CONFIG_LABEL}=${INCORRECT_CONFIG}" "${SERVICE_NAME}"
      reset_gantry_env "${SERVICE_NAME}"
      # Do not set GANTRY_REGISTRY_CONFIG, login to the default config.
      # export GANTRY_REGISTRY_CONFIG="${CONFIG}"
      export GANTRY_REGISTRY_HOST="${REGISTRY}"
      export GANTRY_REGISTRY_PASSWORD_FILE="${PASS_FILE}"
      export GANTRY_REGISTRY_USER_FILE="${USER_FILE}"
      export GANTRY_REGISTRY_CONFIGS_FILE="${CONFIGS_FILE}"
      local RETURN_VALUE=
      run_gantry "${TEST_NAME}"
      RETURN_VALUE="${?}"
      rm "${USER_FILE}"
      rm "${PASS_FILE}"
      rm "${CONFIGS_FILE}"
      docker logout "${REGISTRY}" > /dev/null
      [ -d "${CONFIG}" ] && rm -r "${CONFIG}"
      [ -d "${INCORRECT_CONFIG}" ] && rm -r "${INCORRECT_CONFIG}"
      return "${RETURN_VALUE}"
    }
    BeforeEach "common_setup_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_login_config_mismatch_default "${TEST_NAME}" "${SERVICE_NAME}" "${AUTH_CONFIG}" "${TEST_REGISTRY}" "${TEST_USERNAME}" "${TEST_PASSWORD}"
      The status should be failure
      The stdout should satisfy display_output
      The stdout should satisfy spec_expect_no_message ".+"
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_no_message "${START_WITHOUT_A_SQUARE_BRACKET}"
      The stderr should satisfy spec_expect_message    "${LOGGED_INTO_REGISTRY}.*${TEST_REGISTRY}.*${DEFAULT_CONFIGURATION}"
      The stderr should satisfy spec_expect_message    "${LOGGED_INTO_REGISTRY}.*${TEST_REGISTRY}.*${AUTH_CONFIG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_LOGIN_TO_REGISTRY}"
      The stderr should satisfy spec_expect_message    "incorrect-${AUTH_CONFIG}.*${CONFIG_IS_NOT_A_DIRECTORY}"
      # Check warnings
      The stderr should satisfy spec_expect_message    "${THERE_ARE_NUM_CONFIGURATIONS}.*"
      The stderr should satisfy spec_expect_message    "${USER_LOGGED_INTO_DEFAULT}.*"
      The stderr should satisfy spec_expect_no_message "${ADDING_OPTIONS}.*--config ${AUTH_CONFIG}.*"
      The stderr should satisfy spec_expect_message    "${ADDING_OPTIONS}.*--config incorrect-${AUTH_CONFIG}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${SKIP_UPDATING}.*${SERVICE_NAME}.*${SKIP_REASON_MANIFEST_FAILURE}"
      The stderr should satisfy spec_expect_no_message "${PERFORM_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_SKIP_JOBS}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_INSPECT_FAILURE}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_NO_NEW_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATING}"
      # No --with-registry-auth, due to the incorrect configuration, image inspection failed, we did not reach the updating step.
      The stderr should satisfy spec_expect_no_message "${ADDING_OPTIONS_WITH_REGISTRY_AUTH}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${THERE_ARE_ADDITIONAL_MESSAGES}.*${SERVICE_NAME}.*"
      The stderr should satisfy spec_expect_no_message "${UPDATED}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_UPDATES}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLING_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLED_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${NO_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${SERVICES_UPDATED}"
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
  Describe "test_login_config_mismatch_no_default"
    TEST_NAME="test_login_config_mismatch_no_default"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    # When running with an Gantry image, docker buildx writes files to this folder which are owned by root.
    # Using a relative path, this the container will not write to the folder on the host.
    # So do not use an absolute path, otherwise we cannot remove this folder on the host.
    AUTH_CONFIG="C$(unique_id)"
    TEST_REGISTRY=$(load_test_registry "${SUITE_NAME}") || return 1
    test_login_config_mismatch_no_default() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      local CONFIG="${3}"
      local REGISTRY="${4}"
      local USERNAME="${5}"
      local PASSWORD="${6}"
      local INCORRECT_CONFIG="incorrect-${CONFIG}"
      check_login_input "${REGISTRY}" "${USERNAME}" "${PASSWORD}" || return 1;
      local USER_FILE=; USER_FILE=$(mktemp); echo "${USERNAME}" > "${USER_FILE}";
      local PASS_FILE=; PASS_FILE=$(mktemp); echo "${PASSWORD}" > "${PASS_FILE}";
      # The config name on the service is different from the config name used in GANTRY_REGISTRY_CONFIG
      docker_service_update --label-add "${GANTRY_AUTH_CONFIG_LABEL}=${INCORRECT_CONFIG}" "${SERVICE_NAME}"
      reset_gantry_env "${SERVICE_NAME}"
      export GANTRY_REGISTRY_CONFIG="${CONFIG}"
      export GANTRY_REGISTRY_HOST="${REGISTRY}"
      export GANTRY_REGISTRY_PASSWORD_FILE="${PASS_FILE}"
      export GANTRY_REGISTRY_USER_FILE="${USER_FILE}"
      export GANTRY_REGISTRY_CONFIGS_FILE="${CONFIGS_FILE}"
      local RETURN_VALUE=
      run_gantry "${TEST_NAME}"
      RETURN_VALUE="${?}"
      rm "${USER_FILE}"
      rm "${PASS_FILE}"
      [ -d "${CONFIG}" ] && rm -r "${CONFIG}"
      [ -d "${INCORRECT_CONFIG}" ] && rm -r "${INCORRECT_CONFIG}"
      return "${RETURN_VALUE}"
    }
    BeforeEach "common_setup_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_login_config_mismatch_no_default "${TEST_NAME}" "${SERVICE_NAME}" "${AUTH_CONFIG}" "${TEST_REGISTRY}" "${TEST_USERNAME}" "${TEST_PASSWORD}"
      The status should be failure
      The stdout should satisfy display_output
      The stdout should satisfy spec_expect_no_message ".+"
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_no_message "${START_WITHOUT_A_SQUARE_BRACKET}"
      The stderr should satisfy spec_expect_no_message "${LOGGED_INTO_REGISTRY}.*${TEST_REGISTRY}.*${DEFAULT_CONFIGURATION}"
      The stderr should satisfy spec_expect_message    "${LOGGED_INTO_REGISTRY}.*${TEST_REGISTRY}.*${AUTH_CONFIG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_LOGIN_TO_REGISTRY}"
      The stderr should satisfy spec_expect_message    "incorrect-${AUTH_CONFIG}.*${CONFIG_IS_NOT_A_DIRECTORY}"
      # Check warnings
      The stderr should satisfy spec_expect_message    "${THERE_ARE_NUM_CONFIGURATIONS}.*"
      # This message does not present, because we don't login with the default configuration.
      The stderr should satisfy spec_expect_no_message "${USER_LOGGED_INTO_DEFAULT}.*"
      The stderr should satisfy spec_expect_no_message "${ADDING_OPTIONS}.*--config ${AUTH_CONFIG}.*"
      The stderr should satisfy spec_expect_message    "${ADDING_OPTIONS}.*--config incorrect-${AUTH_CONFIG}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${SKIP_UPDATING}.*${SERVICE_NAME}.*${SKIP_REASON_MANIFEST_FAILURE}"
      The stderr should satisfy spec_expect_no_message "${PERFORM_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_SKIP_JOBS}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_INSPECT_FAILURE}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_NO_NEW_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATING}"
      # No --with-registry-auth, due to the incorrect configuration, image inspection failed, we did not reach the updating step.
      The stderr should satisfy spec_expect_no_message "${ADDING_OPTIONS_WITH_REGISTRY_AUTH}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${THERE_ARE_ADDITIONAL_MESSAGES}.*${SERVICE_NAME}.*"
      The stderr should satisfy spec_expect_no_message "${UPDATED}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_UPDATES}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLING_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLED_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${NO_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${SERVICES_UPDATED}"
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
  Describe "test_login_multi_services_no_label"
    # To test https://github.com/shizunge/gantry/issues/64#issuecomment-2475499085
    TEST_NAME="test_login_multi_services_no_label"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    IMAGE_WITH_TAG0="${IMAGE_WITH_TAG}-0"
    IMAGE_WITH_TAG1="${IMAGE_WITH_TAG}-1"
    SERVICE_NAME0="${SERVICE_NAME}-0"
    SERVICE_NAME1="${SERVICE_NAME}-1"
    # When running with an Gantry image, docker buildx writes files to this folder which are owned by root.
    # Using a relative path, this the container will not write to the folder on the host.
    # So do not use an absolute path, otherwise we cannot remove this folder on the host.
    AUTH_CONFIG="C$(unique_id)"
    TEST_REGISTRY=$(load_test_registry "${SUITE_NAME}") || return 1
    test_start() {
      local TEST_NAME="${1}"
      local IMAGE_WITH_TAG="${2}"
      local SERVICE_NAME="${3}"
      local IMAGE_WITH_TAG0="${IMAGE_WITH_TAG}-0"
      local IMAGE_WITH_TAG1="${IMAGE_WITH_TAG}-1"
      local SERVICE_NAME0="${SERVICE_NAME}-0"
      local SERVICE_NAME1="${SERVICE_NAME}-1"
      initialize_test "${TEST_NAME}"
      build_and_push_test_image "${IMAGE_WITH_TAG0}"
      build_and_push_test_image "${IMAGE_WITH_TAG1}"
      start_replicated_service "${SERVICE_NAME0}" "${IMAGE_WITH_TAG0}"
      start_replicated_service "${SERVICE_NAME1}" "${IMAGE_WITH_TAG1}"
      build_and_push_test_image "${IMAGE_WITH_TAG0}"
      build_and_push_test_image "${IMAGE_WITH_TAG1}"
    }
    test_login_multi_services_no_label() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      local CONFIG="${3}"
      local REGISTRY="${4}"
      local USERNAME="${5}"
      local PASSWORD="${6}"
      local SERVICE_NAME0="${SERVICE_NAME}-0"
      local SERVICE_NAME1="${SERVICE_NAME}-1"
      check_login_input "${REGISTRY}" "${USERNAME}" "${PASSWORD}" || return 1;
      local USER_FILE=; USER_FILE=$(mktemp); echo "${USERNAME}" > "${USER_FILE}";
      local PASS_FILE=; PASS_FILE=$(mktemp); echo "${PASSWORD}" > "${PASS_FILE}";
      # Set GANTRY_AUTH_CONFIG_LABEL on SERVICE_NAME1, but not on SERVICE_NAME0.
      # Inspection of SERVICE_NAME0 should fail, because GANTRY_AUTH_CONFIG_LABEL is not found.
      # Inspection of SERVICE_NAME1 should pass, because configuration is set via GANTRY_AUTH_CONFIG_LABEL.
      docker_service_update --label-add "${GANTRY_AUTH_CONFIG_LABEL}=${CONFIG}" "${SERVICE_NAME1}"
      reset_gantry_env "${SERVICE_NAME}"
      export GANTRY_REGISTRY_CONFIG="${CONFIG}"
      export GANTRY_REGISTRY_HOST="${REGISTRY}"
      export GANTRY_REGISTRY_PASSWORD_FILE="${PASS_FILE}"
      export GANTRY_REGISTRY_USER_FILE="${USER_FILE}"
      # Set GANTRY_CLEANUP_IMAGES="false" to speedup the test. We are not testing removing image here.
      export GANTRY_CLEANUP_IMAGES="false"
      local RETURN_VALUE=
      run_gantry "${TEST_NAME}"
      RETURN_VALUE="${?}"
      rm "${USER_FILE}"
      rm "${PASS_FILE}"
      [ -d "${CONFIG}" ] && rm -r "${CONFIG}"
      return "${RETURN_VALUE}"
    }
    test_end() {
      local TEST_NAME="${1}"
      local IMAGE_WITH_TAG="${2}"
      local SERVICE_NAME="${3}"
      local IMAGE_WITH_TAG0="${IMAGE_WITH_TAG}-0"
      local IMAGE_WITH_TAG1="${IMAGE_WITH_TAG}-1"
      stop_multiple_services "${SERVICE_NAME}" 0 1
      prune_local_test_image "${IMAGE_WITH_TAG0}"
      prune_local_test_image "${IMAGE_WITH_TAG1}"
      finalize_test "${TEST_NAME}"
    }
    BeforeEach "test_start ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "test_end ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_login_multi_services_no_label "${TEST_NAME}" "${SERVICE_NAME}" "${AUTH_CONFIG}" "${TEST_REGISTRY}" "${TEST_USERNAME}" "${TEST_PASSWORD}"
      The status should be failure
      The stdout should satisfy display_output
      The stdout should satisfy spec_expect_no_message ".+"
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_no_message "${START_WITHOUT_A_SQUARE_BRACKET}"
      The stderr should satisfy spec_expect_message    "${LOGGED_INTO_REGISTRY}.*${TEST_REGISTRY}.*${AUTH_CONFIG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_LOGIN_TO_REGISTRY}"
      The stderr should satisfy spec_expect_no_message "${ADDING_OPTIONS}.*--config ${AUTH_CONFIG}.*${SERVICE_NAME0}"
      The stderr should satisfy spec_expect_message    "${ADDING_OPTIONS}.*--config ${AUTH_CONFIG}.*${SERVICE_NAME1}"
      The stderr should satisfy spec_expect_no_message "${PERFORM_UPDATING}.*${SERVICE_NAME0}.*"
      The stderr should satisfy spec_expect_message    "${SKIP_UPDATING}.*${SERVICE_NAME0}.*${SKIP_REASON_MANIFEST_FAILURE}"
      The stderr should satisfy spec_expect_message    "${PERFORM_UPDATING}.*${SERVICE_NAME1}.*${PERFORM_REASON_HAS_NEWER_IMAGE}"
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.*${SERVICE_NAME1}.*"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_SKIP_JOBS}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_INSPECT_FAILURE}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_NO_NEW_IMAGES}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_UPDATING}"
      # No --with-registry-auth, for 1. no label on the SERVICE_NAME0. 2. GANTRY_REGISTRY_CONFIG is set but it is not same as the default location.
      The stderr should satisfy spec_expect_no_message "${ADDING_OPTIONS_WITH_REGISTRY_AUTH}.*${SERVICE_NAME0}"
      # Gantry adds --with-registry-auth for finding GANTRY_AUTH_CONFIG_LABEL on the service.
      The stderr should satisfy spec_expect_message    "${ADDING_OPTIONS_WITH_REGISTRY_AUTH}.*${SERVICE_NAME1}"
      The stderr should satisfy spec_expect_no_message "${THERE_ARE_ADDITIONAL_MESSAGES}.*${SERVICE_NAME0}.*"
      The stderr should satisfy spec_expect_no_message "${THERE_ARE_ADDITIONAL_MESSAGES}.*${SERVICE_NAME1}.*"
      The stderr should satisfy spec_expect_no_message "${UPDATED}.*${SERVICE_NAME0}"
      The stderr should satisfy spec_expect_message    "${UPDATED}.*${SERVICE_NAME1}"
      The stderr should satisfy spec_expect_no_message "${NO_UPDATES}.*${SERVICE_NAME0}"
      The stderr should satisfy spec_expect_no_message "${NO_UPDATES}.*${SERVICE_NAME1}"
      The stderr should satisfy spec_expect_no_message "${ROLLING_BACK}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_ROLLBACK}"
      The stderr should satisfy spec_expect_no_message "${ROLLED_BACK}"
      The stderr should satisfy spec_expect_no_message "${NO_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_message    "1 ${SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_UPDATE_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_ERRORS}"
      The stderr should satisfy spec_expect_no_message "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_no_message "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_message    "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${REMOVED_IMAGE}.*"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*"
      The stderr should satisfy spec_expect_no_message "${DONE_REMOVING_IMAGES}"
    End
  End
  Describe "test_login_REGISTRY_CONFIGS_FILE_bad_format"
    TEST_NAME="test_login_REGISTRY_CONFIGS_FILE_bad_format"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    # When running with an Gantry image, docker buildx writes files to this folder which are owned by root.
    # Using a relative path, this the container will not write to the folder on the host.
    # So do not use an absolute path, otherwise we cannot remove this folder on the host.
    AUTH_CONFIG="C$(unique_id)"
    TEST_REGISTRY=$(load_test_registry "${SUITE_NAME}") || return 1
    test_login_REGISTRY_CONFIGS_FILE_bad_format() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      local CONFIG="${3}"
      local REGISTRY="${4}"
      local USERNAME="${5}"
      local PASSWORD="${6}"
      check_login_input "${REGISTRY}" "${USERNAME}" "${PASSWORD}" || return 1;
      local CONFIGS_FILE=
      CONFIGS_FILE=$(mktemp)
      # Add an extra item to the line.
      echo "${CONFIG} ${REGISTRY} ${USERNAME} ${PASSWORD} Extra" >> "${CONFIGS_FILE}"
      # Missing an item from the line.
      echo "The-Only-Item-In-The-Line" >> "${CONFIGS_FILE}"
      docker_service_update --label-add "${GANTRY_AUTH_CONFIG_LABEL}=${CONFIG}" "${SERVICE_NAME}"
      reset_gantry_env "${SERVICE_NAME}"
      export GANTRY_REGISTRY_CONFIGS_FILE="${CONFIGS_FILE}"
      local RETURN_VALUE=
      run_gantry "${TEST_NAME}"
      RETURN_VALUE="${?}"
      rm "${CONFIGS_FILE}"
      [ -d "${CONFIG}" ] && rm -r "${CONFIG}"
      return "${RETURN_VALUE}"
    }
    BeforeEach "common_setup_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_login_REGISTRY_CONFIGS_FILE_bad_format "${TEST_NAME}" "${SERVICE_NAME}" "${AUTH_CONFIG}" "${TEST_REGISTRY}" "${TEST_USERNAME}" "${TEST_PASSWORD}"
      The status should be failure
      The stdout should satisfy display_output
      The stdout should satisfy spec_expect_no_message ".+"
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_no_message "${START_WITHOUT_A_SQUARE_BRACKET}"
      The stderr should satisfy spec_expect_message    "format error.*Found extra item\(s\)"
      The stderr should satisfy spec_expect_message    "format error.*Missing item\(s\)"
      The stderr should satisfy spec_expect_no_message "${LOGGED_INTO_REGISTRY}.*${TEST_REGISTRY}.*${AUTH_CONFIG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_LOGIN_TO_REGISTRY}"
      The stderr should satisfy spec_expect_no_message "${CONFIG_IS_NOT_A_DIRECTORY}"
      The stderr should satisfy spec_expect_message    "${SKIP_UPDATING_ALL}.*${SKIP_REASON_PREVIOUS_ERRORS}"
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${PERFORM_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_SKIP_JOBS}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_INSPECT_FAILURE}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_NO_NEW_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATING}"
      The stderr should satisfy spec_expect_no_message "${ADDING_OPTIONS}.*--config.*"
      The stderr should satisfy spec_expect_no_message "${THERE_ARE_ADDITIONAL_MESSAGES}.*${SERVICE_NAME}.*"
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
  Describe "test_login_file_not_exist"
    TEST_NAME="test_login_file_not_exist"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    # When running with an Gantry image, docker buildx writes files to this folder which are owned by root.
    # Using a relative path, this the container will not write to the folder on the host.
    # So do not use an absolute path, otherwise we cannot remove this folder on the host.
    AUTH_CONFIG="C$(unique_id)"
    TEST_REGISTRY=$(load_test_registry "${SUITE_NAME}") || return 1
    test_login_file_not_exist() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      local CONFIG="${3}"
      local REGISTRY="${4}"
      local USERNAME="${5}"
      local PASSWORD="${6}"
      check_login_input "${REGISTRY}" "${USERNAME}" "${PASSWORD}" || return 1;
      docker_service_update --label-add "${GANTRY_AUTH_CONFIG_LABEL}=${CONFIG}" "${SERVICE_NAME}"
      local FILE_NOT_EXIST="/tmp/${CONFIG}"
      reset_gantry_env "${SERVICE_NAME}"
      export GANTRY_REGISTRY_CONFIG_FILE="${FILE_NOT_EXIST}"
      export GANTRY_REGISTRY_CONFIGS_FILE="${FILE_NOT_EXIST}"
      export GANTRY_REGISTRY_HOST_FILE="${FILE_NOT_EXIST}"
      export GANTRY_REGISTRY_PASSWORD_FILE="${FILE_NOT_EXIST}"
      export GANTRY_REGISTRY_USER_FILE="${FILE_NOT_EXIST}"
      local RETURN_VALUE=
      run_gantry "${TEST_NAME}"
      RETURN_VALUE="${?}"
      [ -d "${CONFIG}" ] && rm -r "${CONFIG}"
      return "${RETURN_VALUE}"
    }
    BeforeEach "common_setup_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_login_file_not_exist "${TEST_NAME}" "${SERVICE_NAME}" "${AUTH_CONFIG}" "${TEST_REGISTRY}" "${TEST_USERNAME}" "${TEST_PASSWORD}"
      The status should be failure
      The stdout should satisfy display_output
      The stdout should satisfy spec_expect_no_message ".+"
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_no_message "${START_WITHOUT_A_SQUARE_BRACKET}"
      The stderr should satisfy spec_expect_no_message "${LOGGED_INTO_REGISTRY}.*${TEST_REGISTRY}.*${AUTH_CONFIG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_LOGIN_TO_REGISTRY}"
      The stderr should satisfy spec_expect_no_message "${CONFIG_IS_NOT_A_DIRECTORY}"
      The stderr should satisfy spec_expect_message    "${SKIP_UPDATING_ALL}.*${SKIP_REASON_PREVIOUS_ERRORS}"
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${PERFORM_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_SKIP_JOBS}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_INSPECT_FAILURE}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_NO_NEW_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATING}"
      The stderr should satisfy spec_expect_no_message "${ADDING_OPTIONS}.*--config.*"
      The stderr should satisfy spec_expect_no_message "${THERE_ARE_ADDITIONAL_MESSAGES}.*${SERVICE_NAME}.*"
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
End # Describe 'login-negative'
