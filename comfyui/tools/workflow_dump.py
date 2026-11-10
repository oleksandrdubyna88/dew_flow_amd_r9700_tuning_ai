#!/usr/bin/env python3
"""Prints a ComfyUI workflow in the UI format (a template from the comfyui_workflow_templates package, or a workflow saved from the UI) as its nodes, their
widget values and its links — the reading needed to rebuild it as an API-format graph for a script. Standard library only.

  workflow_dump.py <workflow.json>...

One line per node: `node <id> <type> <widget values as JSON, cut at 300 characters>`; one per link: `link <from id>:<slot> -> <to id>:<slot> <type>`.
The nodes and links of every subgraph (definitions.subgraphs) follow under `subgraph <name>`. The widget values are in the UI's order, not by input name:
the input names are read from a running server's /object_info/<node type>."""
import json
import sys

VALUE_CUT = 300


def dump(workflow):
    """The lines for one workflow object."""
    lines = []
    for node in workflow.get("nodes", []):
        lines.append(f"node {node.get('id')} {node.get('type')} {json.dumps(node.get('widgets_values'))[:VALUE_CUT]}")
    for link in workflow.get("links", []):
        if isinstance(link, list) and len(link) >= 6:
            lines.append(f"link {link[1]}:{link[2]} -> {link[3]}:{link[4]} {link[5]}")
    for sub in (workflow.get("definitions") or {}).get("subgraphs", []):
        lines.append(f"subgraph {sub.get('name')}")
        for node in sub.get("nodes", []):
            lines.append(f"  node {node.get('id')} {node.get('type')} {json.dumps(node.get('widgets_values'))[:VALUE_CUT]}")
        for link in sub.get("links", []):
            if isinstance(link, dict):
                lines.append(f"  link {link.get('origin_id')}:{link.get('origin_slot')} -> {link.get('target_id')}:{link.get('target_slot')} {link.get('type')}")
    return lines


def main(argv=None):
    paths = sys.argv[1:] if argv is None else argv
    if not paths:
        print("workflow_dump: usage: workflow_dump.py <workflow.json>...", file=sys.stderr)
        return 2
    for path in paths:
        try:
            with open(path, encoding="utf-8") as handle:
                workflow = json.load(handle)
        except (OSError, ValueError) as error:
            print(f"workflow_dump: {path}: {error}", file=sys.stderr)
            return 1
        if not isinstance(workflow, dict):
            print(f"workflow_dump: {path}: not a UI-format workflow (a JSON object with nodes and links)", file=sys.stderr)
            return 1
        print(f"== {path}")
        print("\n".join(dump(workflow)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
