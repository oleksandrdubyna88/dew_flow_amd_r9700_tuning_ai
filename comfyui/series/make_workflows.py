"""Build ComfyUI UI workflows (the editable kind the browser opens) for every shot of the series in series_elf.py.

From the official templates shipped with ComfyUI (Z-Image Turbo text-to-image, Wan 2.2 TI2V 5B), with each shot's prompt,
size, frame count and seed written in, and the template's bypassed LoadImage switched on as the video's start frame.
Run inside the container:  wslc exec comfyui python /opt/tests/make_workflows.py
Writes /data/user/default/workflows/<story>/s<N>_1_keyframe.json and s<N>_2_video.json (the Workflows sidebar shows them).
"""
import copy
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import series_elf as story  # noqa: E402  the shots, the hero text, the sizes

TEMPLATES = "/usr/local/lib/python3.12/dist-packages/comfyui_workflow_templates_json/templates"
DEST = "/data/user/default/workflows/" + ("elf_escape" if story.NAME == "elf" else story.NAME)


def load(name):
    with open(os.path.join(TEMPLATES, name)) as f:
        return json.load(f)


def nodes_of(wf):
    """Every node of the workflow, the subgraphs' inner nodes included."""
    out = list(wf.get("nodes", []))
    for sg in wf.get("definitions", {}).get("subgraphs", []):
        out += sg.get("nodes", [])
    return out


def set_seed(widgets, seed):
    widgets[0] = seed
    if len(widgets) > 1 and widgets[1] in ("randomize", "increment", "decrement", "fixed"):
        widgets[1] = "fixed"


def keyframe(i, shot, base):
    wf = copy.deepcopy(base)
    for n in nodes_of(wf):
        t, wv = n["type"], n.get("widgets_values")
        if t == "CLIPTextEncode" and wv:
            wv[0] = shot["key"]
        elif t == "EmptySD3LatentImage" and wv:
            wv[0], wv[1] = story.W, story.H
        elif t == "KSampler" and wv:
            set_seed(wv, shot["seed"])
        elif t == "SaveImage" and wv:
            wv[0] = f"series/{story.NAME}/key_s{i}"
    return wf


def video(i, shot, base):
    wf = copy.deepcopy(base)
    texts = [n for n in wf["nodes"] if n["type"] == "CLIPTextEncode"]
    for n in wf["nodes"]:
        t, wv = n["type"], n.get("widgets_values")
        if t == "LoadImage":
            n["mode"] = 0  # the template ships it bypassed; here it is the start frame
            n["widgets_values"] = [f"{story.NAME}_key_s{i}.png", "image"]
        elif t == "Wan22ImageToVideoLatent" and wv:
            wv[0], wv[1], wv[2] = story.W, story.H, story.FRAMES
        elif t == "KSampler" and wv:
            set_seed(wv, shot["seed"])
        elif t == "VAEDecode":  # the driver decodes tiled (the untiled decode spilled out of VRAM)
            n["type"] = "VAEDecodeTiled"
            n["widgets_values"] = [story.TILED[k] for k in ("tile_size", "overlap", "temporal_size", "temporal_overlap")]
        elif t == "CreateVideo" and wv:
            wv[0] = story.FPS
        elif t == "SaveVideo" and wv:
            wv[0] = f"series/{story.NAME}/clip_s{i}"
    for n in texts:  # the negative is the one whose text the template wrote in Chinese
        neg = any(ord(c) > 0x3000 for c in n["widgets_values"][0])
        n["widgets_values"][0] = story.NEG_WAN if neg else shot["motion"] + " " + story.HERO + ". Cinematic."
    if story.VIDEO:
        add_lora(wf, story.VIDEO)
    return wf


def add_lora(wf, mode):
    """Put a LoraLoaderModelOnly between the UNETLoader and ModelSamplingSD3 (rewiring the one MODEL link), and write the
    series' steps, cfg, sampler, scheduler and shift — so the workflow is the one the driver ran."""
    nodes = {n["id"]: n for n in wf["nodes"]}
    unet = next(n for n in wf["nodes"] if n["type"] == "UNETLoader")
    shift = next(n for n in wf["nodes"] if n["type"] == "ModelSamplingSD3")
    link = next(l for l in wf["links"] if l[1] == unet["id"] and l[3] == shift["id"])
    new_id = max(nodes) + 1
    new_link = max(l[0] for l in wf["links"]) + 1
    link[3], link[4] = new_id, 0                         # UNETLoader.MODEL -> LoRA.model
    wf["links"].append([new_link, new_id, 0, shift["id"], 0, "MODEL"])  # LoRA.MODEL -> ModelSamplingSD3.model
    for inp in shift["inputs"]:
        if inp.get("type") == "MODEL":
            inp["link"] = new_link
    x, y = unet.get("pos", [0, 0])
    wf["nodes"].append({
        "id": new_id, "type": "LoraLoaderModelOnly", "pos": [x, y + 140], "size": [320, 90], "flags": {}, "order": unet.get("order", 0),
        "mode": 0, "inputs": [{"name": "model", "type": "MODEL", "link": link[0]}],
        "outputs": [{"name": "MODEL", "type": "MODEL", "links": [new_link]}],
        "properties": {"Node name for S&R": "LoraLoaderModelOnly"}, "widgets_values": [mode["lora"], 1.0]})
    wf["last_node_id"] = max(wf.get("last_node_id", 0), new_id)
    wf["last_link_id"] = max(wf.get("last_link_id", 0), new_link)
    shift["widgets_values"][0] = mode["shift"]
    ks = next(n for n in wf["nodes"] if n["type"] == "KSampler")["widgets_values"]
    ks[2], ks[3], ks[4], ks[5] = mode["steps"], mode["cfg"], mode["sampler"], mode["scheduler"]


def main():
    os.makedirs(DEST, exist_ok=True)
    kbase, vbase = load("image_z_image_turbo.json"), load("video_wan2_2_5B_ti2v.json")
    for i, shot in enumerate(story.SHOTS, 1):
        for name, wf in ((f"s{i}_1_keyframe.json", keyframe(i, shot, kbase)), (f"s{i}_2_video.json", video(i, shot, vbase))):
            path = os.path.join(DEST, name)
            with open(path + ".part", "w") as f:
                json.dump(wf, f, ensure_ascii=False, indent=1)
            os.replace(path + ".part", path)
            print("wrote", path)


if __name__ == "__main__":
    main()
