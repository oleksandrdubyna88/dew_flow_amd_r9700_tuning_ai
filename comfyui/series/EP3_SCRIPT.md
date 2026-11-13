# Episode 3 — "The Castle" (script v2, 2026-11-09)

The owner's story, made into a shot list that works as cinema AND inside the model's limits (one keyframe -> one clip of
81 frames = 5.06 s at 16 fps). Reviewed with two consultants (codex gpt-6-astra, gemini-4; consult 3cb9dde4…); their
advice is merged below. About **85–95 s**, **22 generated clips** (≈110 s of material, trimmed in the edit).

## Ground rules (from what failed or worked in episodes 1–2 and from the consultants)
- **Her face:** keyframes by the reference method that made the approved test (image 1 = the whole-body/composition
  picture, images 2–3 = the young face; never the face crop first). The LoRA slvra_v1 is an option for scenes the
  references cannot do.
- **Eyes (the owner: "the eyes are the main thing"):** her eyes are shown only in TIGHT close-ups (enough pixels for the
  iris) or at a distance/profile/back where they are not resolved; never at medium distance. Every keyframe already has
  the final eye state (open, wide, closed) — the video model must not change it (a sleeping keyframe with open eyes
  "reopened" in ep2). Every face clip is checked frame by frame. The eye-test winner (new seed / 8 steps / eye sentence)
  is used for all face shots.
- **One motion per clip:** one camera move and one action per 5 s. Long camera journeys = several clips joined by
  motivated cuts (match cut on motion, light, sound), or by first-last-frame clips (both ends drawn as keyframes, so the
  face is fixed at both ends) where the joint must be invisible. A chained last frame gets a light clean-up pass first.
- **Hands and props:** keyframes start with the hands ALREADY on the grips; the clip only lifts. Left/right checked.
- **Fights:** one clean exchange, not a choreography.
- **Costume (Act 3–4):** the one-shoulder wool top, the three-piece fur skirt and thigh-high boots are drawn into every
  keyframe; motion only moves them a little. Athletic body, tasteful framing.
- **Voice first:** her lines are generated and timed BEFORE the forest clips, so the picture fits the performance.
- **No lip-sync shots:** she speaks after a gasp (lips barely move), over wide shots, or as a quiet inner voice.
- **Original designs only:** the castle (a gothic school-of-magic feeling, many spires, our own design), the sword and the
  short crystal staff, the skeletal steel training automaton — no copies of known works. The sung line uses the owner's
  words with an ORIGINAL melody.

## Look and light
Act 1: cold twilight after the winter (slate-blue sky, the last amber from ep2's sunset). Act 2: cold blue stone ->
prismatic flash (cyan, gold, violet) -> black void -> orange fire. Act 3: dawn to golden day. Act 4: moonlit night, warm
fire on her, cool blue glade.

## Act 1 — Arrival (≈19 s)
| # | Time | Picture and camera | Sound |
|---|---|---|---|
| 1 | 0–3 s | High, slowly descending view: the spired castle on a cliff above a dark lake; the old military 4x4, already near the gate, rolls in under the arch (small in frame). | Wind in the spires, the engine, gravel. A low musical motif. |
| 2 | 3–6 s | Courtyard, side tracking at waist height: she walks across the empty cobbled yard (dry fountain, fallen banners), seen from behind/three-quarter, looking up at a broken tower. A huge shadow sweeps over the stones at the end. | The engine dies behind the cut; footsteps echo; a stone crumbles above. |
| 3 | 6–9 s | Over her shoulder, low angle (she is a dark silhouette for scale): the dragon (dark scales, amber eyes, torn wings) opens its wings on the broken tower and launches; slates rain down. | One heavy wing snap, downdraft, falling debris, a deep roar. |
| 4–5 | 9–19 s | Two clips, one circle each: the camera stays near the courtyard and tilts as the dragon banks around the broken tower against the sky (the tower crossing the same screen place twice makes "two circles" readable). | Wing beats that move left/right with it; the roar far and near. Music builds, then drops before her reaction. |
| 6 | 19–23 s | TIGHT close-up, camera almost still (a micro push-in). The keyframe already has her eyes wide and lips parted; the sky moves in her eyes; a small breath. First words. | Wind drops; a soft gasp, then her velvety voice: **«Ох… не может быть!»** The dragon far away. |

## Act 2 — The relics (≈25 s)
| # | Time | Picture and camera | Sound |
|---|---|---|---|
| 7 | 23–26 s | Vaulted hall, slow dolly-in between pillars: she is near the altar in a shaft of dusty light; a sword (dark blade) and a short staff with a glowing crystal lie on the stone. | Interior room tone, two footsteps, a faint crystal hum. |
| 8 | 26–29 s | Three-quarter waist view: her hands ALREADY on the grips (sword LEFT, staff RIGHT); she lifts them a few centimetres — a flash of many colours bursts from the crystal. | Leather on metal, a ring of steel, a rising glass-like chord, a soft bass thud. |
| 9 | 29–33 s | Wide, still camera: inside the colour glow a black dome closes around her and swallows the colours; a thin coloured rim stays at its edge. | A reversed whoosh; the music is sucked away; a low pressure drone. |
| 10–11 | 33–43 s | Two crane clips: (10) floor and boots -> torso: her boots are already a little above the floor with a soft shadow; (11) torso -> the vault: head thrown back, arms spread, sword left, staff right, hair floating. She stays still; the camera moves. | One continuous low hum across both clips (hides the joint), cloth rustle, static crackle. |
| 12a | 43–46 s | Extreme close-up of her upper face: the eyes open, embers light up in the irises, the camera pushes in toward her right eye. | A sharp breath, a small ignition. |
| 12b | 46–48 s | Macro of the fiery iris filling the frame; push into the pupil until flame fills everything (a second clip from a macro keyframe; joined to 12a with a 4-frame dissolve and a radial zoom in the edit, so the eye keeps its shape). | The flame roars up — and becomes the first training impact. |

## Act 3 — Training (≈10 s, fast cuts; each from a 5 s clip, trimmed to the peak of the effort)
| # | Time | Picture and camera | Sound |
|---|---|---|---|
| 13 | 48–50 s | Push-ups, low side angle in torchlight: two slow, strong reps (no fast pumping). | Exhale, palms on stone; the drum pulse starts. |
| 14 | 50–52 s | Pull-ups on an iron beam, rear three-quarter view (back and shoulders; her face only in profile at the top). | Bar creak, breath. Cut on the upward motion. |
| 15 | 52–54 s | Running along the castle wall, side tracking, the same screen direction as the courtyard walk; the fur pieces part with her stride. | Fast footfalls, wind; the music speeds up. |
| 16 | 54–57 s | Sword practice, one decisive clash (speed-ramped): the automaton holds a sword in one hand and a round shield in the other (the owner, 2026-11-10); her blade hits its shield in a shower of orange sparks; it swings its sword back, she ducks. Above them a small camera drone hovers and records the fight (red recording light). | One sharp steel clang, servo whine, sparks — whose ringing carries into the night. **Match cut: the sparks become the embers of the campfire.** |

## Act 4 — Night in the forest (≈29 s; her voice)
| # | Time | Picture and camera | Sound and voice |
|---|---|---|---|
| 17–18 | 57–67 s | Two orbit clips of ~90° each around the moonlit glade (together 180°): the campfire on one side, the silver stream on the other, she lies on a dark bear skin in the middle and looks at the stars; a tree trunk in the foreground gives parallax. Ends on the side of her boots. | Fire crackle, stream, crickets (one continuous bed). **She sings softly** (original melody, a lone guitar/lute): **«Столько лет прошло, всё о том же… гудят поезда…»** Then **2 s: only fire and stream.** |
| 19 | 67–72 s | High angle on her boots on the fur; the camera rises along her legs to the waist; at the outburst her hand clenches the fur. | **«Блин! Да когда же уже всё встанет на места?!»** — sharp, then the question loses force. |
| 20 | 72–77 s | A fresh overhead keyframe of her upper body; the camera pulls up and back until her whole body, the fur and the fire are in frame; her chest falls in a sigh. | Tired, close to the mic: **«Я так устала быть сама.»** Warmer: **«Магия — это прекрасно…»** |
| 21 | 77–82 s | The camera keeps rising past the treetops; she becomes small; the canopy gives way to the sky. | Sad, quiet, to nobody: **«…но я хочу встретить хоть кого-то, с кем можно поговорить.»** |
| 22 | 82–86 s | Stars, almost still. In the last 1–2 s an airplane crosses the sky high above — its blinking navigation lights (the owner, 2026-11-10). | The fire and stream fade; a lonely cello; a faint far-off jet hum under the cello; no triumphant ending. |

(The owner's line is "Я так устала быть сама" — kept as written; a smoother variant is "Я так устала быть одна".)

## Her voice
One new character voice, designed once and cloned for every line (separate takes per emotion):
"a young woman of about twenty, a soft velvety mid-low voice, warm, natural Russian". Takes: shot 6 = breathy awe, a
caught breath before «Ох…», disbelief, not a shout; the song = intimate, almost to herself; the outburst = a sudden
break, sharp «Блин!», the question fading; the confession = low energy, warm on «магия», vulnerable at the end.
The sung line is made by the music model with the same words and an original melody; its timbre is matched to her
speaking voice as far as the tools allow.

## Sound design
Per-clip effects from a video-to-audio model as raw material; continuous beds (wind in Act 1, hall tone in Act 2, the
forest in Act 4) span the cuts so a cut does not sound like a new place. Music: low strings (Act 1), a glass-like chord
and a drone (Act 2), drums and an ostinato (Act 3), guitar/cello (Act 4).

## Production order
1. Her voice (design + the 6 lines) and the timing of Act 4 (audio first).
2. Keyframes per shot (reference method; checked by eye; eye state already final).
3. Clips with the eye-test winner; face clips checked frame by frame; failed ones re-rolled.
4. Sound effects, music, the sung line; the mix; the edit (trims, dissolves, the pupil zoom).
Estimated GPU time: 22 clips × ~17–30 min ≈ 7–10 h, plus keyframes and audio.
