"""The series' pipelines as ComfyUI UI workflows (the kind the browser opens and edits), for study and for play.

The owner (2026-11-09) wants to open the pipelines in the ComfyUI page, see every node and link, and change the parameters.
The drivers (episode2.py, ep2_edit.py, series_elf.py) build API graphs; this script converts the same graphs to the UI
format: the widget order is read from the running server's /object_info, so it matches the installed ComfyUI. Each workflow
gets an explaining note (what each node does, which knobs matter, what we measured).
Run inside the container:  wslc exec comfyui python /opt/tests/ui_workflows.py
Writes /data/user/default/workflows/elf_study/*.json (the Workflows sidebar shows them) and *_api.json copies to
/data/output/series/workflows (an API graph also opens by drag-and-drop into the page).
"""
import json
import os
import sys
import time
import urllib.request
import uuid

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ep2_edit  # noqa: E402
import episode2 as ep  # noqa: E402
from eyes_try import GAZE  # noqa: E402

API = "http://127.0.0.1:8188"
DEST = "/data/user/default/workflows/elf_study"
API_DEST = "/data/output/series/workflows"
WIDGET_TYPES = {"INT", "FLOAT", "STRING", "BOOLEAN", "COMBO"}
COL_W, GAP_Y = 460, 40


def object_info(types):
    out = {}
    for t in sorted(types):
        for attempt in range(30):  # the run scripts restart the server between clips
            try:
                with urllib.request.urlopen(f"{API}/object_info/{t}", timeout=30) as r:
                    out[t] = json.load(r)[t]
                break
            except OSError:
                time.sleep(10)
        else:
            raise SystemExit(f"no /object_info for {t}")
    return out


def is_widget(spec):
    kind = spec[0]
    opts = spec[1] if len(spec) > 1 else {}
    if opts.get("forceInput"):
        return False
    return isinstance(kind, list) or kind in WIDGET_TYPES or kind.startswith("COMFY_DYNAMICCOMBO")


def default_of(spec):
    kind, opts = spec[0], (spec[1] if len(spec) > 1 else {})
    if "default" in opts:
        return opts["default"]
    if isinstance(kind, list):
        return kind[0] if kind else ""
    if opts.get("options"):
        first = opts["options"][0]
        return first.get("key") if isinstance(first, dict) else first
    return {"INT": 0, "FLOAT": 0.0, "STRING": "", "BOOLEAN": False}.get(kind, None)


def depth(graph):
    memo = {}

    def d(k):
        if k not in memo:
            ups = [v[0] for v in graph[k]["inputs"].values() if isinstance(v, list) and len(v) == 2 and v[0] in graph]
            memo[k] = 1 + max((d(u) for u in ups), default=-1)
        return memo[k]
    return {k: d(k) for k in graph}


def node_size(cls, n_widgets, n_inputs, text_heavy):
    if text_heavy:
        return [420, 300]
    return [380, 46 + 26 * (n_widgets + n_inputs)]


def to_ui(graph, info, titles, notes, overrides=None):
    """API graph {key: {class_type, inputs}} -> UI workflow. titles: {key: title}; notes: [(title, markdown)]."""
    overrides = overrides or {}
    ids = {k: i for i, k in enumerate(graph, 1)}
    cols = depth(graph)
    links, nodes, next_link = [], [], 1
    out_links = {k: {} for k in graph}
    in_slots = {}
    for k, node in graph.items():  # the inputs of each node: the link-type ones in object_info order
        oi = info[node["class_type"]]
        order = oi.get("input_order") or {s: list(oi["input"].get(s, {})) for s in ("required", "optional")}
        slots, widgets = [], []
        for section in ("required", "optional"):
            for name in order.get(section, []):
                spec = oi["input"][section][name]
                val = node["inputs"].get(name)
                linked = isinstance(val, list) and len(val) == 2 and isinstance(val[0], str)
                if is_widget(spec):
                    if linked:
                        slots.append({"name": name, "type": spec[0] if isinstance(spec[0], str) else "COMBO",
                                      "widget": {"name": name}, "link": None, "_src": val})
                        val = default_of(spec)
                    widgets.append(default_of(spec) if val is None else val)
                    opts = spec[1] if len(spec) > 1 else {}
                    if opts.get("control_after_generate"):
                        widgets.append("fixed")
                    if opts.get("image_upload"):
                        widgets.append("image")
                else:
                    slots.append({"name": name, "type": spec[0], "link": None, "_src": val if linked else None})
        if k in overrides:
            widgets = overrides[k]
        in_slots[k] = (slots, widgets)
    for k, (slots, _) in in_slots.items():
        for idx, s in enumerate(slots):
            src = s.pop("_src")
            if src:
                skey, sslot = src
                stype = info[graph[skey]["class_type"]]["output"][sslot]
                links.append([next_link, ids[skey], sslot, ids[k], idx, stype])
                out_links[skey].setdefault(sslot, []).append(next_link)
                s["link"] = next_link
                next_link += 1
    y_at = {}
    for order_no, (k, node) in enumerate(sorted(graph.items(), key=lambda kv: (cols[kv[0]], ids[kv[0]]))):
        cls = node["class_type"]
        oi = info[cls]
        slots, widgets = in_slots[k]
        text_heavy = any(isinstance(w, str) and len(w) > 120 for w in widgets)
        size = node_size(cls, len(widgets), len(slots), text_heavy)
        col = cols[k]
        y = y_at.get(col, 0)
        y_at[col] = y + size[1] + GAP_Y
        names = oi.get("output_name") or oi["output"]
        outputs = [{"name": names[i], "type": t, "slot_index": i, "links": out_links[k].get(i, [])}
                   for i, t in enumerate(oi["output"])]
        n = {"id": ids[k], "type": cls, "pos": [col * COL_W, y], "size": size, "flags": {}, "order": order_no, "mode": 0,
             "inputs": slots, "outputs": outputs, "properties": {"Node name for S&R": cls}, "widgets_values": widgets}
        if k in titles:
            n["title"] = titles[k]
        nodes.append(n)
    nid = len(graph)
    x = 0
    for title, text in notes:  # the explaining notes, above the graph's first columns (seen first when it opens)
        nid += 1
        h = 120 + 18 * text.count("\n")
        nodes.append({"id": nid, "type": "MarkdownNote", "pos": [x, -h - 60], "size": [880, h], "flags": {}, "order": nid,
                      "mode": 0, "inputs": [], "outputs": [], "properties": {}, "title": title, "widgets_values": [text],
                      "color": "#432", "bgcolor": "#653"})
        x += 880 + GAP_Y
    return {"id": str(uuid.uuid4()), "revision": 0, "last_node_id": nid, "last_link_id": next_link - 1, "nodes": nodes, "links": links, "groups": [],
            "config": {}, "extra": {"ds": {"scale": 0.6, "offset": [60, 520]}}, "version": 0.4}


# ---- the four pipelines, each with the values the films were made with ----

def qwen_keyframe():
    s = ep.SHOTS[0]
    g = ep.story.qwen_keyframe_wf(1, {"key": f"{s['key']} {s['style']}", "seed": s["seed"]})
    g["save"]["inputs"]["filename_prefix"] = "study/key_qwen"
    titles = {"unet": "1. Image model: Qwen-Image 2512 (fp8)", "lora": "2. Lightning LoRA: 4 steps instead of ~40",
              "clip": "3. Text encoder: Qwen2.5-VL 7B", "vae": "VAE: latent <-> pixels", "shift": "4. Sampling shift",
              "pos": "5. Prompt: what to draw", "neg": "Negative prompt (empty: cfg 1 ignores it)",
              "latent": "6. Picture size (empty latent)", "sampler": "7. Sampler: 4 steps, cfg 1",
              "decode": "8. Decode to pixels", "save": "9. Save (output/study/)"}
    note = ("## Keyframe: text to image (Qwen-Image 2512 + Lightning)\n"
            "The first frame of a shot, drawn from the prompt. Episode 2, shot 1.\n\n"
            "**Flow:** model -> LoRA -> shift -> sampler; prompt -> text encoder -> sampler; empty latent -> sampler -> "
            "decode -> save.\n\n"
            "**Knobs to try:**\n"
            "- *seed*: another composition with the same prompt.\n"
            "- *prompt*: the scene, the light, the clothes. Write the face words the same way in every shot.\n"
            "- *steps* 4 and *cfg* 1 belong to the Lightning LoRA. Without the LoRA: steps 30-50, cfg 2.5-4.\n"
            "- *shift* 3.1: higher gives more change in the big shapes.\n"
            "- *width x height*: 1280 x 704 fits the video model (multiples of 16).\n\n"
            "**Measured:** ~7 s per image on the R9700 after the first load.")
    return g, titles, [("What this workflow does", note)]


def arcane_restyle():
    s = ep.SHOTS[0]
    g = ep.story._keyframe_wf(1, {"key": f"{s['key']} Arcane style.", "seed": s["seed"]})
    g["lora"] = {"class_type": "LoraLoaderModelOnly", "inputs": {"model": ["unet", 0], "lora_name": ep.LORA,
                                                                  "strength_model": 1.0}}
    g["shift"]["inputs"]["model"] = ["lora", 0]
    g["src"] = {"class_type": "LoadImage", "inputs": {"image": "ep2_key_s1.png"}}
    g["enc"] = {"class_type": "VAEEncode", "inputs": {"pixels": ["src", 0], "vae": ["vae", 0]}}
    g["sampler"]["inputs"].update({"latent_image": ["enc", 0], "denoise": 0.55})
    g["save"]["inputs"]["filename_prefix"] = "study/arcane_restyle"
    titles = {"unet": "1. Image model: Z-Image Turbo", "lora": "2. Style LoRA: Arcane look",
              "src": "3. The photo-style keyframe to restyle", "enc": "4. Encode the picture to a latent",
              "pos": "5. Prompt (+ 'Arcane style.')", "sampler": "6. Sampler: denoise 0.55 = how much to redraw",
              "decode": "7. Decode", "save": "8. Save (output/study/)"}
    note = ("## Arcane restyle: image to image (Z-Image Turbo + Arcane LoRA)\n"
            "Takes a finished keyframe and paints it again in the Arcane look. Episode 2, shot 1 (first run).\n\n"
            "**The key knob is *denoise* on the sampler:**\n"
            "- 0.40: the photo shows through, a weak style.\n"
            "- 0.55: our choice, the style is strong and the scene stays.\n"
            "- 0.70: a strong style, but the face and the pose start to change.\n\n"
            "**LoRA strength** 1.0: at 0.6-0.8 the style is softer.\n\n"
            "**Known problem:** a redraw changes the face a little in every shot. Episode 2's nose did not match "
            "episode 1. The fix is the 'reference keyframe' workflow (Qwen-Image-Edit).")
    return g, titles, [("What this workflow does", note)]


def reference_keyframe():
    g = ep2_edit.edit_graph(7)
    g["save"]["inputs"]["filename_prefix"] = "study/key_from_refs"
    titles = {"unet": "1. Edit model: Qwen-Image-Edit 2511 (fp8, Lightning 4 steps merged in)",
              "clip": "2. Text + image encoder: Qwen2.5-VL 7B", "vae": "VAE",
              "ref1": "Ref 1: her profile (episode 1)", "ref2": "Ref 2: her face (episode 1)",
              "ref3": "Ref 3: the truck (shot 8)", "scale1": "scale ref 1 to ~1 MP", "scale2": "scale ref 2 to ~1 MP",
              "scale3": "scale ref 3 to ~1 MP", "pos": "3. Instruction + the 3 reference images",
              "neg": "Negative (empty, with the same images)", "shift": "4. Sampling shift",
              "latent": "5. Picture size", "sampler": "6. Sampler: 4 steps, cfg 1", "decode": "7. Decode",
              "save": "8. Save (output/study/)"}
    note = ("## Keyframe from reference images (Qwen-Image-Edit 2511)\n"
            "Draws a new scene with the SAME face: the model sees up to 3 pictures and an instruction. Episode 2 v3, "
            "shot 7 (she gets into the truck).\n\n"
            "**How the references work:** the prompt says 'the same young woman as in image 1 and image 2'. image1..3 "
            "are the inputs of the encoder node. Change a LoadImage to give another reference.\n\n"
            "**Knobs to try:**\n"
            "- the instruction text: the scene, the camera, the light.\n"
            "- *seed*.\n"
            "- *megapixels* of the scale nodes: bigger refs give more face detail, but are slower.\n\n"
            "**Measured:** 30-50 s per keyframe. The nose and the brows match episode 1.\n"
            "With only face refs, shot 7 drew a 6-wheel truck. With the truck as image 3, it drew the right car.")
    return g, titles, [("What this workflow does", note)]


def wan_video():
    k = 7
    s = ep.SHOTS[k - 1]
    g = ep.story.wan14b_video_wf(k, {"motion": f"{s['motion']} {GAZE} {ep.ARC_STYLE}", "seed": s["seed"]}, f"ep2_edit_s{k}.png")
    g["save"]["inputs"].update({"filename_prefix": "study/clip"})
    titles = {"unet_hi": "1a. Video model, HIGH-noise expert (Wan 2.2 14B I2V)", "unet_lo": "1b. Video model, LOW-noise expert",
              "lora_hi": "2a. lightx2v LoRA (4 steps), high", "lora_lo": "2b. lightx2v LoRA (4 steps), low",
              "shift_hi": "3a. shift 5", "shift_lo": "3b. shift 5", "clip": "Text encoder: UMT5-XXL",
              "vae": "VAE (Wan 2.1)", "img": "4. Start frame (the keyframe)", "pos": "5. Motion prompt",
              "neg": "Negative prompt", "i2v": "6. Image-to-video: size and frame count",
              "s_hi": "7a. Steps 0-2 with the HIGH expert (the motion)", "s_lo": "7b. Steps 2-4 with the LOW expert (the detail)",
              "decode": "8. Tiled decode (fits in VRAM)", "video": "9. Frames -> video at 16 fps",
              "save": "10. Save (output/study/)"}
    overrides = {"save": [g["save"]["inputs"]["filename_prefix"], "auto", "auto"]}
    note = ("## Video: image to video (Wan 2.2 A14B + lightx2v 4 steps)\n"
            "Animates one keyframe into 81 frames (5 s at 16 fps). Episode 2 v3, shot 7.\n\n"
            "**Two experts:** Wan 2.2 14B is two models. The HIGH-noise one makes the motion (steps 0-2). The LOW-noise "
            "one adds the detail (steps 2-4). The first sampler hands over its noisy latent "
            "(return_with_leftover_noise = enable) to the second (add_noise = disable).\n\n"
            "**Knobs to try:**\n"
            "- *motion prompt*: say what moves and how. The gaze sentence keeps the eyes steady, and episode 1's "
            "eye drift went away with it.\n"
            "- *noise_seed* on 7a: another take of the same motion.\n"
            "- *length* on 6: 81 frames = 5 s. Use 4n+1 frames. More frames need more VRAM and time.\n"
            "- *steps* 4 / *cfg* 1 belong to the lightx2v LoRA. Keep the split point (end 2 / start 2) in the middle.\n"
            "- *fps* on 9: 16 is native. Our 32/60 fps films are interpolated later, outside ComfyUI.\n\n"
            "**Measured on the R9700:** ~1000 s per clip on a freshly started server. A second clip on the same server "
            "takes ~1790 s, and the server runs out of memory after ~3 clips, so restart ComfyUI before each clip.")
    return g, titles, [("What this workflow does", note)], overrides


def main():
    os.makedirs(DEST, exist_ok=True)
    os.makedirs(API_DEST, exist_ok=True)
    builds = {"series_1_keyframe_qwen_image": qwen_keyframe(), "series_2_arcane_restyle_z_image": arcane_restyle(),
              "series_3_keyframe_from_references_qwen_edit": reference_keyframe(), "series_4_video_wan22_14b": wan_video()}
    types = {n["class_type"] for b in builds.values() for n in b[0].values()}
    info = object_info(types)
    for name, b in builds.items():
        graph, titles, notes = b[:3]
        overrides = b[3] if len(b) > 3 else None
        ui = to_ui(graph, info, titles, notes, overrides)
        for path, data in ((os.path.join(DEST, name + ".json"), ui), (os.path.join(API_DEST, name + "_api.json"), graph)):
            with open(path + ".part", "w") as f:
                json.dump(data, f, ensure_ascii=False, indent=1)
            os.replace(path + ".part", path)
        print(f"wrote {name}: {len(graph)} nodes, {len(ui['links'])} links", flush=True)


# ---- 2026-11-13 (the owner: "prepare the pipelines in the ComfyUI UI" - the LoRA family, the new models, 360, FILM,
# training in ComfyUI). Folder series_lora in the Workflows sidebar; notes in Russian (the owner's language). ----
DEST2 = "/data/user/default/workflows/series_lora"
PROMPT2 = ("slvrareal, an adult woman in her early twenties, medium shot, standing on a forest path, a calm expression, "
           "long silver-white hair, wearing a dark-green wool tunic, morning light, photorealistic photograph, natural "
           "skin texture")
TIP = ("**Промпт:** начинайте со слова-триггера `slvrareal`, потом кадр/поза, эмоция, причёска, одежда, место и свет. "
       "Красоту и фигуру пишите в промпте (например *beautiful, a slim moderately athletic build*), не в подписях датасета.")


def lora_image(kind):
    import she3_check as sc
    if kind == "qwen":
        g = ep.story.qwen_keyframe_wf(1, {"key": PROMPT2, "seed": 4521})
        g["real2"] = {"class_type": "LoraLoaderModelOnly", "inputs": {"model": ["lora", 0],
                      "lora_name": "slvrareal3.safetensors", "strength_model": 0.6}}
        g["shift"]["inputs"]["model"] = ["real2", 0]
        g["save"]["inputs"]["filename_prefix"] = "ui/qwen_slvrareal3"
        note = ("## Картинка: Qwen-Image 2512 + LoRA slvrareal3 (0.6)\nLightning, 4 шага, ~5-30 с.\n\n"
                "- *strength_model* LoRA: 0.6 лучше всего (0.8-1.0 делают лицо старше и жёстче).\n- *seed*: другая "
                "композиция.\n\n" + TIP)
    elif kind in ("flux2", "flux2k9"):
        g = sc.flux2_wf(PROMPT2, 4521, 0.8, f"ui/{kind}_slvrareal3", "9b" if kind == "flux2k9" else "4b")
        size = "9B" if kind == "flux2k9" else "4B"
        note = (f"## Картинка: FLUX.2 klein {size} + LoRA slvrareal3 (0.8)\nДистиллированная модель, 4 шага, "
                f"{'~5 с при том же тексте, ~100 с при новом (модель + энкодер 33 ГБ не помещаются в память VM)' if size == '9B' else '~3 с'}."
                "\n\n- *strength_model*: 0.6-1.0 почти одинаково; 0.8 по умолчанию.\n- *noise_seed*: другая композиция.\n\n"
                + TIP)
    else:
        g = sc.sdxl_wf(PROMPT2, 4521, 0.6, "ui/sdxl_slvrareal3")
        note = ("## Картинка: SDXL RealVisXL V5 + LoRA slvrareal3 (0.6)\n30 шагов, cfg 5.\n\n- *strength*: 0.6; "
                "при 0.8-1.0 появляются лишние люди.\n\n" + TIP)
    return g, {}, [("Что делает эта схема", note)]


def new_model(kind):
    import newmodel_check as nm
    if kind == "hidream":
        g = nm.hidream_wf(PROMPT2, 4521, 0.0, "ui/hidream")
        note = ("## Картинка: HiDream-I1 Full (17B) без LoRA\n50 шагов, cfg 5, uni_pc, shift 3 (настройки официального "
                "шаблона). ~2-6 мин на картинку; иногда зависает (дважды за ночь >30 мин).\n\nLoRA `slvrareal_hidream` "
                "обучается: когда появится, добавьте узел LoraLoaderModelOnly между UNETLoader и ModelSamplingSD3.")
    else:
        g = nm.hunyuan21_wf(PROMPT2, 4521, 0.0, "ui/hunyuan21")
        note = ("## Картинка: HunyuanImage 2.1 (17B) без LoRA\n2K (2048x1152), 20 шагов, cfg 3.5, ~35 с.\n\n"
                "**Особенности:** всё гиперболизирует — хорош для карикатур. Серебристые волосы читает как возраст: "
                "без слова *young* рисует женщину 40-50 лет. Слово *pale skin* делает «Голлума».")
    return g, {}, [("Что делает эта схема", note)]


def orbit_half2_v2v():
    import real2_check as rc
    ep.story.HERO = rc.HERO
    g = ep.story.wan14b_video_wf(2, {"motion": rc.HALF[2] + " Her arms stay held out to her sides as the camera "
                                               "circles, and lower slowly only near the end. " + rc.STYLE, "seed": 4582},
                                 "all360_flux2k9_end.png")
    del g["img"]
    g["vid"] = {"class_type": "LoadVideo", "inputs": {"file": "all360_flux2k9_h1.mp4"}}
    g["comp"] = {"class_type": "GetVideoComponents", "inputs": {"video": ["vid", 0]}}
    g["ctx"] = {"class_type": "ImageFromBatch", "inputs": {"image": ["comp", 0], "batch_index": -17, "length": 17}}
    g["end_img"] = {"class_type": "LoadImage", "inputs": {"image": "all360_flux2k9_end.png"}}
    g["i2v"]["class_type"] = "WanFirstLastFrameToVideo"
    g["i2v"]["inputs"].update({"start_image": ["ctx", 0], "end_image": ["end_img", 0], "length": 97})
    g["save"]["inputs"]["filename_prefix"] = "ui/orbit_half2_v2v"
    note = ("## 360: вторая половина орбиты (v2v)\nWan 2.2 14B. Вход: видео первой половины (LoadVideo) и стартовая "
            "картинка (LoadImage = последний кадр орбиты, круг замыкается на лице).\n\n"
            "- **17 последних кадров** первой половины (ImageFromBatch -17) — модель видит ~1 с движения, стык ровный.\n"
            "- *length* 97 = 17 контекста + 80 новых. При склейке отрежьте первые 33 кадра после FILM (17 до FILM).\n"
            "- Фраза про руки держит руки разведёнными до конца — иначе они падают сразу после стыка.\n"
            "- Перед каждым клипом 14B перезапускайте ComfyUI.")
    return g, {}, [("Что делает эта схема", note)], {"save": [g["save"]["inputs"]["filename_prefix"], "auto", "auto"]}


def film_32():
    g = {"load": {"class_type": "LoadVideo", "inputs": {"file": "all360_flux2k9_h1.mp4"}},
         "parts": {"class_type": "GetVideoComponents", "inputs": {"video": ["load", 0]}},
         "model": {"class_type": "FrameInterpolationModelLoader", "inputs": {"model_name": "film_net_fp16.safetensors"}},
         "interp": {"class_type": "FrameInterpolate", "inputs": {"interp_model": ["model", 0], "images": ["parts", 0],
                                                                 "multiplier": 2}},
         "video": {"class_type": "CreateVideo", "inputs": {"images": ["interp", 0], "fps": 32.0}},
         "save": {"class_type": "SaveVideo", "inputs": {"video": ["video", 0], "filename_prefix": "ui/film_32fps",
                                                        "format": "mp4", "codec": "h264"}}}
    note = ("## FILM: 16 -> 32 кадров/с\nПлавнее движение. 81 кадр -> 161. ~20-30 с на клип.")
    return g, {}, [("Что делает эта схема", note)], {"save": ["ui/film_32fps", "mp4", "h264"]}


def train_in_comfy():
    import comfy_train_test as ct
    g = ct.train_wf(1200)
    note = ("## Обучение LoRA прямо в ComfyUI (TrainLoraNode)\nМодель: FLUX.2 klein BASE 4B (на ней учит и musubi). "
            "Датасет: папка в input ComfyUI с картинками и .txt-подписями с тем же именем (`slvrareal5_flat` = v5).\n\n"
            "- *steps*: 1200 ≈ 12 эпох для 49 картинок с повторами; *rank* 16; *learning_rate* 1e-4.\n"
            "- Все картинки приводятся к 768x768 (узел ImageScale) — бакетов здесь нет.\n"
            "- Результат: SaveLoRA -> output/loras/<имя>_<N>_steps_00001_.safetensors; график потерь показывается "
            "в узле LossGraphNode (временное превью).\n"
            "- Чтобы использовать: скопируйте файл в models/loras и подключите LoraLoaderModelOnly.\n\n"
            "**Проверено 2026-11-13 на R9700:** работает, без ошибок; 100 шагов = 30 мин (**17,5 с/шаг** при 768, "
            "batch 1), файл 49 МБ. Это ~14x медленнее musubi-tuner на той же модели (1,2 с/шаг): 1200 шагов здесь "
            "≈ 6 ч. Для настоящих LoRA — скрипты (musubi-tuner / kohya / diffusion-pipe); эта схема — для "
            "небольших опытов прямо в UI (например 200-300 шагов).")
    return g, {}, [("Что делает эта схема", note)]


def main2():
    os.makedirs(DEST2, exist_ok=True)
    os.makedirs(API_DEST + "/ui", exist_ok=True)
    builds = {"1_lora_qwen": lora_image("qwen"), "2_lora_flux2_klein4b": lora_image("flux2"),
              "3_lora_flux2_klein9b": lora_image("flux2k9"), "4_lora_sdxl": lora_image("sdxl"),
              "5_model_hidream": new_model("hidream"), "6_model_hunyuan21": new_model("hunyuan21"),
              "7_video_360_half2_v2v": orbit_half2_v2v(), "8_video_film_32fps": film_32(),
              "9_train_lora_in_comfyui": train_in_comfy()}
    types = {n["class_type"] for b in builds.values() for n in b[0].values()}
    info = object_info(types)
    for name, b in builds.items():
        graph, titles, notes = b[:3]
        overrides = b[3] if len(b) > 3 else None
        ui = to_ui(graph, info, titles, notes, overrides)
        for path, data in ((os.path.join(DEST2, name + ".json"), ui), (os.path.join(API_DEST, "ui", name + "_api.json"), graph)):
            with open(path + ".part", "w") as f:
                json.dump(data, f, ensure_ascii=False, indent=1)
            os.replace(path + ".part", path)
        print(f"wrote {name}: {len(graph)} nodes, {len(ui['links'])} links", flush=True)


if __name__ == "__main__":
    main2() if sys.argv[1:2] == ["lora"] else main()
