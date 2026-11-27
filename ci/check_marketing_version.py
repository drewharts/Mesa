#!/usr/bin/env python3
"""Fail if the app's MARKETING_VERSION is not strictly greater than the latest version Apple has
approved (agent failure #5: TestFlight uploads are rejected once the version's "train" is closed
because that version was already approved/released).

Source of truth for "latest approved version":
  1. App Store Connect API (needs env ASC_KEY_P8_BASE64 or ASC_KEY_PATH, plus ASC_KEY_ID, ASC_ISSUER_ID):
     highest IOS appStoreVersion whose appStoreState/appVersionState is approved-or-later
     (READY_FOR_SALE, PENDING_DEVELOPER_RELEASE, PENDING_APPLE_RELEASE, PROCESSING_FOR_APP_STORE,
      PROCESSING_FOR_DISTRIBUTION, REPLACED_WITH_NEW_VERSION, REMOVED_FROM_SALE, ACCEPTED,
      READY_FOR_DISTRIBUTION).
  2. Fallback (no secrets, or the API call fails): ci/last_released_version.txt.
Versions are compared like Apple does: split on '.', compare components as INTEGERS. So 5.07 == 5.7,
5.07 > 5.06, and 5.1 == (5,1) < 5.07 == (5,7). Mesa's 5.0, 5.01 ... 5.07 scheme works with this,
but never switch to a "5.1" style by accident: after 5.07 bump to 5.08, not 5.1.

The version checked is the `loc` app target's (MesaShare shares it; test targets use 1.0 and are ignored),
parsed from loc.xcodeproj/project.pbxproj.
Usage: check_marketing_version.py [--write] [repo_root]
  --write   write the ASC-derived value into ci/last_released_version.txt (commit it to refresh the fallback)
"""
import base64, os, re, sys, tempfile

APPROVED = {"READY_FOR_SALE", "PENDING_DEVELOPER_RELEASE", "PENDING_APPLE_RELEASE", "PROCESSING_FOR_APP_STORE",
            "PROCESSING_FOR_DISTRIBUTION", "REPLACED_WITH_NEW_VERSION", "REMOVED_FROM_SALE", "ACCEPTED",
            "READY_FOR_DISTRIBUTION"}
APP_ID = "6740463252"  # bundle drewharts.locc (same id as ci/asc_submit.py)
PBXPROJ = "loc.xcodeproj/project.pbxproj"
FALLBACK = "ci/last_released_version.txt"
GUIDANCE = ("Bump MARKETING_VERSION for the `loc` and `MesaShare` targets in {pbx} (all Debug+Release entries "
            "that are currently {cur}) to a version greater than {approved}, e.g. 5.08.")


def vtuple(v):
    """Parse '5.07' -> (5, 7) using Apple's integer-component semantics."""
    return tuple(int(x) for x in v.strip().split("."))


def app_marketing_versions(root):
    """Return the set of MARKETING_VERSION values used by the `loc` target's build configurations."""
    text = open(os.path.join(root, PBXPROJ), encoding="utf-8").read()
    tgt = re.search(r'isa = PBXNativeTarget;(?:(?!\n\t\t\};).)*?buildConfigurationList = (\w{24}) [^;]*;'
                    r'(?:(?!\n\t\t\};).)*?\bname = loc;', text, re.S)
    if not tgt:
        sys.exit("could not find the loc PBXNativeTarget in the pbxproj")
    lst = re.search(tgt.group(1) + r' /\* [^*]*\*/ = \{.*?buildConfigurations = \((.*?)\);', text, re.S)
    versions = set()
    for cid in re.findall(r"(\w{24})", lst.group(1)):
        blk = re.search(cid + r" /\* [^*]*\*/ = \{\s*isa = XCBuildConfiguration;.*?\n\t\t\};", text, re.S)
        m = re.search(r"MARKETING_VERSION = ([^;]+);", blk.group(0)) if blk else None
        if m:
            versions.add(m.group(1).strip().strip('"'))
    if not versions:
        sys.exit("no MARKETING_VERSION found for the loc target")
    return versions


def asc_latest_approved():
    """Return (version, note) from App Store Connect, or (None, reason) when unavailable."""
    key_path = os.environ.get("ASC_KEY_PATH")
    b64 = os.environ.get("ASC_KEY_P8_BASE64")
    if not (os.environ.get("ASC_KEY_ID") and os.environ.get("ASC_ISSUER_ID") and (key_path or b64)):
        return None, "ASC secrets not available"
    if not key_path:
        fd, key_path = tempfile.mkstemp(suffix=".p8")
        with os.fdopen(fd, "wb") as f:
            f.write(base64.b64decode(b64))
        os.environ["ASC_KEY_PATH"] = key_path
    try:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        from asc_certs import call
        st, d = call("GET", f"/v1/apps/{APP_ID}/appStoreVersions?limit=200")
    except Exception as e:  # noqa: BLE001 - any failure falls back to the file
        return None, f"ASC call raised {type(e).__name__}"
    finally:
        if b64 and os.path.exists(key_path):
            os.remove(key_path)
    if st != 200:
        return None, f"ASC returned HTTP {st}"
    found = []
    for v in d.get("data", []):
        a = v["attributes"]
        state = a.get("appVersionState") or a.get("appStoreState")
        states = {a.get("appStoreState"), a.get("appVersionState")}
        if a.get("platform") == "IOS" and states & APPROVED:
            found.append((vtuple(a["versionString"]), a["versionString"], state))
    if not found:
        return None, "ASC has no approved iOS version"
    best = max(found)
    return best[1], f"ASC (state {best[2]})"


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    root = args[0] if args else "."
    versions = app_marketing_versions(root)
    if len(versions) != 1:
        print(f"::error::loc target has inconsistent MARKETING_VERSION values: {sorted(versions)}")
        sys.exit(1)
    current = versions.pop()
    file_path = os.path.join(root, FALLBACK)
    file_val = open(file_path).read().strip()
    approved, source = asc_latest_approved()
    if approved is None:
        print(f"::warning::{source}; falling back to {FALLBACK} = {file_val}")
        approved, source = file_val, FALLBACK
    elif vtuple(file_val) != vtuple(approved):
        print(f"::notice::{FALLBACK} ({file_val}) is stale vs ASC ({approved}); refresh with `check_marketing_version.py --write`")
    print(f"MARKETING_VERSION (loc) = {current}; latest approved = {approved} [{source}]")
    if "--write" in sys.argv:
        if source == FALLBACK:
            sys.exit("--write needs ASC access; refusing to rewrite the file from itself")
        open(file_path, "w").write(approved + "\n")
        print(f"wrote {approved} to {FALLBACK}")
    if vtuple(current) <= vtuple(approved):
        print(f"::error title=MARKETING_VERSION not bumped::{current} <= approved {approved}; TestFlight will reject the upload")
        print("FAILED: " + GUIDANCE.format(pbx=PBXPROJ, cur=current, approved=approved))
        sys.exit(1)
    print("OK: version is ahead of the latest approved version.")


if __name__ == "__main__":
    main()
