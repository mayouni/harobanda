#!/usr/bin/env python3
"""The source files a kernel build COMPILED (ONEHOUR-1), read from the build itself.

    python3 -I experiment/kernel_sources.py <src tree> <build dir> <build key> <out file>

A kernel advisory names the files its fix touched (`programFiles` in a CVE record of the
kernel's own numbering authority). Whether one of them is in THIS machine's kernel is not a
question about which CONFIG options are set -- an option is a name, and a file is reached
through Makefiles and #includes nobody here reads -- it is a question the build already
answered: kbuild writes, beside every object it compiles, a `.<obj>.cmd` file naming the
source and every header that object was compiled from. So the list is the union of those,
for every object of the kernel (not the host tools under scripts/ or any tools/ directory), as paths
relative to the source tree. A header counts when an object of the kernel included it.

The file it writes is read by `harb advisories`, strictly:
    harb kernel sources v1
    build <version>-<12 hex of the fragment's options>
    <path>            one per line, sorted, unique
"""
import os
import sys


def tokens_of(cmd_path):
    """The source and dependency paths a .cmd file names."""
    with open(cmd_path, encoding="utf-8", errors="replace") as f:
        text = f.read()
    out = []
    in_deps = False
    for line in text.split("\n"):
        if line.startswith("source_"):
            out.append(line.split(":=", 1)[1].strip())
            continue
        if line.startswith("deps_"):
            in_deps = True
            rest = line.split(":=", 1)[1]
        elif in_deps:
            rest = line
        else:
            continue
        cont = rest.rstrip().endswith("\\")
        for tok in rest.replace("\\", " ").split():
            if tok.startswith("$(wildcard") or tok.endswith(")"):
                continue
            out.append(tok)
        if not cont:
            in_deps = False
    return out


def main():
    if len(sys.argv) != 5:
        print("usage: kernel_sources.py <src tree> <build dir> <build key> <out file>")
        return 1
    src, build, key, out_path = sys.argv[1:]
    src = os.path.realpath(src)
    build = os.path.realpath(build)
    files = set()
    objects = 0
    for root, dirs, names in os.walk(build):
        rel_root = os.path.relpath(root, build)
        parts = rel_root.split(os.sep)
        if parts[0] == "scripts" or "tools" in parts:
            dirs[:] = []
            continue
        for n in names:
            if not (n.startswith(".") and n.endswith(".o.cmd")):
                continue
            objects += 1
            for tok in tokens_of(os.path.join(root, n)):
                p = tok if os.path.isabs(tok) else os.path.join(src, tok)
                p = os.path.realpath(p)
                if not p.startswith(src + os.sep) or not os.path.isfile(p):
                    continue
                files.add(os.path.relpath(p, src).replace(os.sep, "/"))
    if objects == 0 or not files:
        print(f"kernel sources: REFUSED -- {build} holds no compiled object of the kernel")
        return 1
    tmp = out_path + ".new"
    with open(tmp, "w", encoding="utf-8", newline="\n") as f:
        f.write("harb kernel sources v1\n")
        f.write(f"build {key}\n")
        for p in sorted(files):
            f.write(p + "\n")
    os.replace(tmp, out_path)
    print(f"kernel sources: {len(files)} files compiled into {objects} objects, written to {out_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
