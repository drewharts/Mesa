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
    elif sys.argv[1] == "ensure-profile":
        # ensure-profile NAME BUNDLE_IDENTIFIER CERT_ID OUT_DIR -> installs <uuid>.mobileprovision
        import base64, urllib.parse
        name, ident, cert_id, out = sys.argv[2:6]
        st, d = call("GET", "/v1/profiles?limit=200&filter[name]=" + urllib.parse.quote(name)
                     + "&filter[profileState]=ACTIVE&include=certificates")
        prof = None
        for p in d.get("data", []) if st == 200 else []:
            certs = [c["id"] for c in p.get("relationships", {}).get("certificates", {}).get("data", [])]
            if p["attributes"].get("name") == name and cert_id in certs:
                prof = p
                break
        if prof is None:
            st, b = call("GET", "/v1/bundleIds?limit=200&filter[identifier]=" + urllib.parse.quote(ident))
            bid = next((x["id"] for x in b.get("data", []) if x["attributes"]["identifier"] == ident), None)
            if not bid:
                print("NO BUNDLE ID", ident, st); sys.exit(1)
            st, d = call("POST", "/v1/profiles", {"data": {"type": "profiles",
                "attributes": {"name": name, "profileType": "IOS_APP_STORE"},
                "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": bid}},
                                  "certificates": {"data": [{"type": "certificates", "id": cert_id}]}}}})
            if st != 201:
                print("PROFILE CREATE FAILED", st, json.dumps(d.get("errors"))); sys.exit(1)
            prof = d["data"]
            print("CREATED PROFILE", prof["id"], name)
        else:
            print("REUSING PROFILE", prof["id"], name)
        os.makedirs(out, exist_ok=True)
        with open(os.path.join(out, prof["attributes"]["uuid"] + ".mobileprovision"), "wb") as f:
            f.write(base64.b64decode(prof["attributes"]["profileContent"]))
    elif sys.argv[1] == "revoke":
        for cid in sys.argv[2:]:
            st, d = call("DELETE", f"/v1/certificates/{cid}")
            print("REVOKE", cid, st, "" if st == 204 else json.dumps(d.get("errors")))
        list_certs()
