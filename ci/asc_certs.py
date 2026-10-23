#!/usr/bin/env python3
"""List / revoke App Store Connect certificates. Never prints key material.
Usage: asc_certs.py list | revoke ID [ID...]"""
import os, sys, time, json, urllib.request
import jwt

def token():
    with open(os.environ["ASC_KEY_PATH"]) as f:
        key = f.read()
    now = int(time.time())
    return jwt.encode({"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 900,
                       "aud": "appstoreconnect-v1"}, key, algorithm="ES256",
                      headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"})

def call(method, path, body=None):
    req = urllib.request.Request("https://api.appstoreconnect.apple.com" + path, method=method,
                                 headers={"Authorization": "Bearer " + token(),
                                          "Content-Type": "application/json"},
                                 data=json.dumps(body).encode() if body else None)
    try:
        with urllib.request.urlopen(req) as r:
            raw = r.read()
            return r.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as e:
        return e.code, {"errors": [{"status": e.code, "detail": (e.read() or b"")[:300].decode(errors="replace")}]}

def list_certs():
    st, d = call("GET", "/v1/certificates?limit=200&fields[certificates]=name,displayName,certificateType,expirationDate,platform,serialNumber")
    if st != 200:
        print("LIST FAILED", st, json.dumps(d.get("errors")))
        sys.exit(1)
    for c in d["data"]:
        a = c["attributes"]
        print(f'{c["id"]}\t{a.get("certificateType")}\t{a.get("expirationDate")}\t{a.get("name")}\t{a.get("displayName")}')
    print("TOTAL", len(d["data"]))

if __name__ == "__main__":
    if sys.argv[1] == "list":
        list_certs()
    elif sys.argv[1] == "create-dist":
        csr = open(sys.argv[2]).read()
        csr = "".join(l for l in csr.splitlines() if "CERTIFICATE REQUEST" not in l)
        st, d = call("POST", "/v1/certificates", {"data": {"type": "certificates", "attributes": {
            "certificateType": "DISTRIBUTION", "csrContent": csr}}})
        if st != 201:
            print("CREATE FAILED", st, json.dumps(d.get("errors"))); sys.exit(1)
        # Public certificate only (no private key exists here).
        print("CREATED", d["data"]["id"], d["data"]["attributes"].get("expirationDate"))
        print("CERT_DER_B64", d["data"]["attributes"]["certificateContent"])
    elif sys.argv[1] == "asc-info":
        # Read-only probes: app, versions, and permission checks (GET only).
        st, d = call("GET", "/v1/apps?filter[bundleId]=drewharts.locc")
        print("apps", st)
        app = d["data"][0]["id"] if st == 200 and d.get("data") else None
        print("app id", app, d["data"][0]["attributes"].get("name") if app else "")
        if app:
            st, v = call("GET", f"/v1/apps/{app}/appStoreVersions?limit=10")
            print("appStoreVersions", st)
            for x in v.get("data", []):
                a = x["attributes"]; print(" ", a.get("versionString"), a.get("appStoreState") or a.get("appVersionState"), a.get("platform"), a.get("createdDate"))
            if st != 200: print(json.dumps(v.get("errors"))[:300])
            st, r = call("GET", f"/v1/reviewSubmissions?filter[app]={app}&limit=5")
            print("reviewSubmissions", st, [(x["attributes"].get("state"), x["attributes"].get("submittedDate")) for x in r.get("data", [])] if st == 200 else json.dumps(r.get("errors"))[:300])
            st, b = call("GET", f"/v1/builds?filter[app]={app}&sort=-uploadedDate&limit=3")
            print("builds", st, [(x["attributes"].get("version"), x["attributes"].get("processingState")) for x in b.get("data", [])])
        st, u = call("GET", "/v1/users?limit=1")
        print("users (admin-only)", st)
    elif sys.argv[1] == "revoke":
        for cid in sys.argv[2:]:
            st, d = call("DELETE", f"/v1/certificates/{cid}")
            print("REVOKE", cid, st, "" if st == 204 else json.dumps(d.get("errors")))
        list_certs()
