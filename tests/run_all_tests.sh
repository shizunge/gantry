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
    GLOBAL_HOSTNAME="${SELF_ID}"
    return 0
  fi
  echo "Run docker swarm init"
  docker swarm init
  SELF_ID=$(docker node inspect self --format "{{.Description.Hostname}}" 2>/dev/null);
  GLOBAL_HOSTNAME="${SELF_ID}"
}

run_gantry() {
  local STACK="${1}"
  source "${GLOBAL_ENTRYPOINT_SH}" "${STACK}"
}

main() {
  if [ -z "${BASH_SOURCE[0]}" ]; then
    echo "BASH_SOURCE is empty." >&2
    return 1
  fi
  echo "Starting tests"
  local IMAGE="${1}"
  if [ -z "${IMAGE}" ]; then
    echo "IMAGE is empty."
    return 1
  fi
  # Optional arguments. They may be used by some tests. Missing them will disable the corresponding tests.
  local REGISTRY="${2}"
  local USER="${3}"
  local PASS="${4}"
  local SCRIPT_DIR IMAGE_WITH_TAG
  SCRIPT_DIR="$( cd "$(dirname "${BASH_SOURCE[0]}")" || return 1; pwd -P )"
  GLOBAL_ENTRYPOINT_SH="${SCRIPT_DIR}/../src/entrypoint.sh"
  IMAGE_WITH_TAG="${IMAGE}"
  if [ -n "${REGISTRY}" ]; then
    IMAGE_WITH_TAG="${REGISTRY}/${IMAGE_WITH_TAG}"
  fi
  if ! echo "${IMAGE_WITH_TAG}" | grep -q ":"; then
    IMAGE_WITH_TAG="${IMAGE_WITH_TAG}:test"
  fi
  echo "GLOBAL_ENTRYPOINT_SH=${GLOBAL_ENTRYPOINT_SH}"
  echo "IMAGE_WITH_TAG=${IMAGE_WITH_TAG}"

  init_swarm

  source "${SCRIPT_DIR}/lib-gantry-test.sh"
  source "${SCRIPT_DIR}/test_entrypoint.sh"

  test_no_new_image "${IMAGE_WITH_TAG}"
  test_new_image "${IMAGE_WITH_TAG}"
  test_login_config "${IMAGE_WITH_TAG}" "${REGISTRY}" "${USER}" "${PASS}"
  test_SERVICES_EXCLUDED "${IMAGE_WITH_TAG}"
  test_SERVICES_EXCLUDED_FILTERS "${IMAGE_WITH_TAG}"
  test_SERVICES_EXCLUDED_combined "${IMAGE_WITH_TAG}"
  test_jobs_skipping "${IMAGE_WITH_TAG}"
  test_jobs_UPDATE_JOBS_on "${IMAGE_WITH_TAG}"
  test_MANIFEST_INSPECT_off "${IMAGE_WITH_TAG}"
  test_replicated_no_running_tasks "${IMAGE_WITH_TAG}"
  test_timeout_rollback "${IMAGE_WITH_TAG}"
  test_rollback_failed  "${IMAGE_WITH_TAG}"
  test_ROLLBACK_ON_FAILURE_off "${IMAGE_WITH_TAG}"
  test_CLEANUP_IMAGES_off "${IMAGE_WITH_TAG}"

  echo "Done tests"
  return 0
}

main "${@}"
