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

export TOTAL_EMAIL_COUNT_IS_ONE="\"total\": *1,"
export SEND_NOTIFY_APPRISE="Sent notification via Apprise"
export SKIP_NOTIFY_APPRISE="Skip sending notification via Apprise"
export NO_UPDATES_OR_ERRORS_FOR_NOTIFICATION="There are no updates or errors for notification."
export SKIP_SENDING_NOTIFICATION="Skip sending notification."

UINQUE_ID="$(unique_id)"
export SERVICE_NAME_APPRISE="gantry-test-${UINQUE_ID}-apprise"
export SERVICE_NAME_MAILPIT="gantry-test-${UINQUE_ID}-mailpit"
# APPRISE_PORT is hard coded in the Apprise container.
export APPRISE_PORT=8000
export SMTP_PORT=1025
export EMAIL_API_PORT=8025

_notify_before_all() {
  local SUITE_NAME="${1}"
  initialize_all_tests "${SUITE_NAME}"
  pull_image_if_not_exist caronc/apprise
  pull_image_if_not_exist axllent/mailpit
  docker_remove "${SERVICE_NAME_APPRISE}" 1>/dev/null 2>&1
  docker_remove "${SERVICE_NAME_MAILPIT}" 1>/dev/null 2>&1
  # Use docker_run to improve coverage on lib-common.sh. `docker run` can do the same thing.
  docker_run -d --restart=on-failure:10 --name="${SERVICE_NAME_APPRISE}" --network=host \
    -e "APPRISE_STATELESS_URLS=mailto://localhost:${SMTP_PORT}?user=userid&pass=password" \
    caronc/apprise
  docker_run -d --restart=on-failure:10 --name="${SERVICE_NAME_MAILPIT}" --network=host \
    axllent/mailpit \
    --smtp "localhost:${SMTP_PORT}" --listen "localhost:${EMAIL_API_PORT}" \
    --smtp-auth-accept-any --smtp-auth-allow-insecure
}

_notify_after_all() {
  local SUITE_NAME="${1}"
  echo "Print Apprise log:"
  docker logs "${SERVICE_NAME_APPRISE}" 2>&1
  docker_remove "${SERVICE_NAME_APPRISE}" 2>&1
  echo "Print Mailpit log:"
  docker logs "${SERVICE_NAME_MAILPIT}" 2>&1
  docker_remove "${SERVICE_NAME_MAILPIT}" 2>&1
  finish_all_tests "${SUITE_NAME}"
}

_print_and_cleanup_emails() {
  local API_URL="localhost:${EMAIL_API_PORT}/api/v1"
  echo "Print emails:"
  curl --silent "${API_URL}/messages" 2>&1
  # Delete all messages
  curl --silent -X "DELETE" "${API_URL}/messages" 2>&1
}

Describe 'notify'
  SUITE_NAME="notify"
  BeforeAll "_notify_before_all ${SUITE_NAME}"
  AfterAll "_notify_after_all ${SUITE_NAME}"
  Describe "test_notify_apprise" "container_test:true" "coverage:true"
    TEST_NAME="test_notify_apprise"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    test_notify_apprise() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      local RETURN_VALUE=0
      reset_gantry_env "${SERVICE_NAME}"
      export GANTRY_NOTIFICATION_APPRISE_URL="http://localhost:${APPRISE_PORT}/notify"
      export GANTRY_NOTIFICATION_TITLE="TEST_TITLE"
      run_gantry "${TEST_NAME}"
      RETURN_VALUE="${?}"
      _print_and_cleanup_emails
      return "${RETURN_VALUE}"
    }
    BeforeEach "common_setup_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_notify_apprise "${TEST_NAME}" "${SERVICE_NAME}"
      The status should be success
      The stdout should satisfy display_output
      The stdout should satisfy spec_expect_message    "Subject.*1 services updated 0 failed TEST_TITLE"
      The stdout should satisfy spec_expect_message    "${TOTAL_EMAIL_COUNT_IS_ONE}"
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_no_message "${START_WITHOUT_A_SQUARE_BRACKET}"
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
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_ERRORS}"
      The stderr should satisfy spec_expect_no_message "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_message    "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_message    "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${SKIP_NOTIFY_APPRISE}"
      The stderr should satisfy spec_expect_message    "${SEND_NOTIFY_APPRISE}"
    End
  End
  Describe "test_notify_apprise_no_new_image" "container_test:true" "coverage:true"
    TEST_NAME="test_notify_apprise_no_new_image"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    test_notify_apprise_no_new_image() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      local RETURN_VALUE=0
      reset_gantry_env "${SERVICE_NAME}"
      export GANTRY_NOTIFICATION_APPRISE_URL="http://localhost:${APPRISE_PORT}/notify"
      export GANTRY_NOTIFICATION_TITLE="TEST_TITLE"
      run_gantry "${TEST_NAME}"
      RETURN_VALUE="${?}"
      _print_and_cleanup_emails
      return "${RETURN_VALUE}"
    }
    BeforeEach "common_setup_no_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_notify_apprise_no_new_image "${TEST_NAME}" "${SERVICE_NAME}"
      The status should be success
      The stdout should satisfy display_output
      The stdout should satisfy spec_expect_message    "Subject.*0 services updated 0 failed TEST_TITLE"
      The stdout should satisfy spec_expect_message    "${TOTAL_EMAIL_COUNT_IS_ONE}"
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_no_message "${START_WITHOUT_A_SQUARE_BRACKET}"
      The stderr should satisfy spec_expect_message    "${SKIP_UPDATING}.*${SERVICE_NAME}.*${SKIP_REASON_CURRENT_IS_LATEST}"
      The stderr should satisfy spec_expect_no_message "${PERFORM_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_SKIP_JOBS}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_INSPECT_FAILURE}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_NO_NEW_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATING}"
      The stderr should satisfy spec_expect_no_message "${ADDING_OPTIONS}"
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
      The stderr should satisfy spec_expect_no_message "${SKIP_NOTIFY_APPRISE}"
      The stderr should satisfy spec_expect_message    "${SEND_NOTIFY_APPRISE}"
    End
  End
  Describe "test_notify_apprise_bad_url" "container_test:true" "coverage:true"
    TEST_NAME="test_notify_apprise_bad_url"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    test_notify_apprise_bad_url() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      reset_gantry_env "${SERVICE_NAME}"
      export GANTRY_NOTIFICATION_APPRISE_URL="http://bad-url/notify"
      run_gantry "${TEST_NAME}"
    }
    BeforeEach "common_setup_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_notify_apprise_bad_url "${TEST_NAME}" "${SERVICE_NAME}"
      The status should be success
      The stdout should satisfy display_output
      The stdout should satisfy spec_expect_no_message ".+"
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_no_message "${START_WITHOUT_A_SQUARE_BRACKET}"
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
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_ERRORS}"
      The stderr should satisfy spec_expect_no_message "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_message    "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_message    "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${SKIP_NOTIFY_APPRISE}"
      The stderr should satisfy spec_expect_message    "Failed to send notification via Apprise"
    End
  End
  Describe "test_notify_on_change_new_image" "container_test:true" "coverage:true"
    TEST_NAME="test_notify_on_change_new_image"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    test_notify_on_change_new_image() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      local RETURN_VALUE=0
      reset_gantry_env "${SERVICE_NAME}"
      export GANTRY_NOTIFICATION_APPRISE_URL="http://localhost:${APPRISE_PORT}/notify"
      export GANTRY_NOTIFICATION_CONDITION="on-change"
      export GANTRY_NOTIFICATION_TITLE="TEST_TITLE"
      run_gantry "${TEST_NAME}"
      RETURN_VALUE="${?}"
      _print_and_cleanup_emails
      return "${RETURN_VALUE}"
    }
    BeforeEach "common_setup_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_notify_on_change_new_image "${TEST_NAME}" "${SERVICE_NAME}"
      The status should be success
      The stdout should satisfy display_output
      The stdout should satisfy spec_expect_message    "Subject.*1 services updated 0 failed TEST_TITLE"
      The stdout should satisfy spec_expect_message    "${TOTAL_EMAIL_COUNT_IS_ONE}"
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_no_message "${START_WITHOUT_A_SQUARE_BRACKET}"
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
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_ERRORS}"
      The stderr should satisfy spec_expect_no_message "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_message    "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_message    "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${FAILED_TO_REMOVE_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${SKIP_NOTIFY_APPRISE}"
      The stderr should satisfy spec_expect_message    "${SEND_NOTIFY_APPRISE}"
    End
  End
  Describe "test_notify_on_change_no_updates" "container_test:true" "coverage:true"
    TEST_NAME="test_notify_on_change_no_updates"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    test_notify_on_change_no_updates() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      local RETURN_VALUE=0
      reset_gantry_env "${SERVICE_NAME}"
      export GANTRY_NOTIFICATION_CONDITION="on-change"
      export GANTRY_NOTIFICATION_TITLE="TEST_TITLE"
      run_gantry "${TEST_NAME}"
      RETURN_VALUE="${?}"
      return "${RETURN_VALUE}"
    }
    BeforeEach "common_setup_no_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_notify_on_change_no_updates "${TEST_NAME}" "${SERVICE_NAME}"
      The status should be success
      The stdout should satisfy display_output
      The stdout should satisfy spec_expect_no_message ".+"
      The stdout should satisfy spec_expect_no_message "TEST_TITLE"
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_no_message "${START_WITHOUT_A_SQUARE_BRACKET}"
      The stderr should satisfy spec_expect_message    "${SKIP_UPDATING}.*${SERVICE_NAME}.*${SKIP_REASON_CURRENT_IS_LATEST}"
      The stderr should satisfy spec_expect_no_message "${PERFORM_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_SKIP_JOBS}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_INSPECT_FAILURE}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_NO_NEW_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATING}"
      The stderr should satisfy spec_expect_no_message "${ADDING_OPTIONS}"
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
      The stderr should satisfy spec_expect_message    "${NO_UPDATES_OR_ERRORS_FOR_NOTIFICATION}"
      The stderr should satisfy spec_expect_message    "${SKIP_SENDING_NOTIFICATION}"
    End
  End
  Describe "test_notify_on_change_errors" "container_test:false" "coverage:true"
    TEST_NAME="test_notify_on_change_errors"
    IMAGE_WITH_TAG=$(get_image_with_tag "${SUITE_NAME}")
    SERVICE_NAME=$(get_test_service_name "${TEST_NAME}")
    test_notify_on_change_errors() {
      local TEST_NAME="${1}"
      local SERVICE_NAME="${2}"
      local RETURN_VALUE=0
      reset_gantry_env "${SERVICE_NAME}"
      export GANTRY_UPDATE_OPTIONS="--bad-options-that-causes-error"
      export GANTRY_NOTIFICATION_APPRISE_URL="http://localhost:${APPRISE_PORT}/notify"
      export GANTRY_NOTIFICATION_CONDITION="on-change"
      export GANTRY_NOTIFICATION_TITLE="TEST_TITLE"
      run_gantry "${TEST_NAME}"
      RETURN_VALUE="${?}"
      _print_and_cleanup_emails
      return "${RETURN_VALUE}"
    }
    BeforeEach "common_setup_new_image ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    AfterEach "common_cleanup ${TEST_NAME} ${IMAGE_WITH_TAG} ${SERVICE_NAME}"
    It 'run_test'
      When run test_notify_on_change_errors "${TEST_NAME}" "${SERVICE_NAME}"
      The status should be failure
      The stdout should satisfy display_output
      The stdout should satisfy spec_expect_message    "Subject.*0 services updated 1 failed TEST_TITLE"
      The stdout should satisfy spec_expect_message    "${TOTAL_EMAIL_COUNT_IS_ONE}"
      The stderr should satisfy display_output
      The stderr should satisfy spec_expect_no_message "${START_WITHOUT_A_SQUARE_BRACKET}"
      The stderr should satisfy spec_expect_no_message "${SKIP_UPDATING}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${PERFORM_UPDATING}.*${SERVICE_NAME}.*${PERFORM_REASON_HAS_NEWER_IMAGE}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_SKIP_JOBS}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_INSPECT_FAILURE}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_NO_NEW_IMAGES}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_UPDATING}"
      The stderr should satisfy spec_expect_no_message "${UPDATED}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${NO_UPDATES}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${ROLLING_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${FAILED_TO_ROLLBACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_no_message "${ROLLED_BACK}.*${SERVICE_NAME}"
      The stderr should satisfy spec_expect_message    "${NO_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_UPDATED}"
      The stderr should satisfy spec_expect_message    "${NUM_SERVICES_UPDATE_FAILED}"
      The stderr should satisfy spec_expect_no_message "${NUM_SERVICES_ERRORS}"
      The stderr should satisfy spec_expect_message    "${NO_IMAGES_TO_REMOVE}"
      The stderr should satisfy spec_expect_no_message "${REMOVING_NUM_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${SKIP_REMOVING_IMAGES}"
      The stderr should satisfy spec_expect_no_message "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
      The stderr should satisfy spec_expect_no_message "${SKIP_NOTIFY_APPRISE}"
      The stderr should satisfy spec_expect_message    "${SEND_NOTIFY_APPRISE}"
    End
  End
End # Describe 'Notify'
