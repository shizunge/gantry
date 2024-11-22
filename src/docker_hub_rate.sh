#!/bin/sh
# Copyright (C) 2023-2024 Shizun Ge
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

_curl_installed() {
  curl --version 1>/dev/null 2>&1;
}

_docker_hub_rate_token() {
  local IMAGE="${1:-ratelimitpreview/test}"
  local USER_AND_PASS="${2}"
  local TOKEN_URL="https://auth.docker.io/token?service=registry.docker.io&scope=repository:${IMAGE}:pull"
  if ! _curl_installed; then
    [ -n "${USER_AND_PASS}" ] && log WARN "Cannot read docker hub rate for the given user because curl is not available."
    wget -qO- "${TOKEN_URL}"
    return $?
  fi
  if [ -n "${USER_AND_PASS}" ]; then
    curl --silent --show-error --user "${USER_AND_PASS}" "${TOKEN_URL}"
    return $?
  fi
  curl --silent --show-error "${TOKEN_URL}"
  return $?
}

_docker_hub_rate_read_rate() {
  local IMAGE="${1:-ratelimitpreview/test}"
  local TOKEN="${2}"
  [ -z "${TOKEN}" ] && echo "[EMPTY TOKEN ERROR]" && return 1
  local HEADER="Authorization: Bearer ${TOKEN}"
  local URL="https://registry-1.docker.io/v2/${IMAGE}/manifests/latest"
  if ! _curl_installed; then
    # Add `--spider`` implies that you want to send a HEAD request (as opposed to GET or POST).
    # The `busybox wget` does not send a HEAD request, thus it will consume a docker hub rate.
    wget -qS --spider --header="${HEADER}" -O /dev/null "${URL}" 2>&1
    return $?
  fi
  curl --silent --show-error --head -H "${HEADER}" "${URL}" 2>&1
}

_docker_hub_echo_error() {
  local TITLE="${1}"
  local RESPONSE="${2}"
  local OLD_LOG_SCOPE="${LOG_SCOPE}"
  LOG_SCOPE=$(attach_tag_to_log_scope "docker-hub")
  export LOG_SCOPE
  log DEBUG "${TITLE}: RESPONSE="
  echo "${RESPONSE}" | log_lines DEBUG
  echo "[${TITLE}]"
  export LOG_SCOPE="${OLD_LOG_SCOPE}"
}

docker_hub_rate() {
  local IMAGE="${1:-ratelimitpreview/test}"
  local USER_AND_PASS="${2}"
  if ! type log 1>/dev/null 2>&1; then
    log() { echo "${*}" >&2; }
  fi
  if ! type log_lines 1>/dev/null 2>&1; then
    # Usage: echo "${LOGS}" | log_lines LEVLE
    log_lines() { local LEVEL="${1}"; while read -r LINE; do [ -z "${LINE}" ] && continue; log "${LEVEL}" "${LINE}"; done; }
  fi
  local RESPONSE=
  if ! RESPONSE=$(_docker_hub_rate_token "${IMAGE}" "${USER_AND_PASS}" 2>&1); then
    _docker_hub_echo_error "GET TOKEN RESPONSE ERROR" "${RESPONSE}"
    return 1
  fi
  local TOKEN=
  TOKEN=$(echo "${RESPONSE}" | sed 's/.*"token":"\([^"]*\).*/\1/')
  if [ -z "${TOKEN}" ]; then
    _docker_hub_echo_error "PARSE TOKEN ERROR" "${RESPONSE}"
    return 1
  fi
  if ! RESPONSE=$(_docker_hub_rate_read_rate "${IMAGE}" "${TOKEN}" 2>&1); then
    if echo "${RESPONSE}" | grep -q "Too Many Requests" ; then
      # This occurs when we send request not via the HEAD method, i.e. using busybox wget.
      echo "0"
      return 0
    fi
    _docker_hub_echo_error "GET RATE RESPONSE ERROR" "${RESPONSE}"
    return 1
  fi
  local RATE=
  RATE=$(echo "${RESPONSE}" | sed -n 's/.*ratelimit-remaining: \([-]\?[0-9]\+\);.*/\1/p' )
  if [ -z "${RATE}" ]; then
    _docker_hub_echo_error "PARSE RATE ERROR" "${RESPONSE}"
    return 1
  fi
  [ "${RATE}" -lt 0 ] && RATE=0;
  echo "${RATE}"
}
