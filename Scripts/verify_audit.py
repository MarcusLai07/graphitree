#!/usr/bin/env python3
"""Recompute the Overview numbers from graph.json independently of the Swift importer.

Usage: Scripts/test.sh --real <graphify-out> > actual.json
       python3 -I Scripts/verify_audit.py <graphify-out> actual.json
"""
import collections
import json
import os
import sys


SINGLE_REPO = None  # Set in main() when the graph's root is itself a git repo.


def project(path):
    if SINGLE_REPO:
        return SINGLE_REPO if path else "(none)"
    parts = (path or "").split("/")
    if not parts[0]:
        return "(none)"
    return "/".join(parts[:2]) if parts[0] in ("work", "personal") else parts[0]


def is_noise(path):
    needles = ("/static/lib/", "/vendor/", "/node_modules/", "/generated/", ".gen.",
               "/dist/", "/build/", "/.next/", "/migrations/")
    suffixes = (".min.js", ".min.css", ".d.ts")
    rooted = "/" + path
    return path.endswith(suffixes) or any(n in rooted for n in needles)


def main():
    out, actual_path = sys.argv[1:3]
    graph = json.load(open(os.path.join(out, "graph.json")))
    global SINGLE_REPO
    root = open(os.path.join(out, ".graphify_root")).read().strip().strip("\"'")
    SINGLE_REPO = os.path.basename(root) if os.path.exists(os.path.join(root, ".git")) else None
    nodes, edges = graph["nodes"], graph["links"]

    project_of = {n["id"]: project(n.get("source_file")) for n in nodes}
    files = collections.Counter(n["source_file"] for n in nodes if n.get("source_file"))

    def exists(path):
        if os.path.exists(os.path.join(root, path)):
            return True
        if not SINGLE_REPO:
            return False
        parent = root
        for _ in range(3):
            parent = os.path.dirname(parent)
            if os.path.exists(os.path.join(parent, path)):
                return True
        return False

    missing = {f for f in files if not exists(f)}
    degree = collections.Counter()
    for e in edges:
        degree[e["source"]] += 1
        degree[e["target"]] += 1
    labels = collections.defaultdict(set)
    for n in nodes:
        labels[n.get("norm_label") or n["label"]].add(project_of[n["id"]])

    def cross(e):
        a, b = project_of[e["source"]], project_of[e["target"]]
        return a != b and "(none)" not in (a, b)

    expected = {
        "nodes": len(nodes),
        "edges": len(edges),
        "communities": len({n.get("community") for n in nodes}),
        "sourceFiles": len(files),
        "generatedOrVendoredNodes": sum(is_noise(n.get("source_file") or "") for n in nodes),
        "noiseNodes": sum(is_noise(n.get("source_file") or "") or n.get("source_file") in missing for n in nodes),
        "crossProjectEdges": sum(cross(e) for e in edges),
        "missingFiles": len(missing),
        "staleNodes": sum(files[f] for f in missing),
        "repeatedLabels": sum(len(v) > 1 for v in labels.values()),
        "isolatedNodes": sum(degree[n["id"]] == 0 for n in nodes),
        "nodesWithoutSource": sum(not n.get("source_file") for n in nodes),
    }

    actual = json.load(open(actual_path))
    bad = 0
    for key, want in expected.items():
        got = actual.get(key)
        mark = "ok  " if got == want else "FAIL"
        bad += got != want
        print(f"{mark} {key:26} swift={got:>8} python={want:>8}")
    print("\nAll counts match." if not bad else f"\n{bad} count(s) differ.")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
