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

_notify_via_apprise() {
  local URL="${GANTRY_NOTIFICATION_APPRISE_URL:-""}"
  local TYPE="${1}"
  local TITLE="${2}"
  local BODY="${3}"
  if [ -z "${URL}" ]; then
    return 0
  fi
  # info, success, warning, failure
  if [ "${TYPE}" != "info" ] && [ "${TYPE}" != "success" ] && [ "${TYPE}" != "warning" ] && [ "${TYPE}" != "failure" ]; then
    TYPE="info"
  fi
  [ -z "${BODY}" ] && BODY="${TITLE}"
  curl -X POST -H "Content-Type: application/json" --data "{\"title\": \"${TITLE}\", \"body\": \"${BODY}\", \"type\": \"${TYPE}\"}" "${URL}"
}

notify_summary() {
  local CUSTOMIZED_TITLE="${GANTRY_NOTIFICATION_TITLE:-""}"
  local TYPE="${1}"
  local TITLE="${2}"
  local BODY="${3}"
  [ -n "${CUSTOMIZED_TITLE}" ] && TITLE="${TITLE} ${CUSTOMIZED_TITLE}"
  _notify_via_apprise "${TYPE}" "${TITLE}" "${BODY}"
}
