#!/usr/bin/env python3
"""Ephemerous App Store hero panels — the Tmpr formula, in night-sky colours.

Flat bold ground, short white sans headline, real device frame bleeding off
the bottom edge. One HTML file per panel at exactly the store's pixel size
for the chosen device, so a headless Chrome shot at that window size is
submission-ready with no rescaling.

    python3 make_panels.py OUTDIR [ground] [device]
    ./render.sh OUTDIR WIDTH HEIGHT

    ground: canvas | midnight | dusk | brass          (default dusk)
    device: iphone69 | ipad13                          (default iphone69)
"""
import base64, json, random, sys
from pathlib import Path

ROOT   = Path("/Users/licurgen/Developer/Ephoemerous/AppStoreShots")
OUT    = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
GROUND = sys.argv[2] if len(sys.argv) > 2 else "dusk"
DEVICE = sys.argv[3] if len(sys.argv) > 3 else "iphone69"
OUT.mkdir(parents=True, exist_ok=True)

# Candidate grounds. `stars` = whether a whisper of star field suits it.
GROUNDS = {
    "canvas":   dict(bg="#0C1F36", ink="#FFFFFF", stars=True),
    "midnight": dict(bg="#1B3A5C", ink="#FFFFFF", stars=True),
    "dusk":     dict(bg="#2E3A63", ink="#FFFFFF", stars=True),
    "brass":    dict(bg="#D8A857", ink="#20180B", stars=False),
}

# Per-device store geometry. `island` draws the Dynamic Island pill — iPhone
# only; iPad wears a uniform bezel and no cutout.
DEVICES = {
    "iphone69": dict(
        W=1320, H=2868, shots=ROOT / "iPhone-6.9_1320x2868",
        frame_w=1120, frame_top=600, bezel=14, island=True,
        head_size=104, head_track=-2, copy_top=172, copy_pad=80, stars_n=90,
        panels=[
            ("01_hero_sky",  "01_launch_northin.png", "The sky above you.", "Right now."),
            ("02_hero_wind", "04_datecrown.png",      "Wind time.",         "Travel anywhere."),
            ("03_hero_keep", "03_moon_detail.png",    "Tap to know it.",    "Keep what you love."),
        ]),
    # iPad is nearly 3:4, so everything re-proportions: a wider frame, a
    # bigger headline, more air at the top. Not a rescale of the phone.
    "ipad13": dict(
        W=2064, H=2752, shots=ROOT / "iPad-13_2064x2752",
        frame_w=1560, frame_top=760, bezel=22, island=False,
        head_size=140, head_track=-3, copy_top=210, copy_pad=180, stars_n=120,
        panels=[
            ("10_hero_ipad_sky",       "12_ipad_northin_105.png",  "The sky above you.", "Right now."),
            ("11_hero_ipad_celestial", "11_ipad_northout.png", "One gesture.",       "The whole sphere."),
        ]),
}


def b64(path: Path) -> str:
    return base64.b64encode(path.read_bytes()).decode()


def starfield(seed: int, w: int, h: int, n: int) -> str:
    """A quiet scatter — never louder than the real sky inside the device."""
    rnd = random.Random(seed)
    out = []
    for _ in range(n):
        x, y = rnd.uniform(0, w), rnd.uniform(0, h)
        r = rnd.choice([1.0, 1.3, 1.7, 2.2])
        o = rnd.uniform(0.15, 0.5)
        out.append(f'<circle cx="{x:.0f}" cy="{y:.0f}" r="{r}" fill="#fff" opacity="{o:.2f}"/>')
    return "".join(out)


def panel_html(shot_file, l1, l2, seed, ground, dev) -> str:
    W, H = dev["W"], dev["H"]
    shot  = b64(dev["shots"] / shot_file)
    stars = (f'<svg class="stars" viewBox="0 0 {W} {H}">'
             f'{starfield(seed, W, H, dev["stars_n"])}</svg>') if ground["stars"] else ""

    frame_w, bezel = dev["frame_w"], dev["bezel"]
    img_w = frame_w - bezel * 2
    img_h = round(img_w * H / W)
    island = ""
    if dev["island"]:
        isl_w, isl_h = round(img_w * 0.284), round(img_w * 0.084)
        island = (f'<div class="island" style="width:{isl_w}px;height:{isl_h}px;'
                  f'top:{bezel + round(img_w * 0.030)}px;'
                  f'border-radius:{isl_h // 2}px"></div>')

    frame_r = round(frame_w * (0.115 if dev["island"] else 0.045))
    img_r   = round(frame_w * (0.098 if dev["island"] else 0.036))

    return f"""<!doctype html>
<meta charset="utf-8">
<style>
  * {{ margin:0; padding:0; box-sizing:border-box; }}
  html, body {{ width:{W}px; height:{H}px; overflow:hidden; }}
  .panel {{ position:relative; width:{W}px; height:{H}px; overflow:hidden;
            background:{ground["bg"]};
            font-family:-apple-system,"SF Pro Display","Helvetica Neue",Arial,sans-serif; }}
  svg.stars {{ position:absolute; inset:0; }}
  .copy {{ position:absolute; top:{dev["copy_top"]}px; left:0; right:0;
           text-align:center; padding:0 {dev["copy_pad"]}px; }}
  h1 {{ font-size:{dev["head_size"]}px; line-height:1.15; font-weight:700;
        letter-spacing:{dev["head_track"]}px; color:{ground["ink"]}; }}
  .device {{ position:absolute; left:50%; transform:translateX(-50%);
             top:{dev["frame_top"]}px; width:{frame_w}px; padding:{bezel}px;
             background:#000; border-radius:{frame_r}px;
             box-shadow:0 44px 90px rgba(0,0,0,.42),
                        0 0 0 2px rgba(255,255,255,.10) inset; }}
  .device img {{ display:block; width:{img_w}px; height:{img_h}px;
                 border-radius:{img_r}px; }}
  .island {{ position:absolute; left:50%; transform:translateX(-50%); background:#000; }}
</style>
<div class="panel">
  {stars}
  <div class="copy"><h1>{l1}<br>{l2}</h1></div>
  <div class="device">
    <img src="data:image/png;base64,{shot}">
    {island}
  </div>
</div>
"""


g, dev = GROUNDS[GROUND], DEVICES[DEVICE]
manifest = []
for i, (name, shot, l1, l2) in enumerate(dev["panels"]):
    out_name = f"{name}_{GROUND}"
    (OUT / f"{out_name}.html").write_text(
        panel_html(shot, l1, l2, 11 + i * 7, g, dev))
    manifest.append({"html": f"{out_name}.html", "png": f"{out_name}.png"})

(OUT / f"manifest_{DEVICE}_{GROUND}.json").write_text(json.dumps(manifest, indent=2))
print(f'{DEVICE} {GROUND}: {dev["W"]}x{dev["H"]} -> {len(manifest)} panels')
for m in manifest:
    print("  ", m["png"])
