"""Print a ComfyUI UI-format workflow (template) as nodes, widget values and links, to rebuild it as an API graph.
Run:  python3 tpl_dump.py <workflow.json>...
"""
import json
import sys

for f in sys.argv[1:]:
    g = json.load(open(f))
    print("==", f.split("/")[-1])
    nodes = g.get("nodes", [])
    for sg in g.get("definitions", {}).get("subgraphs", []):
        print("  (subgraph", sg.get("name"), ")")
        nodes = nodes + sg.get("nodes", [])
        for link in sg.get("links", []):
            if isinstance(link, dict):
                print("   sublink", link.get("origin_id"), link.get("origin_slot"), "->", link.get("target_id"),
                      link.get("target_slot"), link.get("type"))
    for n in nodes:
        print(" ", n["id"], n["type"], json.dumps(n.get("widgets_values"))[:300])
    for link in g.get("links", []):
        if isinstance(link, list):
            print("   link", link[1], link[2], "->", link[3], link[4], link[5])
