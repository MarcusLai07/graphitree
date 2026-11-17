#!/usr/bin/env python3
"""Recompute graph.clean.json from graph.json and curation.jsonl, independently of the Swift code.

Usage: python3 -I Scripts/verify_clean.py <graphify-out>
"""
import json
import os
import re
import sys

CODE_RELATIONS = {"calls", "indirect_call", "references", "imports", "imports_from",
                  "implements", "inherits", "method", "contains", "re_exports"}


SINGLE_REPO = None  # Set in main() when the graph's root is itself a git repo.


def project(path):
    if SINGLE_REPO:
        return SINGLE_REPO if path else "(none)"
    parts = (path or "").split("/")
    if not parts[0]:
        return "(none)"
    return "/".join(parts[:2]) if parts[0] in ("work", "personal") else parts[0]


def glob_regex(pattern):
    if pattern.endswith("/"):
        pattern += "**"
    if "/" not in pattern:
        pattern = "**/" + pattern
    out = ""
    parts = pattern.split("/")
    for i, part in enumerate(parts):
        last = i == len(parts) - 1
        if part == "**":
            out += ".*" if last else "(?:[^/]+/)*"
        else:
            out += "[^/]*".join(re.escape(p) for p in part.split("*"))
            if not last:
                out += "/"
    return re.compile("^" + out + "$")


def is_config_key(key, path):
    name = os.path.basename(path).lower()
    return name.endswith((".json", ".toml", ".yaml", ".yml")) and key.lower() != name


def main():
    global SINGLE_REPO
    out = sys.argv[1]
    marker = os.path.join(out, ".graphify_root")
    root = open(marker).read().strip().strip("\"'") if os.path.exists(marker) else os.path.dirname(os.path.abspath(out))
    SINGLE_REPO = os.path.basename(root) if os.path.exists(os.path.join(root, ".git")) else None
    graph = json.load(open(os.path.join(out, "graph.json")))
    clean = json.load(open(os.path.join(out, "graph.clean.json")))
    entries = [json.loads(line) for line in open(os.path.join(out, "curation.jsonl")) if line.strip()]
    revoked = {e["rule"] for e in entries if e["op"] == "revoke"}
    live = [e for e in entries if e["id"] not in revoked]

    globs = [glob_regex(e["glob"]) for e in live if e["op"] == "hide_path"]
    hidden_nodes = {e["node"] for e in live if e["op"] == "hide_node"}
    labels = {e["label"] for e in live if e["op"] == "hide_config_label"}
    hubs = {e["target"] for e in live if e["op"] == "reject_edges"}
    pairs = {(frozenset((e["source"], e["target"])), e["relation"]) for e in live if e["op"] == "reject_edge"}

    def hidden(n):
        path = n.get("source_file") or ""
        key = n.get("norm_label") or n["label"]
        return (n["id"] in hidden_nodes
                or (path and any(g.match(path) for g in globs))
                or (is_config_key(key, path) and key in labels))

    by_id = {n["id"]: n for n in graph["nodes"]}
    gone = {n["id"] for n in graph["nodes"] if hidden(n)}

    def suspect(e):
        a, b = by_id[e["source"]], by_id[e["target"]]
        pa, pb = project(a.get("source_file")), project(b.get("source_file"))
        return (e["relation"] in CODE_RELATIONS and pa != pb and "(none)" not in (pa, pb)
                and a.get("file_type") == "code" and b.get("file_type") == "code")

    def edge_kept(e):
        if e["source"] in gone or e["target"] in gone:
            return False
        if (frozenset((e["source"], e["target"])), e["relation"]) in pairs:
            return False
        return not (suspect(e) and (e["source"] in hubs or e["target"] in hubs))

    want_nodes = {n["id"]: n for n in graph["nodes"] if n["id"] not in gone}
    key = lambda e: (e["source"], e["target"], e["relation"])
    want_edges = {key(e): e for e in graph["links"] if edge_kept(e)}
    got_nodes = {n["id"]: n for n in clean["nodes"]}
    got_edges = {key(e): e for e in clean["links"]}

    bad = 0

    def report(name, ok, detail=""):
        nonlocal bad
        bad += not ok
        print(f"{'ok  ' if ok else 'FAIL'} {name} {detail}")

    report("node ids match", set(want_nodes) == set(got_nodes), f"{len(want_nodes)} vs {len(got_nodes)}")
    report("edges match", set(want_edges) == set(got_edges), f"{len(want_edges)} vs {len(got_edges)}")
    report("node fields preserved", all(want_nodes[i] == got_nodes[i] for i in want_nodes.keys() & got_nodes.keys()))
    report("edge fields preserved", all(want_edges[k] == got_edges[k] for k in want_edges.keys() & got_edges.keys()))
    report("no edge points at a removed node",
           all(e["source"] in got_nodes and e["target"] in got_nodes for e in clean["links"]))
    # Some graphs already list group members that have no node, so only members a rule hid count.
    report("no hidden node left in a hyperedge",
           not any(m in gone for h in clean.get("hyperedges", []) for m in h["nodes"]))
    report("top-level keys preserved", set(graph) == set(clean))
    print("\nClean graph matches." if not bad else f"\n{bad} problem(s).")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
