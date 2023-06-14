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

docker_hub_rate() {
  local IMAGE=${1:-ratelimitpreview/test}
  local RESPONSE=$(wget -qO- "https://auth.docker.io/token?service=registry.docker.io&scope=repository:${IMAGE}:pull")
  [ $? -ne 0 ] && echo "[GET TOKEN RESPONSE ERROR]" && return 1
  local TOKEN=$(echo ${RESPONSE} | sed 's/.*"token":"\([^"]*\).*/\1/')
  [ -z "${TOKEN}" ] && echo "[GET TOKEN ERROR]" && return 1
  local HEADER="Authorization: Bearer ${TOKEN}"
  local URL="https://registry-1.docker.io/v2/${IMAGE}/manifests/latest"
  # adding --spider implies that you want to send a HEAD request (as opposed to GET or POST).
  RESPONSE=$(wget -qS --spider --header="${HEADER}" -O /dev/null "${URL}" 2>&1)
  if [ $? -ne 0 ]; then
    if echo "${RESPONSE}" | grep -q "Too Many Requests" ; then
      echo "0"
      return 0
    fi
    echo "[GET RATE RESPONSE ERROR]"
    return 1
  fi
  local RATE=$(echo ${RESPONSE} | sed -n 's/.*ratelimit-remaining: \([0-9]*\).*/\1/p' )
  [ -z "${RATE}" ] && echo "[GET RATE ERROR]" && return 1
  echo ${RATE}
}