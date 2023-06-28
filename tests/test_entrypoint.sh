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

test_no_new_image() {
  local ENTRYPOINT_SH="${1}"
  local IMAGE_WITH_TAG="${2}"

  test_start "${FUNCNAME[0]}"
  local SERVICE_NAME STDOUT LINE
  SERVICE_NAME="gantry-test-$(date +%s)"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"

  GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  STDOUT=$(source "${ENTRYPOINT_SH}" "${FUNCNAME[0]}" | tee /dev/tty)

  set -x
  LINE=$(echo -e "${STDOUT}" | grep "${SERVICE_NAME}")
  LINE=$(echo -e "${LINE}" | grep "No new image")
  LINE=$(echo -e "${STDOUT}" | grep "No services updated")
  LINE=$(echo -e "${STDOUT}" | grep "No images to remove")
  set +x

  stop_service "${SERVICE_NAME}"
  test_end_no_error "${FUNCNAME[0]}"
  return 0
}

test_new_image() {
  local ENTRYPOINT_SH="${1}"
  local IMAGE_WITH_TAG="${2}"
  LOG_SCOPE="${FUNCNAME[0]}"

  test_start "${FUNCNAME[0]}"
  local SERVICE_NAME STDOUT LINE
  SERVICE_NAME="gantry-test-$(date +%s)"
  build_and_push_test_image "${IMAGE_WITH_TAG}"
  start_service "${SERVICE_NAME}" "${IMAGE_WITH_TAG}"
  build_and_push_test_image "${IMAGE_WITH_TAG}"

  GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  STDOUT=$(source "${ENTRYPOINT_SH}" "${FUNCNAME[0]}" | tee /dev/tty)

  set -x
  LINE=$(echo -e "${STDOUT}" | grep "${SERVICE_NAME}")
  LINE=$(echo -e "${LINE}" | grep "UPDATED")
  LINE=$(echo -e "${STDOUT}" | grep "1 service(s) updated")
  LINE=$(echo -e "${STDOUT}" | grep "Removing 1 image(s)")
  LINE=$(echo -e "${STDOUT}" | grep "Removed image ${IMAGE_WITH_TAG}")
  set +x

  stop_service "${SERVICE_NAME}"
  test_end_no_error "${FUNCNAME[0]}"
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

  GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  GANTRY_SERVICES_EXCLUDED="${SERVICE_NAME}"
  STDOUT=$(source "${ENTRYPOINT_SH}" "${FUNCNAME[0]}" | tee /dev/tty)

  set -x
  LINE=$(echo -e "${STDOUT}" | grep "No services updated")
  LINE=$(echo -e "${STDOUT}" | grep "No images to remove")
  set +x

  stop_service "${SERVICE_NAME}"
  test_end_no_error "${FUNCNAME[0]}"
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

  GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  GANTRY_SERVICES_EXCLUDED_FILTERS="name=${SERVICE_NAME}"
  STDOUT=$(source "${ENTRYPOINT_SH}" "${FUNCNAME[0]}" | tee /dev/tty)

  set -x
  LINE=$(echo -e "${STDOUT}" | grep "No services updated")
  LINE=$(echo -e "${STDOUT}" | grep "No images to remove")
  set +x

  stop_service "${SERVICE_NAME}"
  test_end_no_error "${FUNCNAME[0]}"
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

  GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  GANTRY_CLEANUP_IMAGES="false"
  STDOUT=$(source "${ENTRYPOINT_SH}" "${FUNCNAME[0]}" | tee /dev/tty)

  set -x
  LINE=$(echo -e "${STDOUT}" | grep "1 service(s) updated")
  LINE=$(echo -e "${STDOUT}" | grep "Skip removing images")
  set +x

  stop_service "${SERVICE_NAME}"
  test_end_no_error "${FUNCNAME[0]}"
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

  GANTRY_SERVICES_FILTERS="name=${SERVICE_NAME}"
  GANTRY_MANIFEST_INSPECT="false"
  GANTRY_UPDATE_OPTIONS="--force"
  STDOUT=$(source "${ENTRYPOINT_SH}" "${FUNCNAME[0]}" | tee /dev/tty)

  set -x
  # Gantry is still trying to update the service.
  # But it will see no new images.
  LINE=$(echo -e "${STDOUT}" | grep "${SERVICE_NAME}")
  LINE=$(echo -e "${LINE}" | grep "No new image")
  LINE=$(echo -e "${STDOUT}" | grep "No services updated")
  LINE=$(echo -e "${STDOUT}" | grep "No images to remove")
  set +x

  stop_service "${SERVICE_NAME}"
  test_end_no_error "${FUNCNAME[0]}"
  return 0
}

main() {
  local ENTRYPOINT_SH="${1}"
  local IMAGE_WITH_TAG="${2}"

  test_no_new_image "${ENTRYPOINT_SH}" "${IMAGE_WITH_TAG}"
  test_new_image "${ENTRYPOINT_SH}" "${IMAGE_WITH_TAG}"
  test_SERVICES_EXCLUDED "${ENTRYPOINT_SH}" "${IMAGE_WITH_TAG}"
  test_SERVICES_EXCLUDED_FILTERS "${ENTRYPOINT_SH}" "${IMAGE_WITH_TAG}"
  test_CLEANUP_IMAGES_off "${ENTRYPOINT_SH}" "${IMAGE_WITH_TAG}"
  test_MANIFEST_INSPECT_off "${ENTRYPOINT_SH}" "${IMAGE_WITH_TAG}"

  return 0
}

main "${@}"
