"""VAE decode test on a saved Wan 2.2 latent (2026-11-10: the decode took ~11.7 of ~17 min per clip; ComfyUI turns MIOpen
off on this GPU — "torch.backends.cudnn.enabled = False" — unless COMFYUI_ENABLE_MIOPEN=1, so the 3D convolutions of
the video VAE may run on a slow fallback). Decodes the latent with one tile setting and saves a video, timed.
Run inside the comfyui container:  python /opt/tests/decode_test.py <latent file in output/latents/...> <label> \
    <tile> <overlap> <temporal> <temporal_overlap>   -> series/ep3/vaetest/<label>_*.mp4
"""
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import episode2 as ep  # noqa: E402


def main(latent, label, tile, overlap, temporal, t_overlap):
    name = "ep3_vaetest.latent"
    shutil.copyfile(latent, os.path.join("/data/input", name))
    wf = {
        "load": {"class_type": "LoadLatent", "inputs": {"latent": name}},
        "vae": {"class_type": "VAELoader", "inputs": {"vae_name": "wan_2.1_vae.safetensors"}},
        "decode": {"class_type": "VAEDecodeTiled", "inputs": {"samples": ["load", 0], "vae": ["vae", 0], "tile_size": tile,
                                                               "overlap": overlap, "temporal_size": temporal,
                                                               "temporal_overlap": t_overlap}},
        "video": {"class_type": "CreateVideo", "inputs": {"images": ["decode", 0], "fps": 16.0}},
        "save": {"class_type": "SaveVideo", "inputs": {"video": ["video", 0], "filename_prefix": f"series/ep3/vaetest/{label}",
                                                       "format": "mp4", "codec": "h264"}},
    }
    secs, _ = ep.story.run(wf, 3600)
    print(f"vae test {label} tile {tile}/{overlap} temporal {temporal}/{t_overlap}: {secs:.1f} s", flush=True)


if __name__ == "__main__":
    a = sys.argv[1:]
    main(a[0], a[1], *map(int, a[2:6]))
