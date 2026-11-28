#!/usr/bin/env bash
# Runs one UI test class on the given simulator with retries; usage: run_ui_tests.sh <TestClass> <label> <simulator-udid>
set -o pipefail
CLASS="$1"; LABEL="$2"; SIM="$3"
LOG="$RUNNER_TEMP/ui-$LABEL.log"
rm -rf "$RUNNER_TEMP/ui-$LABEL.xcresult"
if [ -n "$TEST_RUNNER_TEST_ACCOUNT_PASSWORD" ]; then
  echo "::add-mask::$TEST_RUNNER_TEST_ACCOUNT_PASSWORD"
fi
# Serial execution (-parallel-testing-enabled NO) avoids simulator clones; the locUISmoke scheme's test plan
# keeps screenshots only on failure and disables screen recording.
xcodebuild test \
  -project loc.xcodeproj -scheme locUISmoke -configuration Debug \
  -destination "platform=iOS Simulator,id=$SIM" \
  -clonedSourcePackagesDirPath .spm \
  -skipPackagePluginValidation -skipMacroValidation \
  -parallel-testing-enabled NO \
  -retry-tests-on-failure -test-iterations 3 \
  -only-testing:"locUITests/$CLASS" \
  -resultBundlePath "$RUNNER_TEMP/ui-$LABEL.xcresult" \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= CODE_SIGNING_REQUIRED=NO > "$LOG" 2>&1 \
  || { echo "=== compiler errors ==="; grep -aE "\.swift:[0-9]+:[0-9]+: error|error: " "$LOG" | sort -u | head -60; echo "=== log tail ==="; tail -n 30 "$LOG"; exit 1; }
tail -n 15 "$LOG"
