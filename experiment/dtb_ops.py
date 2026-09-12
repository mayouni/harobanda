#!/usr/bin/env python3
"""dtb_ops.py -- apply declared operations to a decompiled device tree.

    dtb_ops.py <in.dts> <out.dts> [op ...]

Ops (derived by `stzos image` into image.env, never typed here):
    disable:<node>          status = "disabled" on the first node of that name
    okay:<node>             status = "okay"
    drop:<node>:<property>  remove a property from that node
    alias:<name>:<path>     set (or add) an alias

Two lists exist: DTB_OPS, applied to the BOARD's tree (what the board
needs that mainline's tree does not say -- the mmc aliases that make the
declared /dev/mmcblk0p2 hold), and QEMU_DTB_OPS, applied on top for the
emulator's tree (the blocks the emulator does not model, the host it
plugs the card into). Every op prints what it did; a node it cannot find
is named, never silently skipped.
"""
import sys, re

src, dst, ops = sys.argv[1], sys.argv[2], sys.argv[3:]
s = open(src).read()

def node_span(text, name):
    """(start, end) of the first node named `name` -- from `name {` to its matching `}`"""
    m = re.search(r'(?m)^(\s*)' + re.escape(name) + r' \{', text)
    if not m:
        return None
    i, depth = m.end(), 1
    while i < len(text) and depth:
        c = text[i]
        if c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
        i += 1
    return m.start(), i

for op in ops:
    parts = op.split(':')
    kind = parts[0]
    if kind == 'alias':
        name, path = parts[1], parts[2]
        span = node_span(s, 'aliases')
        if not span:
            print(f"dtb: no aliases node for {op}")
            continue
        a, b = span
        body = s[a:b]
        new, n = re.subn(r'(?m)^(\s*)' + re.escape(name) + r' = "[^"]*";',
                         lambda m: f'{m.group(1)}{name} = "{path}";', body)
        if n == 0:
            new = body.replace('{', '{\n\t\t' + f'{name} = "{path}";', 1)
        s = s[:a] + new + s[b:]
        print(f"dtb: alias {name} = {path} ({'set' if n else 'added'})")
        continue
    node = parts[1]
    span = node_span(s, node)
    if not span:
        print(f"dtb: no node {node} for {op}")
        continue
    a, b = span
    body = s[a:b]
    if kind in ('disable', 'okay'):
        want = '"disabled"' if kind == 'disable' else '"okay"'
        new, n = re.subn(r'(?m)^(\s*)status = "[^"]*";',
                         lambda m: f'{m.group(1)}status = {want};', body, count=1)
        if n == 0:
            new = body.replace('{', '{\n\t\tstatus = ' + want + ';', 1)
        s = s[:a] + new + s[b:]
        print(f"dtb: {node} status {want}")
    elif kind == 'drop':
        prop = parts[2]
        new, n = re.subn(r'(?m)^\s*' + re.escape(prop) + r'(\s*=\s*[^;]*)?;\n', '', body)
        s = s[:a] + new + s[b:]
        print(f"dtb: {node} drop {prop} ({n} removed)")
    else:
        print(f"dtb: unknown op {op}")

open(dst, 'w').write(s)
