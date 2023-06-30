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

init_swarm() {
  local SELF_ID=
  SELF_ID=$(docker node inspect self --format "{{.Description.Hostname}}" 2>/dev/null);
  if [ -n "${SELF_ID}" ]; then
    echo "Host ${SELF_ID} is already a swarm manager."
    return 0
  fi
  echo "Run docker swarm init"
  docker swarm init
}

get_image_with_tag() {
  local IMAGE="${1}"
  local REGISTRY="${2}"
  if [ -z "${IMAGE}" ]; then
    echo "IMAGE is empty." >&2
    return 1
  fi
  local IMAGE_WITH_TAG="${IMAGE}"
  if [ -n "${REGISTRY}" ]; then
    IMAGE_WITH_TAG="${REGISTRY}/${IMAGE_WITH_TAG}"
  fi
  if ! echo "${IMAGE_WITH_TAG}" | grep -q ":"; then
    IMAGE_WITH_TAG="${IMAGE_WITH_TAG}:for-test-$(date +%s)"
  fi
  echo "${IMAGE_WITH_TAG}"
}

get_script_dir() {
  if [ -z "${BASH_SOURCE[0]}" ]; then
    echo "BASH_SOURCE is empty." >&2
    echo "."
    return 1
  fi
  local SCRIPT_DIR=
  SCRIPT_DIR="$( cd "$(dirname "${BASH_SOURCE[0]}")" || return 1; pwd -P )"
  echo "${SCRIPT_DIR}"
}

main() {
  local IMAGE="${1}"
  # Optional arguments. They may be used by some tests. Missing them will disable the corresponding tests.
  local REGISTRY="${2}"
  local USER="${3}"
  local PASS="${4}"
  
  echo "Starting tests"

  local IMAGE_WITH_TAG=
  IMAGE_WITH_TAG="$(get_image_with_tag "${IMAGE}" "${REGISTRY}")" || return 1
  echo "IMAGE_WITH_TAG=${IMAGE_WITH_TAG}"

  local SCRIPT_DIR=
  SCRIPT_DIR="$(get_script_dir)" || return 1
  echo "SCRIPT_DIR=${SCRIPT_DIR}"
  source "${SCRIPT_DIR}/lib-gantry-test.sh"
  source "${SCRIPT_DIR}/test_entrypoint.sh"

  GLOBAL_ENTRYPOINT_SH=$(get_entrypoint_sh) || return 1
  echo "GLOBAL_ENTRYPOINT_SH=${GLOBAL_ENTRYPOINT_SH}"

  init_swarm

  test_no_new_image "${IMAGE_WITH_TAG}"
  test_new_image "${IMAGE_WITH_TAG}"
  test_new_image_LOG_LEVEL_none "${IMAGE_WITH_TAG}"
  test_login_config "${IMAGE_WITH_TAG}" "${REGISTRY}" "${USER}" "${PASS}"
  test_login_REGISTRY_CONFIGS_FILE "${IMAGE_WITH_TAG}" "${REGISTRY}" "${USER}" "${PASS}"
  test_SERVICES_EXCLUDED "${IMAGE_WITH_TAG}"
  test_SERVICES_EXCLUDED_FILTERS "${IMAGE_WITH_TAG}"
  test_updating_multiple_services "${IMAGE_WITH_TAG}"
  test_jobs_skipping "${IMAGE_WITH_TAG}"
  test_jobs_UPDATE_JOBS_true "${IMAGE_WITH_TAG}"
  test_jobs_UPDATE_JOBS_true_no_running_tasks "${IMAGE_WITH_TAG}"
  test_MANIFEST_INSPECT_false "${IMAGE_WITH_TAG}"
  test_MANIFEST_CMD_manifest "${IMAGE_WITH_TAG}"
  test_UPDATE_OPTIONS "${IMAGE_WITH_TAG}"
  test_replicated_no_running_tasks "${IMAGE_WITH_TAG}"
  test_global_no_running_tasks "${IMAGE_WITH_TAG}"
  test_timeout_rollback "${IMAGE_WITH_TAG}"
  test_rollback_failed  "${IMAGE_WITH_TAG}"
  test_ROLLBACK_ON_FAILURE_false "${IMAGE_WITH_TAG}"
  test_CLEANUP_IMAGES_false "${IMAGE_WITH_TAG}"

  # finish_all_tests should return non zero when there are errors.
  finish_all_tests
}

main "${@}"
