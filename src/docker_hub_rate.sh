#!/bin/sh
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

docker_hub_rate_token() {
  local IMAGE="${1:-ratelimitpreview/test}"
  local TOKEN_URL="https://auth.docker.io/token?service=registry.docker.io&scope=repository:${IMAGE}:pull"
  if curl --version 1>/dev/null 2>&1; then
    curl -s ${TOKEN_URL}
    return $?
  fi
  wget -qO-  ${TOKEN_URL}
}

docker_hub_rate_read_rate() {
  local IMAGE="${1:-ratelimitpreview/test}"
  local TOKEN="${2}"
  [ -z "${TOKEN}" ] && echo "[GET TOKEN ERROR]" && return 1
  local HEADER="Authorization: Bearer ${TOKEN}"
  local URL="https://registry-1.docker.io/v2/${IMAGE}/manifests/latest"
  if curl --version 1>/dev/null 2>&1; then
    curl --head -H "${HEADER}" "${URL}" 2>&1
    return $?
  fi
  # Add `--spider`` implies that you want to send a HEAD request (as opposed to GET or POST).
  # The `busybox wget` does not send a HEAD request, thus it will consume a docker hub rate.
  wget -qS --spider --header="${HEADER}" -O /dev/null "${URL}" 2>&1
}

docker_hub_rate() {
  local IMAGE="${1:-ratelimitpreview/test}"
  local RESPONSE=
  if ! RESPONSE=$(docker_hub_rate_token "${IMAGE}"); then
    echo "[GET TOKEN RESPONSE ERROR]"
    return 1
  fi
  local TOKEN=
  TOKEN=$(echo "${RESPONSE}" | sed 's/.*"token":"\([^"]*\).*/\1/')
  if ! RESPONSE=$(docker_hub_rate_read_rate "${IMAGE}" "${TOKEN}"); then
    if echo "${RESPONSE}" | grep -q "Too Many Requests" ; then
      echo "0"
      return 0
    fi
    echo "[GET RATE RESPONSE ERROR]"
    return 1
  fi
  local RATE=
  RATE=$(echo "${RESPONSE}" | sed -n 's/.*ratelimit-remaining: \([0-9]*\).*/\1/p' )
  [ -z "${RATE}" ] && echo "[GET RATE ERROR]" && return 1
  echo "${RATE}"
}
