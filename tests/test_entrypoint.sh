#!/bin/bash
# Copyright (C) 2023 Shizun Ge
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

NO_NEW_IMAGE="No new image"
NO_UPDATES="No updates"
UPDATED="UPDATED"
NO_SERVICES_UPDATED="No services updated"
NO_IMAGES_TO_REMOVE="No images to remove"
NUM_SERVICES_UPDATED="[1-9] service\(s\) updated"
REMOVING_NUM_IMAGES="Removing [1-9] image\(s\)"
SKIP_REMOVING_IMAGES="Skip removing images"
REMOVED_IMAGE="Removed image"

test_no_new_image() {
  local ENTRYPOINT_SH="${1}"
  local IMAGE_WITH_TAG="${2}"

  test_start "${FUNCNAME[0]}"
  local SERVICE_NAME STDOUT LINE
  SERVICE_NAME="gantry-test-$(date +%s)"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"

  export GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  STDOUT=$(source "${ENTRYPOINT_SH}" "${FUNCNAME[0]}" | tee /dev/tty)

  expect_message    "${STDOUT}" "${SERVICE_NAME}.*${NO_NEW_IMAGE}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${UPDATED}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_UPDATES}"
  expect_message    "${STDOUT}" "${NO_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NUM_SERVICES_UPDATED}"
  expect_message    "${STDOUT}" "${NO_IMAGES_TO_REMOVE}"
  expect_no_message "${STDOUT}" "${REMOVING_NUM_IMAGES}"
  expect_no_message "${STDOUT}" "${SKIP_REMOVING_IMAGES}"
  expect_no_message "${STDOUT}" "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"

  stop_service "${SERVICE_NAME}"
  test_end "${FUNCNAME[0]}"
  return 0
}

test_new_image() {
  local ENTRYPOINT_SH="${1}"
  local IMAGE_WITH_TAG="${2}"

  test_start "${FUNCNAME[0]}"
  local SERVICE_NAME STDOUT LINE
  SERVICE_NAME="gantry-test-$(date +%s)"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"

  export GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  STDOUT=$(source "${ENTRYPOINT_SH}" "${FUNCNAME[0]}" | tee /dev/tty)

  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_NEW_IMAGE}"
  expect_message    "${STDOUT}" "${SERVICE_NAME}.*${UPDATED}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_UPDATES}"
  expect_no_message "${STDOUT}" "${NO_SERVICES_UPDATED}"
  expect_message    "${STDOUT}" "${NUM_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NO_IMAGES_TO_REMOVE}"
  expect_message    "${STDOUT}" "${REMOVING_NUM_IMAGES}"
  expect_no_message "${STDOUT}" "${SKIP_REMOVING_IMAGES}"
  expect_message    "${STDOUT}" "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"

  stop_service "${SERVICE_NAME}"
  test_end "${FUNCNAME[0]}"
  return 0
}

test_SERVICES_EXCLUDED() {
  local ENTRYPOINT_SH="${1}"
  local IMAGE_WITH_TAG="${2}"

  test_start "${FUNCNAME[0]}"
  local SERVICE_NAME STDOUT LINE
  SERVICE_NAME="gantry-test-$(date +%s)"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"

  export GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  export GANTRY_SERVICES_EXCLUDED="${SERVICE_NAME}"
  STDOUT=$(source "${ENTRYPOINT_SH}" "${FUNCNAME[0]}" | tee /dev/tty)

  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_NEW_IMAGE}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${UPDATED}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_UPDATES}"
  expect_message    "${STDOUT}" "${NO_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NUM_SERVICES_UPDATED}"
  expect_message    "${STDOUT}" "${NO_IMAGES_TO_REMOVE}"
  expect_no_message "${STDOUT}" "${REMOVING_NUM_IMAGES}"
  expect_no_message "${STDOUT}" "${SKIP_REMOVING_IMAGES}"
  expect_no_message "${STDOUT}" "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"
 
  stop_service "${SERVICE_NAME}"
  test_end "${FUNCNAME[0]}"
  return 0
}

test_SERVICES_EXCLUDED_FILTERS() {
  local ENTRYPOINT_SH="${1}"
  local IMAGE_WITH_TAG="${2}"

  test_start "${FUNCNAME[0]}"
  local SERVICE_NAME STDOUT LINE
  SERVICE_NAME="gantry-test-$(date +%s)"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"

  export GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  export GANTRY_SERVICES_EXCLUDED_FILTERS="name=${SERVICE_NAME}"
  STDOUT=$(source "${ENTRYPOINT_SH}" "${FUNCNAME[0]}" | tee /dev/tty)

  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_NEW_IMAGE}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${UPDATED}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_UPDATES}"
  expect_message    "${STDOUT}" "${NO_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NUM_SERVICES_UPDATED}"
  expect_message    "${STDOUT}" "${NO_IMAGES_TO_REMOVE}"
  expect_no_message "${STDOUT}" "${REMOVING_NUM_IMAGES}"
  expect_no_message "${STDOUT}" "${SKIP_REMOVING_IMAGES}"
  expect_no_message "${STDOUT}" "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"

  stop_service "${SERVICE_NAME}"
  test_end "${FUNCNAME[0]}"
  return 0
}

test_CLEANUP_IMAGES_off() {
  local ENTRYPOINT_SH="${1}"
  local IMAGE_WITH_TAG="${2}"

  test_start "${FUNCNAME[0]}"
  local SERVICE_NAME STDOUT LINE
  SERVICE_NAME="gantry-test-$(date +%s)"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"

  export GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  export GANTRY_CLEANUP_IMAGES="false"
  STDOUT=$(source "${ENTRYPOINT_SH}" "${FUNCNAME[0]}" | tee /dev/tty)

  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_NEW_IMAGE}"
  expect_message    "${STDOUT}" "${SERVICE_NAME}.*${UPDATED}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_UPDATES}"
  expect_no_message "${STDOUT}" "${NO_SERVICES_UPDATED}"
  expect_message    "${STDOUT}" "${NUM_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NO_IMAGES_TO_REMOVE}"
  expect_no_message "${STDOUT}" "${REMOVING_NUM_IMAGES}"
  expect_message    "${STDOUT}" "${SKIP_REMOVING_IMAGES}"
  expect_no_message "${STDOUT}" "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"

  stop_service "${SERVICE_NAME}"
  test_end "${FUNCNAME[0]}"
  return 0
}

test_MANIFEST_INSPECT_off() {
  local ENTRYPOINT_SH="${1}"
  local IMAGE_WITH_TAG="${2}"

  test_start "${FUNCNAME[0]}"
  local SERVICE_NAME STDOUT LINE
  SERVICE_NAME="gantry-test-$(date +%s)"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
  # No image updates after service started.

  export GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  export GANTRY_MANIFEST_INSPECT="false"
  export GANTRY_UPDATE_OPTIONS="--force"
  STDOUT=$(source "${ENTRYPOINT_SH}" "${FUNCNAME[0]}" | tee /dev/tty)

  # Gantry is still trying to update the service.
  # But it will see no new images.
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${NO_NEW_IMAGE}"
  expect_no_message "${STDOUT}" "${SERVICE_NAME}.*${UPDATED}"
  expect_message    "${STDOUT}" "${SERVICE_NAME}.*${NO_UPDATES}"
  expect_message    "${STDOUT}" "${NO_SERVICES_UPDATED}"
  expect_no_message "${STDOUT}" "${NUM_SERVICES_UPDATED}"
  expect_message    "${STDOUT}" "${NO_IMAGES_TO_REMOVE}"
  expect_no_message "${STDOUT}" "${REMOVING_NUM_IMAGES}"
  expect_no_message "${STDOUT}" "${SKIP_REMOVING_IMAGES}"
  expect_no_message "${STDOUT}" "${REMOVED_IMAGE}.*${IMAGE_WITH_TAG}"

  stop_service "${SERVICE_NAME}"
  test_end "${FUNCNAME[0]}"
  return 0
}
