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
    local PID="$$"
    IMAGE_WITH_TAG="${IMAGE_WITH_TAG}:for-test-$(date +%s)-${PID}"
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

  GLOBAL_ENTRYPOINT=$(get_entrypoint) || return 1
  echo "GLOBAL_ENTRYPOINT=${GLOBAL_ENTRYPOINT}"

  init_swarm

  local NORMAL_TESTS="\
    test_new_image_no \
    test_new_image_yes \
    test_new_image_multiple_services \
    test_SERVICES_EXCLUDED \
    test_SERVICES_EXCLUDED_FILTERS \
    test_jobs_skipping \
    test_jobs_UPDATE_JOBS_true \
    test_jobs_UPDATE_JOBS_true_no_running_tasks \
    test_MANIFEST_CMD_none \
    test_MANIFEST_CMD_none_SERVICES_SELF \
    test_MANIFEST_CMD_manifest \
    test_no_running_tasks_replicated \
    test_no_running_tasks_global \
    test_rollback_due_to_timeout \
    test_rollback_failed  \
    test_rollback_ROLLBACK_ON_FAILURE_false \
    test_options_LOG_LEVEL_none \
    test_options_UPDATE_OPTIONS \
    test_options_CLEANUP_IMAGES_false \
  "
  local LOGIN_TESTS="\
    test_login_config \
    test_login_REGISTRY_CONFIGS_FILE \
  "

  for TEST in ${NORMAL_TESTS}; do
    run_test "${TEST}" "${IMAGE_WITH_TAG}"
  done
  for TEST in ${LOGIN_TESTS}; do
    run_test "${TEST}" "${IMAGE_WITH_TAG}" "${REGISTRY}" "${USER}" "${PASS}"
  done

  # finish_all_tests should return non zero when there are errors.
  finish_all_tests
}

main "${@}"
