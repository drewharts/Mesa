#!/usr/bin/env python3
"""App Store submission via the ASC API. Never prints key material.
Usage: asc_submit.py VERSION BUILD NOTES_FILE [--submit] [--replace-in-review] [--release-type=AFTER_APPROVAL|MANUAL]
Without --submit: waits for the build, prepares the version (build, notes, compliance) and stops.
--replace-in-review: if another version is waiting for / in review, cancel that submission
  (developer reject) and reuse that version record for VERSION."""
import sys, time, json
from asc_certs import call

APP = "6740463252"

def die(msg, d=None):
    print("FAILED:", msg, json.dumps((d or {}).get("errors"))[:1500] if d else "")
    sys.exit(1)

def cancel_other_review(version):
    """Cancel any active review submission for a different version (developer reject)."""
    for state in ("WAITING_FOR_REVIEW", "IN_REVIEW", "UNRESOLVED_ISSUES"):
        st, d = call("GET", f"/v1/reviewSubmissions?filter[app]={APP}&filter[state]={state}&include=items&limit=5")
        if st != 200: die(f"list reviewSubmissions {state} {st}", d)
        for rs in d.get("data", []):
            st2, d2 = call("GET", f"/v1/reviewSubmissions/{rs['id']}/items?include=appStoreVersion")
            vers = [i["attributes"].get("versionString") for i in d2.get("included", []) if i.get("type") == "appStoreVersions"]
            if version in vers:
                continue
            print("canceling review submission", rs["id"], state, "for", vers)
            st3, d3 = call("PATCH", f"/v1/reviewSubmissions/{rs['id']}", {"data": {"type": "reviewSubmissions", "id": rs["id"],
                "attributes": {"canceled": True}}})
            if st3 != 200: die(f"cancel reviewSubmission {st3}", d3)
            for _ in range(40):
                st4, d4 = call("GET", f"/v1/reviewSubmissions/{rs['id']}")
                s4 = d4.get("data", {}).get("attributes", {}).get("state")
                print("  submission state", s4)
                if s4 in ("COMPLETE", "CANCELED"): break
                time.sleep(15)

def main():
    version, build_no, notes_file = sys.argv[1:4]
    submit = "--submit" in sys.argv
    replace = "--replace-in-review" in sys.argv
    forced_release = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--release-type=")), None)
    notes = open(notes_file).read().strip()

    # 1. Wait for the build to finish processing.
    build = None
    for _ in range(90):
        st, d = call("GET", f"/v1/builds?filter[app]={APP}&filter[version]={build_no}&filter[preReleaseVersion.version]={version}&limit=1")
        if st == 200 and d.get("data"):
            build = d["data"][0]
            state = build["attributes"].get("processingState")
            print("build", build_no, state)
            if state == "VALID": break
            if state in ("FAILED", "INVALID"): die("build processing " + state)
        else:
            print("build not visible yet", st)
        time.sleep(30)
    else:
        die("timed out waiting for build")
    bid = build["id"]

    # 2. Export compliance: copy the answer of previous builds.
    st, d = call("GET", f"/v1/builds?filter[app]={APP}&sort=-uploadedDate&limit=10&fields[builds]=version,usesNonExemptEncryption")
    prior = [x["attributes"].get("usesNonExemptEncryption") for x in d.get("data", []) if x["id"] != bid]
    print("prior usesNonExemptEncryption:", prior)
    if build["attributes"].get("usesNonExemptEncryption") is None:
        if True in prior: die("prior builds declared non-exempt encryption; answer manually")
        st, d = call("PATCH", f"/v1/builds/{bid}", {"data": {"type": "builds", "id": bid, "attributes": {"usesNonExemptEncryption": False}}})
        if st != 200: die(f"set export compliance {st}", d)
        print("export compliance: no non-exempt encryption")

    # 2b. Optionally pull another version out of review so this one can replace it.
    if replace:
        cancel_other_review(version)

    # 3. Find or create the App Store version (release type copied from the last version).
    st, d = call("GET", f"/v1/apps/{APP}/appStoreVersions?limit=200")
    if st != 200: die(f"list versions {st}", d)
    vers = d["data"]
    live = [v for v in vers if v["attributes"].get("appStoreState") == "READY_FOR_SALE"]
    release_type = live[0]["attributes"].get("releaseType") if live else "MANUAL"
    release_type = forced_release or release_type or "MANUAL"
    print("release type from", live[0]["attributes"]["versionString"] if live else None, "=", release_type)
    v = next((x for x in vers if x["attributes"]["versionString"] == version and x["attributes"]["platform"] == "IOS"), None)
    if v is None and replace:
        editable = [x for x in vers if x["attributes"]["platform"] == "IOS" and x["attributes"].get("appStoreState") in
                    ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED")]
        if editable:
            old = editable[0]
            st, d = call("PATCH", f"/v1/appStoreVersions/{old['id']}", {"data": {"type": "appStoreVersions", "id": old["id"],
                "attributes": {"versionString": version}}})
            if st != 200: die(f"rename version {old['attributes']['versionString']} -> {version} {st}", d)
            v = d["data"]; print("renamed version", old["attributes"]["versionString"], "->", version, v["id"])
    if v is None:
        st, d = call("POST", "/v1/appStoreVersions", {"data": {"type": "appStoreVersions",
            "attributes": {"platform": "IOS", "versionString": version, "releaseType": release_type},
            "relationships": {"app": {"data": {"type": "apps", "id": APP}}}}})
        if st != 201: die(f"create version {st}", d)
        v = d["data"]; print("created version", version, v["id"])
    else:
        print("existing version", version, v["id"], v["attributes"].get("appStoreState"))
    vid = v["id"]
    if v["attributes"].get("releaseType") != release_type:
        st, d = call("PATCH", f"/v1/appStoreVersions/{vid}", {"data": {"type": "appStoreVersions", "id": vid,
            "attributes": {"releaseType": release_type}}})
        if st != 200: die(f"set releaseType {st}", d)
        print("releaseType set to", release_type)

    # 4. Attach the build.
    st, d = call("PATCH", f"/v1/appStoreVersions/{vid}/relationships/build", {"data": {"type": "builds", "id": bid}})
    if st not in (200, 204): die(f"attach build {st}", d)
    print("attached build", build_no)

    # 5. What's New for every localization.
    st, d = call("GET", f"/v1/appStoreVersions/{vid}/appStoreVersionLocalizations")
    if st != 200 or not d.get("data"): die(f"localizations {st}", d)
    for loc in d["data"]:
        st2, d2 = call("PATCH", f"/v1/appStoreVersionLocalizations/{loc['id']}", {"data": {"type": "appStoreVersionLocalizations", "id": loc["id"], "attributes": {"whatsNew": notes}}})
        if st2 != 200: die(f"whatsNew {loc['attributes'].get('locale')} {st2}", d2)
        print("whatsNew set for", loc["attributes"].get("locale"))

    if not submit:
        print("PREPARED (not submitted)"); return

    # 6. Review submission.
    st, d = call("GET", f"/v1/reviewSubmissions?filter[app]={APP}&filter[state]=READY_FOR_REVIEW&limit=5")
    rs = d["data"][0] if st == 200 and d.get("data") else None
    if rs is None:
        st, d = call("POST", "/v1/reviewSubmissions", {"data": {"type": "reviewSubmissions", "attributes": {"platform": "IOS"},
            "relationships": {"app": {"data": {"type": "apps", "id": APP}}}}})
        if st != 201: die(f"create reviewSubmission {st}", d)
        rs = d["data"]
    rsid = rs["id"]
    st, d = call("POST", "/v1/reviewSubmissionItems", {"data": {"type": "reviewSubmissionItems",
        "relationships": {"reviewSubmission": {"data": {"type": "reviewSubmissions", "id": rsid}},
                          "appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}}}}})
    if st != 201 and "already" not in json.dumps(d).lower(): die(f"add item {st}", d)
    st, d = call("PATCH", f"/v1/reviewSubmissions/{rsid}", {"data": {"type": "reviewSubmissions", "id": rsid, "attributes": {"submitted": True}}})
    if st != 200: die(f"submit {st}", d)
    print("SUBMITTED reviewSubmission", rsid, "state", d["data"]["attributes"].get("state"))
    st, d = call("GET", f"/v1/appStoreVersions/{vid}")
    print("version state", d.get("data", {}).get("attributes", {}).get("appStoreState"))

if __name__ == "__main__":
    main()
