#!/usr/bin/env python3
"""Fail if a module defines the same top-level type name twice (agent failure #1: e.g. a
second `ShimmerModifier` struct breaking the build).

Modules (each is one Swift module, so names must be unique within it). Membership comes from
loc.xcodeproj/project.pbxproj, so files that exist on disk but are not compiled are ignored:
  loc        file-system-synchronized groups of the `loc` target + explicitly referenced .swift files under loc/
  MesaShare  synchronized groups of the MesaShare target
  locTests / locUITests  synchronized groups and/or explicitly referenced .swift files
A "top-level type" is a struct/class/enum/actor/protocol/typealias declared at brace depth 0
(nested types and extensions are ignored). `private`/`fileprivate` top-level types are file-scoped:
they are allowed to repeat, but are listed in the report. Comments and string literals are
stripped before scanning, so `// struct Foo` or "struct Foo" never count.
Usage: check_duplicate_types.py [repo_root]
"""
import os, re, sys
from collections import defaultdict

MODULES = ["loc", "MesaShare", "locTests", "locUITests"]
PBXPROJ = "loc.xcodeproj/project.pbxproj"
SKIP_DIRS = {"build", ".build", "DerivedData", "SourcePackages", "Preview Content"}
DECL = re.compile(
    r"^\s*((?:@\w+(?:\([^)]*\))?\s+|(?:public|open|internal|private|fileprivate|final|indirect|nonisolated|package)\s+)*)"
    r"(struct|class|enum|actor|protocol|typealias)\s+([A-Za-z_]\w*)")


def strip_code(src):
    """Blank out comments and string literals (keeping newlines and braces outside them)."""
    out, i, n = [], 0, len(src)
    while i < n:
        c, two = src[i], src[i:i + 2]
        if two == "//":
            j = src.find("\n", i)
            i = n if j < 0 else j
        elif two == "/*":
            depth, i = 1, i + 2
            while i < n and depth:
                if src[i:i + 2] == "/*": depth, i = depth + 1, i + 2
                elif src[i:i + 2] == "*/": depth, i = depth - 1, i + 2
                else:
                    if src[i] == "\n": out.append("\n")
                    i += 1
        elif c == '"':
            if src[i:i + 3] == '"""':
                j = src.find('"""', i + 3)
                j = n if j < 0 else j + 3
                out.append("\n" * src.count("\n", i, j)); i = j
            else:
                i += 1
                while i < n and src[i] not in '"\n':
                    i += 2 if src[i] == "\\" else 1
                i += 1
        else:
            out.append(c); i += 1
    return "".join(out)


def top_level_decls(path):
    """Yield (name, kind, is_file_scoped, line) for each depth-0 type declaration."""
    with open(path, encoding="utf-8", errors="replace") as f:
        code = strip_code(f.read())
    depth = 0
    for lineno, line in enumerate(code.split("\n"), 1):
        if depth == 0:
            m = DECL.match(line)
            if m:
                scoped = bool(re.search(r"\b(private|fileprivate)\b", m.group(1)))
                yield m.group(3), m.group(2), scoped, lineno
        depth += line.count("{") - line.count("}")
        depth = max(depth, 0)


def resolve(root, rel, parent="loc"):
    """Resolve a pbxproj group-relative path to an existing path (tries loc/<rel> then <rel>)."""
    for cand in (os.path.join(root, parent, rel), os.path.join(root, rel)):
        if os.path.exists(cand):
            return cand
    return None


def module_roots(root):
    """Map target name -> list of synchronized-group directories, parsed from the pbxproj."""
    text = open(os.path.join(root, PBXPROJ), encoding="utf-8").read()
    groups = dict(re.findall(r"(\w{24}) /\* [^*]* \*/ = \{isa = PBXFileSystemSynchronizedRootGroup;.*?path = ([^;]+);", text))
    targets = {}
    for m in re.finditer(r"isa = PBXNativeTarget;(.*?)\n\t\t\};", text, re.S):
        body = m.group(1)
        name = re.search(r"\bname = ([^;]+);", body).group(1).strip('"')
        ids = re.search(r"fileSystemSynchronizedGroups = \((.*?)\);", body, re.S)
        dirs = [groups[i] for i in re.findall(r"(\w{24})", ids.group(1)) if i in groups] if ids else []
        targets[name] = dirs
    explicit = [p.strip('"') for p in re.findall(r"path = ([^;]+\.swift); sourceTree", text)]
    return targets, explicit


def swift_files(root, module, targets, explicit):
    """List .swift files compiled into `module` according to the pbxproj."""
    found = set()
    for d in targets.get(module, []):
        base = resolve(root, d, module if module != "loc" else "loc") or resolve(root, d, "")
        for dp, dn, fn in os.walk(base or os.path.join(root, d)):
            dn[:] = [x for x in dn if x not in SKIP_DIRS]
            found.update(os.path.join(dp, f) for f in fn if f.endswith(".swift"))
    # Explicitly referenced files (targets such as loc/locUITests mix synced groups and file refs).
    for rel in explicit:
        p = os.path.join(root, module, rel)
        if os.path.isfile(p):
            found.add(p)
    return sorted(found)


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "."
    failed = False
    targets, explicit = module_roots(root)
    for module in MODULES:
        seen, scoped_seen = defaultdict(list), defaultdict(list)
        files = swift_files(root, module, targets, explicit)
        if not files:
            print(f"::error::no Swift files resolved for module {module}; check ci/check_duplicate_types.py")
            sys.exit(1)
        for path in files:
            rel = os.path.relpath(path, root)
            for name, kind, scoped, line in top_level_decls(path):
                (scoped_seen if scoped else seen)[name].append(f"{rel}:{line} ({kind})")
        dups = {k: v for k, v in seen.items() if len(v) > 1}
        print(f"[{module}] {sum(len(v) for v in seen.values())} top-level types, {len(dups)} duplicate name(s)")
        for name, locs in sorted(dups.items()):
            failed = True
            print(f"::error title=Duplicate type {name} in {module}::{name} declared {len(locs)}x: {'; '.join(locs)}")
            print(f"  DUPLICATE {name}:"); [print(f"    - {l}") for l in locs]
        for name, locs in sorted(scoped_seen.items()):
            if len(locs) > 1 or name in seen:
                print(f"  note (file-scoped, allowed): {name}: {'; '.join(locs + seen.get(name, []))}")
    if failed:
        print("\nFAILED: remove or rename the duplicate type definitions above "
              "(search for the existing type before adding a new one).")
        sys.exit(1)
    print("OK: no duplicate top-level types.")


if __name__ == "__main__":
    main()
