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

notify_via_apprise() {
  local URL=${GANTRY_NOTIFICATION_APPRISE_URL}
  local TITLE="${1}"
  local BODY="${2}"
  if [ -z "${URL}" ]; then
    return 0
  fi
  curl -X POST -H "Content-Type: application/json" --data "{\"title\": \"${TITLE}\", \"body\": \"${BODY}\"}" "$URL"
}

notify_summary() {
  local CUSTOMIZED_TITLE=${GANTRY_NOTIFICATION_TITLE}
  local TITLE="${1}"
  local BODY="${2}"
  [ -n "${CUSTOMIZED_TITLE}" ] && TITLE="${TITLE} ${CUSTOMIZED_TITLE}"
  notify_via_apprise "${TITLE}" "${BODY}"
}
