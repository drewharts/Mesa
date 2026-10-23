#!/usr/bin/env python3
"""CI only: make the app + share extension Release configs sign with the stored
Apple Distribution identity (automatic signing), so Xcode doesn't mint a new
Apple Development certificate on every run. Package targets are untouched."""
import re
p = 'loc.xcodeproj/project.pbxproj'
s = open(p).read()
n = 0
def fix(m):
    global n
    b = m.group(0)
    if 'PRODUCT_BUNDLE_IDENTIFIER = drewharts.locc;' in b or 'PRODUCT_BUNDLE_IDENTIFIER = drewharts.locc.MesaShare;' in b:
        n += 1
        return b.replace('CODE_SIGN_IDENTITY = "Apple Development";', 'CODE_SIGN_IDENTITY = "Apple Distribution";')
    return b
s = re.sub(r'\w+ /\* Release \*/ = \{.*?\n\t\t\};', fix, s, flags=re.S)
assert n == 2, n
open(p, 'w').write(s)
print("patched", n, "Release configs")
