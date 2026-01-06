#!/bin/sh
# Copyright (C) 2023-2026 Shizun Ge
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

# Replace newline with '\n'
_replace_newline() {
  local STRING="${1}"
  echo "${STRING}" | sed 's/$/\\n/' | tr -d '\n'
}

_notify_via_apprise() {
  local URL="${1}"
  local TYPE="${2}"
  local TITLE="${3}"
  local BODY="${4}"
  if [ -z "${URL}" ]; then
    log DEBUG "Skip sending notification via Apprise."
    return 0
  fi
  # info, success, warning, failure
  if [ "${TYPE}" != "info" ] && [ "${TYPE}" != "success" ] && [ "${TYPE}" != "warning" ] && [ "${TYPE}" != "failure" ]; then
    TYPE="info"
  fi
  [ -z "${BODY}" ] && BODY="${TITLE}"
  TITLE=$(_replace_newline "${TITLE}")
  BODY=$(_replace_newline "${BODY}")
  local LOG=
  if LOG=$(curl --silent --show-error -X POST -H "Content-Type: application/json" --data "{\"title\": \"${TITLE}\", \"body\": \"${BODY}\", \"type\": \"${TYPE}\"}" "${URL}" 2>&1); then
    log INFO "Sent notification via Apprise:"
    echo "${LOG}" | log_lines INFO
  else
    log WARN "Failed to send notification via Apprise:"
    echo "${LOG}" | log_lines WARN
  fi
  return 0
}

notify_summary() {
  local CUSTOMIZED_TITLE="${GANTRY_NOTIFICATION_TITLE:-""}"
  local APPRISE_URL="${GANTRY_NOTIFICATION_APPRISE_URL:-""}"
  local TYPE="${1}"
  local TITLE="${2}"
  local BODY="${3}"
  local RETURN_VALUE=0
  local OLD_LOG_SCOPE="${LOG_SCOPE}"
  LOG_SCOPE=$(attach_tag_to_log_scope "notify")
  export LOG_SCOPE
  [ -n "${CUSTOMIZED_TITLE}" ] && TITLE="${TITLE} ${CUSTOMIZED_TITLE}"
  if ! _notify_via_apprise "${APPRISE_URL}" "${TYPE}" "${TITLE}" "${BODY}"; then
    RETURN_VALUE=1
  fi
  export LOG_SCOPE="${OLD_LOG_SCOPE}"
  return "${RETURN_VALUE}"
}
