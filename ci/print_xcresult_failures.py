#!/usr/bin/env python3
"""Print failing tests (and GitHub error annotations) from an .xcresult bundle.
Usage: print_xcresult_failures.py PATH.xcresult
Uses `xcrun xcresulttool get test-results summary` (Xcode 16+); never fails the step itself."""
import json, subprocess, sys

def main():
    path = sys.argv[1]
    try:
        out = subprocess.run(["xcrun", "xcresulttool", "get", "test-results", "summary", "--path", path],
                             capture_output=True, text=True, check=True).stdout
        summary = json.loads(out)
    except Exception as e:  # noqa: BLE001
        print(f"could not read {path}: {e}")
        return
    print(f"result={summary.get('result')} passed={summary.get('passedTests')} failed={summary.get('failedTests')} "
          f"skipped={summary.get('skippedTests')} total={summary.get('totalTestCount')}")
    for f in summary.get("testFailures", []):
        name = f.get("testIdentifierString") or f.get("testName")
        text = (f.get("failureText") or "").replace("\n", " ")
        print(f"::error title=Test failed::{name}: {text}")
        print(f"FAILED {name}: {text}")

if __name__ == "__main__":
    main()
