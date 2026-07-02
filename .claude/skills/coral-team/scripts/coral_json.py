#!/usr/bin/env python3
"""Tiny JSON helper so the shell scripts don't need `jq` (only the stdlib).

Modes:
  kv     <k> <v> [<k> <v> ...]   -> build a JSON object on stdout.
                                     key prefix '@' => value is a CSV -> array
                                     key prefix '#' => value is an integer
                                     else           => value is a string
  get    <dotted.path>           -> read JSON on stdin, print value at path.
                                     scalars printed raw; objects/arrays as compact JSON;
                                     missing path or null -> exit 1
  pretty                         -> read JSON on stdin, pretty-print it
"""
import sys, json


def main():
    if len(sys.argv) < 2:
        sys.exit(3)
    mode = sys.argv[1]

    if mode == "kv":
        a = sys.argv[2:]
        o = {}
        i = 0
        while i + 1 < len(a):
            k, v = a[i], a[i + 1]
            i += 2
            if k.startswith("@"):
                o[k[1:]] = [x for x in v.split(",") if x]
            elif k.startswith("#"):
                o[k[1:]] = int(v)
            else:
                o[k] = v
        sys.stdout.write(json.dumps(o, ensure_ascii=False))

    elif mode == "get":
        path = sys.argv[2] if len(sys.argv) > 2 else ""
        try:
            cur = json.load(sys.stdin)
        except Exception:
            sys.exit(2)
        for part in (path.split(".") if path else []):
            if isinstance(cur, list):
                try:
                    cur = cur[int(part)]
                except Exception:
                    sys.exit(1)
            elif isinstance(cur, dict):
                if part in cur:
                    cur = cur[part]
                else:
                    sys.exit(1)
            else:
                sys.exit(1)
        if cur is None:
            sys.exit(1)
        sys.stdout.write(cur if isinstance(cur, str) else json.dumps(cur, ensure_ascii=False))

    elif mode == "pretty":
        try:
            d = json.load(sys.stdin)
        except Exception:
            sys.exit(2)
        sys.stdout.write(json.dumps(d, indent=2, ensure_ascii=False))

    else:
        sys.exit(3)


main()
