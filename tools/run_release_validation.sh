#!/bin/zsh

set -u
set -o pipefail

PROJECT_DIR="${0:A:h:h}"
GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
RUN_ID="$(date +%Y%m%d-%H%M%S)"
REPORT_DIR="${PROJECT_DIR}/artifacts/release_validation/${RUN_ID}"
VISUAL=0

if [[ "${1:-}" == "--visual" ]]; then
  VISUAL=1
elif [[ -n "${1:-}" ]]; then
  print -u2 "Usage: tools/run_release_validation.sh [--visual]"
  exit 2
fi

if ! mkdir -p "${REPORT_DIR}"; then
  print -u2 "Failed to create release validation report directory: ${REPORT_DIR}"
  exit 1
fi
SUMMARY="${REPORT_DIR}/summary.txt"
STATUS=0

run_case_group() {
  local group="$1"
  local home_dir="$2"
  local script_path="$3"
  local log_path="${REPORT_DIR}/${group}.log"
  mkdir -p "${home_dir}"
  print "RUN ${group} ${script_path}" | tee -a "${SUMMARY}"
  HOME="${home_dir}" "${GODOT_BIN}" --headless --path "${PROJECT_DIR}" --script "${script_path}" 2>&1 | tee "${log_path}"
  local command_status=${pipestatus[1]}
  if rg -q "SCRIPT ERROR:|Assertion failed:|Parse JSON failed" "${log_path}"; then
    command_status=1
  fi
  if [[ ${command_status} -eq 0 ]]; then
    print "PASS ${group}" | tee -a "${SUMMARY}"
  else
    print "FAIL ${group} exit=${command_status}" | tee -a "${SUMMARY}"
    STATUS=1
  fi
}

print "color king release validation ${RUN_ID}" > "${SUMMARY}"
print "Project: ${PROJECT_DIR}" >> "${SUMMARY}"

run_case_group "A-core_HOME_LEVEL_BOARD_HINT_TOOL_ECON_DATA_I18N_RESULT" "/private/tmp/color_king_release_core" "res://tests/smoke_test.gd"
run_case_group "A-tutorial_TUTOR" "/private/tmp/color_king_release_tutorial" "res://tests/tutorial_smoke_test.gd"
run_case_group "A-save_SAVE-001_SAVE-002" "/private/tmp/color_king_release_save" "res://tests/save_compat_test.gd"
run_case_group "A-regression_TODO-009_TODO-010" "/private/tmp/color_king_release_todo_9_10" "res://tools/verify_todo_9_10.gd"
run_case_group "A-editor_EDITOR" "/private/tmp/color_king_release_editor" "res://tests/editor_smoke_test.gd"

if [[ ${VISUAL} -eq 1 ]]; then
  VISUAL_LOG="${REPORT_DIR}/visual_capture.log"
  print "RUN V1 HOME TUTOR LEVEL BOARD HINT RESULT" | tee -a "${SUMMARY}"
  HOME="/private/tmp/color_king_release_visual" "${GODOT_BIN}" \
    --display-driver macos --rendering-driver opengl3 --resolution 540x960 \
    --path "${PROJECT_DIR}" --script "res://tools/capture_ui_screenshots.gd" 2>&1 | tee "${VISUAL_LOG}"
  visual_status=${pipestatus[1]}
  if [[ ${visual_status} -eq 0 ]]; then
    mkdir -p "${REPORT_DIR}/v1_screenshots"
    for screenshot in /private/tmp/color_king_ui_*.png; do
      [[ -f "${screenshot}" ]] && cp "${screenshot}" "${REPORT_DIR}/v1_screenshots/"
    done
    print "PASS V1 capture; manual UI review is still required" | tee -a "${SUMMARY}"
  else
    print "FAIL V1 capture exit=${visual_status}" | tee -a "${SUMMARY}"
    STATUS=1
  fi
else
  print "SKIP V1 visual capture; rerun with --visual" | tee -a "${SUMMARY}"
fi

if [[ -f "${PROJECT_DIR}/builds/color_king-debug.apk" ]]; then
  shasum -a 256 "${PROJECT_DIR}/builds/color_king-debug.apk" > "${REPORT_DIR}/apk_sha256.txt"
  stat -f "APK path: %N%nAPK bytes: %z%nAPK modified: %Sm" -t "%Y-%m-%d %H:%M:%S %z" \
    "${PROJECT_DIR}/builds/color_king-debug.apk" > "${REPORT_DIR}/apk_metadata.txt"
else
  print "APK not found; D verification cannot start" | tee -a "${SUMMARY}"
fi

print "D status: NOT RUN. Complete Android real/cloud device cases and attach evidence." | tee -a "${SUMMARY}"
print "Report: ${REPORT_DIR}" | tee -a "${SUMMARY}"
exit ${STATUS}
