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

# Test coverage for the combination of the following 3 configurations.
# Legend:
# D: Whether DOCKER_CONFIG is set or not.
# C: Whether Configuration is named or not. (i.e. GANTRY_REGISTRY_CONFIG or GANTRY_REGISTRY_CONFIGS_FILE is set or not.)
# L: Whether GANTRY_AUTH_CONFIG_LABEL is set on the service or not.
# (N): This is a negative test.
# The coverage is:
# D=0 C=0 L=0 test_login_default_config
# D=0 C=0 L=1 test_login_config_mismatch (N)
# D=0 C=1 L=0 test_login_multi_services_no_label SERVICE_NAME0 (N)
# D=0 C=1 L=1 test_login_config
# D=1 C=0 L=0 test_login_docker_config_default_config
# D=1 C=0 L=1 test_login_docker_config_label_override SERVICE_NAME0 (N)
# D=1 C=1 L=0 test_login_docker_config_no_label
# D=1 C=1 L=1 test_login_docker_config_label_override SERVICE_NAME1

Describe 'login_docker_config'
  SUITE_NAME="login_docker_config"
  BeforeAll "initialize_all_tests ${SUITE_NAME} ENFORCE_LOGIN"
  AfterAll "finish_all_tests ${SUITE_NAME} ENFORCE_LOGIN"
  Describe "test_login_docker_config_no_label" "container_test:true"
    TEST_NAME="test_login_docker_config_no_label"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME="gantry-test-$(unique_id)"
    CONFIG="C$(unique_id)"
    TEST_REGISTRY=$(load_test_registry "${SUITE_NAME}") || return 1
    test_login_docker_config_no_label() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      local CONFIG="${3}"
      local REGISTRY="${4}"
      local USERNAME="${5}"
      local PASSWORD="${6}"
      check_login_input "${REGISTRY}" "${USERNAME}" "${PASSWORD}" || return 1;
      local USER_FILE=; USER_FILE=$(mktemp); echo "${USERNAME}" > "${USER_FILE}";
      local PASS_FILE=; PASS_FILE=$(mktemp); echo "${PASSWORD}" > "${PASS_FILE}";
      reset_gantry_env "${SERVICE_NAME}"
      export DOCKER_CONFIG="${CONFIG}"
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
      When run test_login_docker_config_no_label "${TEST_NAME}" "${SERVICE_NAME}" "${CONFIG}" "${TEST_REGISTRY}" "${TEST_USERNAME}" "${TEST_PASSWORD}"
      The status should be success
      The stdout should satisfy display_output
      The stdout should satisfy spec_expect_no_message ".+"
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_no_message "${NOT_START_WITH_A_SQUARE_BRACKET}"
      The stderr should satisfy spec_expect_no_message "${LOGGED_INTO_REGISTRY}.*${DEFAULT_CONFIGURATION}"
      The stderr should satisfy spec_expect_message    "${LOGGED_INTO_REGISTRY}.*${TEST_REGISTRY}.*${CONFIG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_LOGIN_TO_REGISTRY}"
      The stderr should satisfy spec_expect_no_message "${CONFIG_IS_NOT_A_DIRECTORY}"
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${PERFORM_UPDATING}.*${SERVICE_NAME}.*${PERFORM_REASON_HAS_NEWER_IMAGE}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_SKIP_JOBS}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_INSPECT_FAILURE}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_NO_NEW_IMAGES}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_UPDATING}"
      # No --config, due to GANTRY_AUTH_CONFIG_LABEL is not found on the service.
      The stderr should satisfy spec_expect_no_message "${ADDING_OPTIONS}.*--config.*"
      # Gantry adds --with-registry-auth, because DOCKER_CONFIG and the configuration name are same (default location).
      The stderr should satisfy spec_expect_message    "${ADDING_OPTIONS_WITH_REGISTRY_AUTH}"
      The stderr should satisfy spec_expect_no_message "${THERE_ARE_ADDITIONAL_MESSAGES}.*${SERVICE_NAME}.*"
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
    End
  End
  Describe "test_login_docker_config_default_config" "container_test:true"
    TEST_NAME="test_login_docker_config_default_config"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME="gantry-test-$(unique_id)"
    CONFIG="C$(unique_id)"
    TEST_REGISTRY=$(load_test_registry "${SUITE_NAME}") || return 1
    test_login_docker_config_default_config() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      local CONFIG="${3}"
      local REGISTRY="${4}"
      local USERNAME="${5}"
      local PASSWORD="${6}"
      check_login_input "${REGISTRY}" "${USERNAME}" "${PASSWORD}" || return 1;
      local USER_FILE=; USER_FILE=$(mktemp); echo "${USERNAME}" > "${USER_FILE}";
      local PASS_FILE=; PASS_FILE=$(mktemp); echo "${PASSWORD}" > "${PASS_FILE}";
      # Do not set GANTRY_AUTH_CONFIG_LABEL on the service.
      reset_gantry_env "${SERVICE_NAME}"
      export DOCKER_CONFIG="${CONFIG}"
      # Do not set GANTRY_REGISTRY_CONFIG to login to the default configuration.
      export GANTRY_REGISTRY_HOST="${REGISTRY}"
      export GANTRY_REGISTRY_PASSWORD_FILE="${PASS_FILE}"
      export GANTRY_REGISTRY_USER_FILE="${USER_FILE}"
      local RETURN_VALUE=
      run_gantry "${TEST_NAME}"
      RETURN_VALUE="${?}"
      docker logout "${REGISTRY}" > /dev/null
      rm "${USER_FILE}"
      rm "${PASS_FILE}"
      [ -d "${CONFIG}" ] && rm -r "${CONFIG}"
      return "${RETURN_VALUE}"
    }
    BeforeEach "common_setup_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_login_docker_config_default_config "${TEST_NAME}" "${SERVICE_NAME}" "${CONFIG}" "${TEST_REGISTRY}" "${TEST_USERNAME}" "${TEST_PASSWORD}"
      The status should be success
      The stdout should satisfy display_output
      The stdout should satisfy spec_expect_no_message ".+"
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_no_message "${NOT_START_WITH_A_SQUARE_BRACKET}"
      The stderr should satisfy spec_expect_message    "${LOGGED_INTO_REGISTRY}.*${TEST_REGISTRY}.*${DEFAULT_CONFIGURATION}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_LOGIN_TO_REGISTRY}"
      The stderr should satisfy spec_expect_no_message "${CONFIG_IS_NOT_A_DIRECTORY}"
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${PERFORM_UPDATING}.*${SERVICE_NAME}.*${PERFORM_REASON_HAS_NEWER_IMAGE}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_SKIP_JOBS}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_INSPECT_FAILURE}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_NO_NEW_IMAGES}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_UPDATING}"
      The stderr should satisfy spec_expect_no_message "${ADDING_OPTIONS}.*--config.*"
      # Gantry adds --with-registry-auth for using the default configuration.
      The stderr should satisfy spec_expect_message    "${ADDING_OPTIONS_WITH_REGISTRY_AUTH}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${THERE_ARE_ADDITIONAL_MESSAGES}.*${SERVICE_NAME}.*"
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
    End
  End
  Describe "test_login_docker_config_label_override" "container_test:false"
    TEST_NAME="test_login_docker_config_label_override"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME="gantry-test-$(unique_id)"
    SERVICE_NAME0="${SERVICE_NAME}-0"
    SERVICE_NAME1="${SERVICE_NAME}-1"
    SERVICE_NAME2="${SERVICE_NAME}-2"
    CONFIG="C$(unique_id)"
    TEST_REGISTRY=$(load_test_registry "${SUITE_NAME}") || return 1
    test_start() {
      local TEST_NAME="${1}"
      local IMAGE_WITH_TAG="${2}"
      local SERVICE_NAME="${3}"
      initialize_test "${TEST_NAME}"
      build_and_push_test_image "${IMAGE_WITH_TAG}"
      start_multiple_replicated_services "${SERVICE_NAME}" "${IMAGE_WITH_TAG}" 0 2
      build_and_push_test_image "${IMAGE_WITH_TAG}"
    }
    test_login_docker_config_label_override() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      local CONFIG="${3}"
      local REGISTRY="${4}"
      local USERNAME="${5}"
      local PASSWORD="${6}"
      local SERVICE_NAME0="${SERVICE_NAME}-0"
      local SERVICE_NAME1="${SERVICE_NAME}-1"
      local SERVICE_NAME2="${SERVICE_NAME}-2"
      local INCORRECT_CONFIG="incorrect-${CONFIG}"
      check_login_input "${REGISTRY}" "${USERNAME}" "${PASSWORD}" || return 1;
      local CONFIGS_FILE=
      CONFIGS_FILE=$(mktemp)
      echo "${CONFIG} ${REGISTRY} ${USERNAME} ${PASSWORD}" > "${CONFIGS_FILE}"
      # Set GANTRY_AUTH_CONFIG_LABEL on SERVICE_NAME1, but not on SERVICE_NAME0.
      # Inspection of SERVICE_NAME0 should fail (incorrect label overrides DOCKER_CONFIG).
      # Inspection of SERVICE_NAME1 should pass (correct label overrides DOCKER_CONFIG).
      # Inspection of SERVICE_NAME2 should pass (use DOCKER_CONFIG).
      docker_service_update --label-add "${GANTRY_AUTH_CONFIG_LABEL}=${INCORRECT_CONFIG}" "${SERVICE_NAME0}"
      docker_service_update --label-add "${GANTRY_AUTH_CONFIG_LABEL}=${CONFIG}" "${SERVICE_NAME1}"
      reset_gantry_env "${SERVICE_NAME}"
      # Inspection and updating should use DOCKER_CONFIG or the label.
      export DOCKER_CONFIG="${CONFIG}"
      export GANTRY_REGISTRY_CONFIGS_FILE="${CONFIGS_FILE}"
      # Set GANTRY_CLEANUP_IMAGES="false" to speedup the test. We are not testing removing image here.
      export GANTRY_CLEANUP_IMAGES="false"
      local RETURN_VALUE=
      run_gantry "${TEST_NAME}"
      RETURN_VALUE="${?}"
      rm "${CONFIGS_FILE}"
      [ -d "${CONFIG}" ] && rm -r "${CONFIG}"
      [ -d "${INCORRECT_CONFIG}" ] && rm -r "${INCORRECT_CONFIG}"
      return "${RETURN_VALUE}"
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
      When run test_login_docker_config_label_override "${TEST_NAME}" "${SERVICE_NAME}" "${CONFIG}" "${TEST_REGISTRY}" "${TEST_USERNAME}" "${TEST_PASSWORD}"
      The status should be failure
      The stdout should satisfy display_output
      The stdout should satisfy spec_expect_no_message ".+"
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_no_message "${NOT_START_WITH_A_SQUARE_BRACKET}"
      The stderr should satisfy spec_expect_message    "${LOGGED_INTO_REGISTRY}.*${TEST_REGISTRY}.*${CONFIG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_LOGIN_TO_REGISTRY}"
      The stderr should satisfy spec_expect_message    "incorrect-${CONFIG}.*${CONFIG_IS_NOT_A_DIRECTORY}"
      # Check warnings
      The stderr should satisfy spec_expect_message    "${THERE_ARE_NUM_CONFIGURATIONS}.*"
      The stderr should satisfy spec_expect_message    "${USER_LOGGED_INTO_DEFAULT}.*"
      The stderr should satisfy spec_expect_message    "${ADDING_OPTIONS}.*--config incorrect-${CONFIG}.*${SERVICE_NAME0}"
      The stderr should satisfy spec_expect_message    "${ADDING_OPTIONS}.*--config ${CONFIG}.*${SERVICE_NAME1}"
      The stderr should satisfy spec_expect_no_message "${ADDING_OPTIONS}.*--config ${CONFIG}.*${SERVICE_NAME2}"
      The stderr should satisfy spec_expect_no_message "${PERFORM_UPDATING}.*${SERVICE_NAME0}.*"
      The stderr should satisfy spec_expect_message    "${SKIP_UPDATING}.*${SERVICE_NAME0}.*${SKIP_REASON_MANIFEST_FAILURE}"
      The stderr should satisfy spec_expect_message    "${PERFORM_UPDATING}.*${SERVICE_NAME1}.*${PERFORM_REASON_HAS_NEWER_IMAGE}"
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.*${SERVICE_NAME1}.*"
      The stderr should satisfy spec_expect_message    "${PERFORM_UPDATING}.*${SERVICE_NAME2}.*${PERFORM_REASON_KNOWN_NEWER_IMAGE}"
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.*${SERVICE_NAME2}.*"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_SKIP_JOBS}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_INSPECT_FAILURE}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_NO_NEW_IMAGES}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_UPDATING}"
      # No --with-registry-auth, due to the incorrect configuration, image inspection failed, we did not reach the updating step.
      The stderr should satisfy spec_expect_no_message "${ADDING_OPTIONS_WITH_REGISTRY_AUTH}.*${SERVICE_NAME0}"
      # Gantry adds --with-registry-auth for finding GANTRY_AUTH_CONFIG_LABEL on the service.
      The stderr should satisfy spec_expect_message    "${ADDING_OPTIONS_WITH_REGISTRY_AUTH}.*${SERVICE_NAME1}"
      # Gantry adds --with-registry-auth, because DOCKER_CONFIG and the configuration name are same (default location).
      The stderr should satisfy spec_expect_message    "${ADDING_OPTIONS_WITH_REGISTRY_AUTH}.*${SERVICE_NAME2}"
      The stderr should satisfy spec_expect_no_message "${THERE_ARE_ADDITIONAL_MESSAGES}.*${SERVICE_NAME0}.*"
      The stderr should satisfy spec_expect_no_message "${THERE_ARE_ADDITIONAL_MESSAGES}.*${SERVICE_NAME1}.*"
      The stderr should satisfy spec_expect_no_message "${THERE_ARE_ADDITIONAL_MESSAGES}.*${SERVICE_NAME2}.*"
      The stderr should satisfy spec_expect_no_message "${UPDATED}.*${SERVICE_NAME0}"
      The stderr should satisfy spec_expect_message    "${UPDATED}.*${SERVICE_NAME1}"
      The stderr should satisfy spec_expect_message    "${UPDATED}.*${SERVICE_NAME2}"
      The stderr should satisfy spec_expect_no_message "${NO_UPDATES}.*${SERVICE_NAME0}"
      The stderr should satisfy spec_expect_no_message "${NO_UPDATES}.*${SERVICE_NAME1}"
      The stderr should satisfy spec_expect_no_message "${NO_UPDATES}.*${SERVICE_NAME2}"
      The stderr should satisfy spec_expect_no_message "${ROLLING_BACK}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_ROLLBACK}"
      The stderr should satisfy spec_expect_no_message "${ROLLED_BACK}"
      The stderr should satisfy spec_expect_no_message "${NO_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_message    "2 ${SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_UPDATE_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_ERRORS}"
      The stderr should satisfy spec_expect_no_message "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_no_message "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_message    "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${REMOVED_IMAGE}.*"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*"
    End
  End
End # Describe 'login_docker_config'
