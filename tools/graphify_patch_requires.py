"""Patch graphify-out/graph.json with the Luau require links graphify misses.

graphify's AST pass can't resolve Roblox-style requires such as
`require(script.Parent:WaitForChild("ModelSyncLookup"))` or
`require(Modules.BattleService)`. It turns them into placeholder nodes
(`script_parent_waitforchild`, `script_parent_basemanager`, ...) or drops them,
so modules end up disconnected or falsely joined through a shared stub.

This script:
  1. removes those placeholder nodes and their edges,
  2. scans every .luau file under src/ and tests/ for require(...) calls,
     resolves each one by its last path segment to a module file node,
     and adds a real `imports` edge (file -> module),
  3. re-clusters, carries community names over from the previous graph,
     and rewrites graph.json, GRAPH_REPORT.md and graph.html.

Run it after every `/graphify` rebuild or `--update` (a rebuild overwrites the patch):
    python tools/graphify_patch_requires.py
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from collections import Counter, defaultdict
from pathlib import Path

import networkx as nx

ROOT = Path(__file__).resolve().parent.parent
GRAPH = ROOT / "graphify-out" / "graph.json"
REPORT = ROOT / "graphify-out" / "GRAPH_REPORT.md"
SCAN_DIRS = ("src", "tests")
# Placeholder nodes for real external libraries (used by the Python generators) stay.
KEEP_STUBS = {"json", "math", "random"}
PATCH_ORIGIN = "require_patch"

REQUIRE_START = re.compile(r"\brequire\s*\(")
SEGMENT = re.compile(r'"([A-Za-z_][A-Za-z0-9_]*)"|\.([A-Za-z_][A-Za-z0-9_]*)|\b([A-Za-z_][A-Za-z0-9_]*)')


def module_name(path: Path) -> str:
    name = path.name
    for suffix in (".server.luau", ".client.luau", ".spec.luau", ".luau"):
        if name.endswith(suffix):
            return name[: -len(suffix)]
    return path.stem


def require_args(text: str):
    """Yield (line_number, inner_text) for each require(...) call, with balanced parens."""
    for m in REQUIRE_START.finditer(text):
        depth, i = 1, m.end()
        while i < len(text) and depth:
            if text[i] == "(":
                depth += 1
            elif text[i] == ")":
                depth -= 1
            i += 1
        if depth == 0:
            yield text.count("\n", 0, m.start()) + 1, text[m.end() : i - 1]


def last_segment(arg: str) -> str | None:
    found = None
    for s in SEGMENT.finditer(arg):
        found = s.group(1) or s.group(2) or s.group(3)
    return found


def load_graph(data: dict) -> nx.Graph:
    G = nx.Graph()
    G.graph.update(data.get("graph", {}))
    for n in data["nodes"]:
        attrs = dict(n)
        G.add_node(attrs.pop("id"), **attrs)
    for e in data.get("links", data.get("edges", [])):
        attrs = dict(e)
        G.add_edge(attrs.pop("source"), attrs.pop("target"), **attrs)
    return G


def carry_labels(G: nx.Graph, communities: dict[int, list[str]], old_names: dict[str, str]) -> dict[int, str]:
    """Name each new community after the old community most of its nodes came from.

    If no old community supplies at least 60% of the members, the old name would
    mislead, so the community is named after its biggest source files instead.
    """
    labels: dict[int, str] = {}
    used: Counter[str] = Counter()
    for cid, members in sorted(communities.items(), key=lambda kv: -len(kv[1])):
        votes = Counter(old_names[m] for m in members if m in old_names)
        top = votes.most_common(1)
        if top and top[0][1] >= 0.6 * len(members):
            name = top[0][0]
        else:
            files = Counter(
                module_name(Path(G.nodes[m]["source_file"])) for m in members if G.nodes[m].get("source_file")
            )
            name = " & ".join(f for f, _ in files.most_common(2)) or f"Community {cid}"
        used[name] += 1
        labels[cid] = name if used[name] == 1 else f"{name} ({used[name]})"
    return labels


def main() -> int:
    from graphify.analyze import god_nodes, suggest_questions, surprising_connections
    from graphify.cluster import cluster, score_all
    from graphify.detect import detect
    from graphify.export import to_json
    from graphify.report import generate

    data = json.loads(GRAPH.read_text(encoding="utf-8"))
    G = load_graph(data)
    old_names = {n: a.get("community_name") for n, a in G.nodes(data=True) if a.get("community_name")}

    # 1. Drop require placeholders (code stubs with no source file).
    stubs = [
        n for n, a in G.nodes(data=True)
        if not a.get("source_file") and a.get("file_type") == "concept" and n not in KEEP_STUBS
        and all(G.edges[n, m].get("relation") in ("imports", "calls") for m in G[n])
    ]
    G.remove_nodes_from(stubs)
    # Earlier patch edges are rebuilt from scratch so re-running is idempotent.
    old_patch = [(u, v) for u, v, a in G.edges(data=True) if a.get("_origin") == PATCH_ORIGIN]
    G.remove_edges_from(old_patch)

    # 2. Map module names to their file nodes.
    file_node: dict[str, str] = {}
    by_name: dict[str, list[str]] = defaultdict(list)
    for n, a in G.nodes(data=True):
        sf = a.get("source_file") or ""
        if sf.endswith(".luau") and a.get("label") == Path(sf).name:
            file_node[sf] = n
            by_name[module_name(Path(sf))].append(sf)

    added, unresolved, ambiguous = 0, Counter(), Counter()
    for d in SCAN_DIRS:
        for path in sorted((ROOT / d).rglob("*.luau")):
            rel = path.relative_to(ROOT).as_posix()
            src = file_node.get(rel)
            if not src:
                continue
            text = path.read_text(encoding="utf-8", errors="replace")
            for line, arg in require_args(text):
                name = last_segment(arg)
                targets = by_name.get(name or "", [])
                if not targets:
                    unresolved[name or arg.strip()[:40]] += 1
                    continue
                if len(targets) > 1:
                    # Prefer a module beside the requiring file, else flag it.
                    near = [t for t in targets if Path(t).parent == Path(rel).parent]
                    if len(near) != 1:
                        ambiguous[name] += 1
                        continue
                    targets = near
                dst = file_node[targets[0]]
                if dst == src or G.has_edge(src, dst):
                    continue
                G.add_edge(
                    src, dst, relation="imports", confidence="EXTRACTED", confidence_score=1.0,
                    context="import", source_file=rel, source_location=f"L{line}", weight=1.0,
                    _origin=PATCH_ORIGIN,
                )
                added += 1

    # 3. Re-cluster and rewrite outputs.
    communities = cluster(G)
    cohesion = score_all(G, communities)
    labels = carry_labels(G, communities, old_names)
    gods = god_nodes(G)
    surprises = surprising_connections(G, communities)
    questions = suggest_questions(G, communities, labels)
    if not to_json(G, communities, str(GRAPH), community_labels=labels, force=True):
        print("ERROR: graph.json was not written")
        return 1
    detection = detect(ROOT)
    cost_path = ROOT / "graphify-out" / "cost.json"
    last = json.loads(cost_path.read_text(encoding="utf-8"))["runs"][-1] if cost_path.exists() else {}
    tokens = {"input": last.get("input_tokens", 0), "output": last.get("output_tokens", 0)}
    report = generate(G, communities, cohesion, labels, gods, surprises, detection, tokens, ".",
                      suggested_questions=questions)
    REPORT.write_text(report, encoding="utf-8")
    (ROOT / "graphify-out" / ".graphify_labels.json").write_text(
        json.dumps({str(k): v for k, v in labels.items()}, ensure_ascii=False), encoding="utf-8")
    subprocess.run(["graphify", "export", "html"], cwd=ROOT, check=False)

    print(f"Removed {len(stubs)} placeholder nodes; added {added} require edges")
    print(f"Graph: {G.number_of_nodes()} nodes, {G.number_of_edges()} edges, {len(communities)} communities")
    if unresolved:
        print("Unresolved requires (no matching module file):", dict(unresolved.most_common()))
    if ambiguous:
        print("Ambiguous module names (skipped):", dict(ambiguous))
    return 0


if __name__ == "__main__":
    sys.exit(main())
