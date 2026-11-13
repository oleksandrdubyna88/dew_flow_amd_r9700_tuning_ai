"""Episode 3 sound (EP3_SCRIPT.md v2 Sound columns; the owner approved the 4 local audio tools, 2026-11-10).
  song  - ACE-Step 1.5 turbo (native): her sung line «Столько лет прошло, всё о том же… гудят поезда…», an ORIGINAL
          melody, soft female voice, a lone lute/nylon guitar, 3 seeds -> audio/ep3/song_<n>
  sfx   - Stable Audio 3 medium (native, 8 steps lcm): the effects and beds per script row -> audio/ep3/sfx_<name>
  music - Stable Audio 3 medium: the score pieces (Act 1-2 bed, the Act 3 drum pulse, the lonely cello) -> audio/ep3/mus_*
Prompts name only what should be heard (the edit model drew what a prompt named, even after "no"; same care here).
Run inside the comfyui container:  python /opt/tests/ep3_audio.py song|sfx|music [name...]
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import episode2 as ep  # noqa: E402

OUT = "audio/ep3"
SONG_TAGS = ("slow intimate folk ballad, soft breathy young female vocal singing quietly to herself, a lone fingerpicked "
             "nylon-string guitar like a lute, campfire at night, melancholic, tender, warm, close microphone, sparse")
SONG_LYRICS = "[Verse]\nСтолько лет прошло,\nвсё о том же…\nгудят поезда…\n\n[Outro]\n(guitar fades)"
# name: (seconds, prompt)
SFX = {
    "wind_spires": (6, "Cold wind howling softly through high stone castle spires at twilight, long gusts, distant and airy."),
    "engine_gravel": (5, "An old military diesel 4x4 engine idling and rolling slowly over gravel, then the engine shuts off."),
    "steps_courtyard": (5, "Slow footsteps of boots on old cobblestones in an empty stone courtyard, a light echo, a small stone "
                        "crumbles and falls far above."),
    "wing_snap_roar": (5, "A huge leathery wing snaps open with a heavy whoosh, a gust of downdraft, slates and stones falling and "
                       "shattering, then a deep dragon roar."),
    "wingbeats_pass": (8, "Giant slow wing beats of a dragon flying past overhead from left to right, a distant roar, wind."),
    "hall_tone": (5, "The quiet room tone of a vast stone hall, two soft footsteps, a faint high crystal hum."),
    "relic_lift": (4, "Leather on metal, a bright ring of a steel blade, a rising glassy magical chord and a soft deep bass thud."),
    "dome_close": (5, "A reversed whoosh that sucks all sound away into a low dark pressure drone."),
    "float_hum": (10, "One continuous low magical hum with faint static electric crackles and the soft rustle of cloth."),
    "eye_ignite": (3, "A sharp breath and a small fire igniting with a soft whump."),
    "flame_roar": (3, "A big flame roaring up fast and loud."),
    "pushups": (3, "A strong slow exhale and palms pressing on stone, a deep drum pulse begins."),
    "bar_creak": (3, "An iron bar creaking under weight and a strong breath."),
    "run_wall": (3, "Fast running footsteps on stone and wind rushing past."),
    "clang_servo": (3, "One sharp ringing steel clang of a sword hitting a steel shield, a mechanical servo whine and crackling "
                    "sparks, the ring carrying into the night."),
    "glade_bed": (30, "A night forest glade: a crackling campfire, a gentle silver stream flowing over stones, crickets, calm."),
    "jet_far": (6, "A faint far-off jet airliner humming high in the night sky, very distant and soft."),
}
MUSIC = {
    "mus_act1": (20, "Slow dark cinematic orchestral ambient, low strings and a soft low horn motif, mysterious, cold twilight, "
                     "building slowly."),
    "mus_act2": (24, "A glassy magical chord that swells slowly over a low dark drone, mysterious, an ancient stone hall, "
                     "cinematic ambient, a soft shimmer of bells."),
    "mus_act3": (10, "Driving cinematic training montage drums, a steady deep drum pulse that speeds up, low strings, energetic."),
    "mus_cello": (12, "A lonely solo cello playing a slow sad melody at night, intimate, quiet, gentle ending."),
}


def ace_graph(seed, n):
    return {
        "ckpt": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": "ace_step_1.5_turbo_aio.safetensors"}},
        "enc": {"class_type": "TextEncodeAceStepAudio1.5", "inputs": {
            "clip": ["ckpt", 1], "tags": SONG_TAGS, "lyrics": SONG_LYRICS, "seed": seed, "bpm": 70, "duration": 14.0,
            "timesignature": "4", "language": "ru", "keyscale": "A minor", "generate_audio_codes": True,
            "cfg_scale": 2.0, "temperature": 0.85, "top_p": 0.9, "top_k": 0, "min_p": 0.0}},
        "zero": {"class_type": "ConditioningZeroOut", "inputs": {"conditioning": ["enc", 0]}},
        "shift": {"class_type": "ModelSamplingAuraFlow", "inputs": {"model": ["ckpt", 0], "shift": 3.0}},
        "latent": {"class_type": "EmptyAceStep1.5LatentAudio", "inputs": {"seconds": 14.0, "batch_size": 1}},
        "sampler": {"class_type": "KSampler", "inputs": {
            "model": ["shift", 0], "positive": ["enc", 0], "negative": ["zero", 0], "latent_image": ["latent", 0],
            "seed": seed, "steps": 8, "cfg": 1.0, "sampler_name": "euler", "scheduler": "simple", "denoise": 1.0}},
        "decode": {"class_type": "VAEDecodeAudio", "inputs": {"samples": ["sampler", 0], "vae": ["ckpt", 2]}},
        "save": {"class_type": "SaveAudioAdvanced", "inputs": {"audio": ["decode", 0], "filename_prefix": f"{OUT}/song_{n}",
                                                               "format": "flac"}},
    }


def sa3_graph(prompt, seconds, seed, prefix):
    return {
        "ckpt": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": "stable_audio_3_medium.safetensors"}},
        "clip": {"class_type": "CLIPLoader", "inputs": {"clip_name": "t5gemma_b_b_ul2.safetensors", "type": "stable_audio",
                                                        "device": "default"}},
        "pos": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["clip", 0], "text": prompt}},
        "neg": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["clip", 0], "text": ""}},
        "latent": {"class_type": "EmptyLatentAudio", "inputs": {"seconds": float(seconds), "batch_size": 1}},
        "sampler": {"class_type": "KSampler", "inputs": {
            "model": ["ckpt", 0], "positive": ["pos", 0], "negative": ["neg", 0], "latent_image": ["latent", 0],
            "seed": seed, "steps": 8, "cfg": 1.0, "sampler_name": "lcm", "scheduler": "simple", "denoise": 1.0}},
        "decode": {"class_type": "VAEDecodeAudio", "inputs": {"samples": ["sampler", 0], "vae": ["ckpt", 2]}},
        "save": {"class_type": "SaveAudioAdvanced", "inputs": {"audio": ["decode", 0], "filename_prefix": prefix,
                                                               "format": "flac"}},
    }


# Episode 1 v3 sound (the reviewer's critique, agreed 2026-11-10): layered effects per shot, a quiet original music bed
# under the narrator, the cave after the hard cut to silence. Mode "ep1" -> audio/ep1/<name>.
EP1_OUT = "audio/ep1"
EP1 = {
    "dawn_forest": (8, "An ancient forest at dawn: soft birdsong, a light wind in tall trees, calm and peaceful."),
    "far_blasts": (6, "Deep distant thunderous rumbles of huge explosions rolling over mountains, a low roaring wind."),
    "flash_blast": (4, "A sharp rising whoosh into a deafening blast and a shockwave of wind with flying debris."),
    "forest_fire": (8, "A roaring forest fire: crackling burning trees, falling branches, fast running footsteps."),
    "boiling_river": (7, "A boiling river: loud hissing steam, bubbling rapids, splashes on wet rocks."),
    "cave_waterfall": (10, "A waterfall heard from inside a quiet cave: soft heavy falling water, slow water drops."),
    "mus_bed": (26, "A quiet original orchestral bed for an ancient legend: a solemn low cello, a soft choir pad, slow, "
                    "ominous, building gently."),
}


# Episode 2 upgrade (the owner, 2026-11-10: FILM + the new sound design, NO new clips, both approved versions): one
# effect per shot of the 9 clips + a music bed under the VoxCPM narrator. Mode "ep2" -> audio/ep2/<name>.
EP2_OUT = "audio/ep2"
EP2 = {
    "cave_fire": (6, "A small crackling campfire inside a dry cave, a waterfall roaring softly outside."),
    "sleep_embers": (6, "Soft glowing embers with a quiet crackle, a gentle waterfall far away, a peaceful night."),
    "storm_clouds": (6, "A cold wind rising, distant rolling thunder, heavy dark clouds moving in."),
    "dead_forest": (6, "A cold wind through dead bare trees, creaking branches, slow footsteps crunching in ash."),
    "wolves": (6, "Low growls and sniffing of wolves prowling close by in a dead forest, tense and quiet."),
    "leave_cave": (6, "A leather strap pulled tight, footsteps on stone walking out of a cave into a cold wind."),
    "truck_start": (6, "A heavy truck door closes, an old diesel engine cranks and starts with a deep rumble."),
    "drive": (6, "An old military truck driving fast on a cracked road: engine roar, tyres on gravel, rushing wind."),
    "rise_wind": (8, "A high cold wind over a vast grey wasteland, a distant engine fading away."),
    "mus_ep2": (50, "A melancholic original orchestral bed for a dying world: soft piano and low strings, slow, then a "
                    "faint warm hope rising at the end."),
}


def done(prefix):
    return ep.newest(f"/data/output/{prefix}_*.flac")


def main(mode, names):
    if mode == "song":
        for n, seed in enumerate((3801, 3802, 3803), 1):
            if not done(f"{OUT}/song_{n}"):
                secs, _ = ep.story.run(ace_graph(seed, n), 1800)
                print(f"ep3 audio song_{n}: {secs:.1f} s", flush=True)
        return
    if mode in ("ep1", "ep2"):
        table, out, seed0 = (EP1, EP1_OUT, 3950) if mode == "ep1" else (EP2, EP2_OUT, 4050)
        for i, (name, (seconds, prompt)) in enumerate(table.items()):
            prefix = f"{out}/{name}"
            if (not names or name in names) and not done(prefix):
                secs, _ = ep.story.run(sa3_graph(prompt, seconds, seed0 + i, prefix), 1800)
                print(f"{mode} audio {name}: {secs:.1f} s", flush=True)
        return
    table = SFX if mode == "sfx" else MUSIC
    for i, (name, (seconds, prompt)) in enumerate(table.items()):
        if names and name not in names:
            continue
        prefix = f"{OUT}/{name if mode == 'music' else 'sfx_' + name}"
        if not done(prefix):
            secs, _ = ep.story.run(sa3_graph(prompt, seconds, 3850 + i, prefix), 1800)
            print(f"ep3 audio {name}: {secs:.1f} s", flush=True)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2:])
