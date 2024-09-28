#!/bin/sh
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

_docker_start_replicated_job() {
  local ARGS="${@}"
  if [ -z "${ARGS}" ]; then
    echo "No services set."
    echo "Services that are not running:"
    docker service ls | grep "0/"
    return 0
  fi
  for S in ${ARGS}; do
    echo -n "Set replicas to 0 to ${S}: "
    docker service update --replicas=0 "${S}"
    echo -n "Set replicas to 1 to ${S}: "
    docker service update --detach --replicas=1 "${S}"
  done
}

_get_number_of_running_tasks() {
  local FILTER="${1}"
  local REPLICAS=
  if ! REPLICAS=$(docker service ls --filter "${FILTER}" --format '{{.Replicas}}' | head -n 1); then
    return 1
  fi
  # https://docs.docker.com/engine/reference/commandline/service_ls/#examples
  # The REPLICAS is like "5/5" or "1/1 (3/5 completed)"
  # Get the number before the first "/".
  local NUM_RUNS=
  NUM_RUNS=$(echo "${REPLICAS}/" | cut -d '/' -f 1)
  echo "${NUM_RUNS}"
}

resume_gantry() {
  local FILTER="label=webhook.run-gantry=true"
  local SERVICE_NAME=$(docker service ls --filter "${FILTER}" --format "{{.Name}}" | head -n 1)
  if [ -z "${SERVICE_NAME}" ]; then
    echo "Cannot find a service from ${FILTER}."
    return 1
  fi
  local replicas=
  if ! replicas=$(_get_number_of_running_tasks "${FILTER}"); then
    echo "Failed to obtain task states of service from ${FILTER}."
    return 1
  fi
  if [ "${replicas}" != "0" ]; then
    echo "${SERVICE_NAME} is still running. There are ${replicas} running tasks."
    return 1
  fi
  docker service update --detach --env-add "GANTRY_SERVICES_EXCLUDED=${GANTRY_SERVICES_EXCLUDED}" "${SERVICE_NAME}"
  docker service update --detach --env-add "GANTRY_SERVICES_EXCLUDED_FILTERS=${GANTRY_SERVICES_EXCLUDED_FILTERS}" "${SERVICE_NAME}"
  docker service update --detach --env-add "GANTRY_SERVICES_FILTERS=${GANTRY_SERVICES_FILTERS}" "${SERVICE_NAME}"
  _docker_start_replicated_job "${SERVICE_NAME}"
}

launch_new_gantry() {
  local service_name="gantry-$(date +%s)"
  docker service create \
    --name "${service_name}" \
    --mode replicated-job \
    --constraint "node.role==manager" \
    --env "GANTRY_SERVICES_EXCLUDED=${GANTRY_SERVICES_EXCLUDED}" \
    --env "GANTRY_SERVICES_EXCLUDED_FILTERS=${GANTRY_SERVICES_EXCLUDED_FILTERS}" \
    --env "GANTRY_SERVICES_FILTERS=${GANTRY_SERVICES_FILTERS}" \
    --label "from-webhook=true" \
    --mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock \
    shizunge/gantry
  local return_value=$?
  docker service logs --raw "${service_name}"
  docker service rm "${service_name}"
  return "${return_value}"
}

main() {
  launch_new_gantry ${*}
}

main "${@}"
