#!/usr/bin/env python3
"""Same-length redaction: replace every literal from LITERALS (one per line)
by 'x' (spaces stay) in the given files, in place. Works on binary files too,
because the length never changes. Exit 1 if a literal was not found anywhere.

usage: tools/redact.py LITERALS FILE...
"""
import sys

lits = [l.rstrip('\r\n') for l in open(sys.argv[1], encoding='utf-8') if l.strip()]
found = dict.fromkeys(lits, 0)
for path in sys.argv[2:]:
    data = open(path, 'rb').read()
    for lit in lits:
        b = lit.encode('cp1252')
        n = data.count(b)
        if n:
            data = data.replace(b, bytes(c if c == 32 else ord('x') for c in b))
            found[lit] += n
    open(path, 'wb').write(data)
for lit, n in found.items():
    print(f'{n:3d} x  literal #{lits.index(lit) + 1}')
sys.exit(1 if 0 in found.values() else 0)
