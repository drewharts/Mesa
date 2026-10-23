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
    elif sys.argv[1] == "revoke":
        for cid in sys.argv[2:]:
            st, d = call("DELETE", f"/v1/certificates/{cid}")
            print("REVOKE", cid, st, "" if st == 204 else json.dumps(d.get("errors")))
        list_certs()
