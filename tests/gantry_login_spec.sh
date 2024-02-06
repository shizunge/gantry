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

Describe 'Login'
  SUITE_NAME="Login"
  BeforeAll "initialize_all_tests ${SUITE_NAME}"
  AfterAll "finish_all_tests ${SUITE_NAME}"
  # Here are just simple login tests.
  Describe "test_login_config" "container_test:true"
    TEST_NAME="test_login_config"
    IMAGE_WITH_TAG=$(get_image_with_tag)
    SERVICE_NAME="gantry-test-$(unique_id)"
    test_login_config() {
      local TEST_NAME=${1}
      local SERVICE_NAME=${2}
      local REGISTRY=${3}
      local USERNAME=${4}
      local PASSWORD=${5}
      if [ -z "${USERNAME}" ] || [ -z "${PASSWORD}" ]; then
        echo "No USERNAME or PASSWORD provided." >&2
        return 1
      fi
      local LABEL="gantry.auth.config"
      CONFIG="C$(unique_id)"
      USER_FILE=$(mktemp)
      PASS_FILE=$(mktemp)
      docker service update --quiet --label-add "${LABEL}=${CONFIG}" "${SERVICE_NAME}"
      echo "${USERNAME}" > "${USER_FILE}"
      echo "${PASSWORD}" > "${PASS_FILE}"
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
    Before "common_setup_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    After "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_gantry'
      When call test_login_config "${TEST_NAME}" "${SERVICE_NAME}" "${TEST_REGISTRY}" "${TEST_USERNAME}" "${TEST_PASSWORD}"
      The status should be success
      The stdout should satisfy display_output
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_message    "Logged into registry *${TEST_REGISTRY} for config ${CONFIG}"
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${PERFORM_UPDATING}.*${SERVICE_NAME}.*${PERFORM_REASON_HAS_NEWER_IMAGE}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_SKIP_JOBS}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_INSPECT_FAILURE}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_NO_NEW_IMAGES}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_UPDATING}"
      The stderr should satisfy spec_expect_message    "${ADDING_OPTIONS}.*--config ${CONFIG}"
      The stderr should satisfy spec_expect_message    "${UPDATED}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_UPDATES}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLING_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLED_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATE_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_ERRORS}"
      The stderr should satisfy spec_expect_no_message "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_message    "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_message    "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
    End
  End
  Describe "test_login_REGISTRY_CONFIGS_FILE" "container_test:true"
    TEST_NAME="test_login_REGISTRY_CONFIGS_FILE"
    IMAGE_WITH_TAG=$(get_image_with_tag)
    SERVICE_NAME="gantry-test-$(unique_id)"
    test_login_REGISTRY_CONFIGS_FILE() {
      local TEST_NAME=${1}
      local SERVICE_NAME=${2}
      local REGISTRY=${3}
      local USERNAME=${4}
      local PASSWORD=${5}
      if [ -z "${REGISTRY}" ] || [ -z "${USERNAME}" ] || [ -z "${PASSWORD}" ]; then
        echo "No REGISTRY, USERNAME or PASSWORD provided." >&2
        return 1
      fi
      local LABEL="gantry.auth.config"
      CONFIG="C$(unique_id)"
      CONFIGS_FILE=$(mktemp)
      docker service update --quiet --label-add "${LABEL}=${CONFIG}" "${SERVICE_NAME}"
      echo "# Test comments: CONFIG REGISTRY USERNAME PASSWORD" >> "${CONFIGS_FILE}"
      echo "${CONFIG} ${REGISTRY} ${USERNAME} ${PASSWORD}" >> "${CONFIGS_FILE}"
      export GANTRY_REGISTRY_CONFIGS_FILE="${CONFIGS_FILE}"
      # Since we pass credentials via the configs file, we can use other envs to login to docker hub and check the rate.
      # However we do not actually check whether we read rates correctly, in case password or usrename for docker hub is not set.
      # It seems there is no rate limit when running from the github actions, which also gives us a NaN error.
      export GANTRY_REGISTRY_HOST="docker.io"
      export GANTRY_REGISTRY_PASSWORD="${DOCKERHUB_PASSWORD:-""}"
      export GANTRY_REGISTRY_USER="${DOCKERHUB_USERNAME:-""}"
      local RETURN_VALUE=
      run_gantry "${TEST_NAME}"
      RETURN_VALUE="${?}"
      rm "${CONFIGS_FILE}"
      [ -d "${CONFIG}" ] && rm -r "${CONFIG}"
      return "${RETURN_VALUE}"
    }
    Before "common_setup_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    After "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_gantry'
      When call test_login_REGISTRY_CONFIGS_FILE "${TEST_NAME}" "${SERVICE_NAME}" "${TEST_REGISTRY}" "${TEST_USERNAME}" "${TEST_PASSWORD}" 
      The status should be success
      The stdout should satisfy display_output
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_message    "Logged into registry *${TEST_REGISTRY} for config ${CONFIG}"
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${PERFORM_UPDATING}.*${SERVICE_NAME}.*${PERFORM_REASON_HAS_NEWER_IMAGE}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_SKIP_JOBS}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_INSPECT_FAILURE}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_NO_NEW_IMAGES}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_UPDATING}"
      The stderr should satisfy spec_expect_message    "${ADDING_OPTIONS}.*--config ${CONFIG}"
      The stderr should satisfy spec_expect_message    "${UPDATED}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_UPDATES}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLING_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLED_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATE_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_ERRORS}"
      The stderr should satisfy spec_expect_no_message "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_message    "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_message    "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
    End
  End
  Describe "test_login_REGISTRY_CONFIGS_FILE_bad_format_extra" "container_test:false"
    TEST_NAME="test_login_REGISTRY_CONFIGS_FILE_bad_format_extra"
    IMAGE_WITH_TAG=$(get_image_with_tag)
    SERVICE_NAME="gantry-test-$(unique_id)"
    test_login_REGISTRY_CONFIGS_FILE_bad_format_extra() {
      local TEST_NAME=${1}
      local SERVICE_NAME=${2}
      local REGISTRY=${3}
      local USERNAME=${4}
      local PASSWORD=${5}
      if [ -z "${REGISTRY}" ] || [ -z "${USERNAME}" ] || [ -z "${PASSWORD}" ]; then
        echo "No REGISTRY, USERNAME or PASSWORD provided." >&2
        return 1
      fi
      local LABEL="gantry.auth.config"
      CONFIG="C$(unique_id)"
      CONFIGS_FILE=$(mktemp)
      docker service update --quiet --label-add "${LABEL}=${CONFIG}" "${SERVICE_NAME}"
      # Add an extra item to the line.
      echo "${CONFIG} ${REGISTRY} ${USERNAME} ${PASSWORD} Extra" >> "${CONFIGS_FILE}"
      export GANTRY_REGISTRY_CONFIGS_FILE="${CONFIGS_FILE}"
      local RETURN_VALUE=
      run_gantry "${TEST_NAME}"
      RETURN_VALUE="${?}"
      rm "${CONFIGS_FILE}"
      [ -d "${CONFIG}" ] && rm -r "${CONFIG}"
      return "${RETURN_VALUE}"
    }
    Before "common_setup_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    After "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_gantry'
      When call test_login_REGISTRY_CONFIGS_FILE_bad_format_extra "${TEST_NAME}" "${SERVICE_NAME}" "${TEST_REGISTRY}" "${TEST_USERNAME}" "${TEST_PASSWORD}"
      The status should be failure
      The stdout should satisfy display_output
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_message    "format error.*A line should contains only \"<CONFIG> <HOST> <USER> <PASSWORD>\".*"
      The stderr should satisfy spec_expect_no_message "Logged into registry *${TEST_REGISTRY} for config ${CONFIG}"
      The stderr should satisfy spec_expect_message    "${SKIP_UPDATING_ALL}"
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${PERFORM_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_SKIP_JOBS}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_INSPECT_FAILURE}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_NO_NEW_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATING}"
      The stderr should satisfy spec_expect_no_message "${ADDING_OPTIONS}.*--config.*"
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
    End
  End
  Describe "test_login_REGISTRY_CONFIGS_FILE_bad_format_missing" "container_test:false"
    TEST_NAME="test_login_REGISTRY_CONFIGS_FILE_bad_format_missing"
    IMAGE_WITH_TAG=$(get_image_with_tag)
    SERVICE_NAME="gantry-test-$(unique_id)"
    test_login_REGISTRY_CONFIGS_FILE_bad_format_missing() {
      local TEST_NAME=${1}
      local SERVICE_NAME=${2}
      local REGISTRY=${3}
      local USERNAME=${4}
      local PASSWORD=${5}
      if [ -z "${REGISTRY}" ] || [ -z "${USERNAME}" ] || [ -z "${PASSWORD}" ]; then
        echo "No REGISTRY, USERNAME or PASSWORD provided." >&2
        return 1
      fi
      local LABEL="gantry.auth.config"
      CONFIG="C$(unique_id)"
      CONFIGS_FILE=$(mktemp)
      docker service update --quiet --label-add "${LABEL}=${CONFIG}" "${SERVICE_NAME}"
      # Missing an item from the line.
      echo "${REGISTRY} ${USERNAME} ${PASSWORD}" >> "${CONFIGS_FILE}"
      export GANTRY_REGISTRY_CONFIGS_FILE="${CONFIGS_FILE}"
      local RETURN_VALUE=
      run_gantry "${TEST_NAME}"
      RETURN_VALUE="${?}"
      rm "${CONFIGS_FILE}"
      [ -d "${CONFIG}" ] && rm -r "${CONFIG}"
      return "${RETURN_VALUE}"
    }
    Before "common_setup_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    After "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_gantry'
      When call test_login_REGISTRY_CONFIGS_FILE_bad_format_missing "${TEST_NAME}" "${SERVICE_NAME}" "${TEST_REGISTRY}" "${TEST_USERNAME}" "${TEST_PASSWORD}"
      The status should be failure
      The stdout should satisfy display_output
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_message    "format error.*A line should contains only \"<CONFIG> <HOST> <USER> <PASSWORD>\".*"
      The stderr should satisfy spec_expect_no_message "Logged into registry *${TEST_REGISTRY} for config ${CONFIG}"
      The stderr should satisfy spec_expect_message    "${SKIP_UPDATING_ALL}"
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${PERFORM_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_SKIP_JOBS}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_INSPECT_FAILURE}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_NO_NEW_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATING}"
      The stderr should satisfy spec_expect_no_message "${ADDING_OPTIONS}.*--config.*"
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
    End
  End
End # Describe 'Login'
