#!/usr/bin/env python3
"""Ephemerous App Store hero panels — the Tmpr formula, in night-sky colours.

Flat bold ground, short white sans headline, real device frame bleeding off
the bottom edge. One HTML file per panel at exactly the store's pixel size
for the chosen device, so a headless Chrome shot at that window size is
submission-ready with no rescaling.

    python3 make_panels.py OUTDIR [ground] [device]
    ./render.sh OUTDIR WIDTH HEIGHT

    ground: canvas | midnight | dusk | brass | solar   (default dusk)
    device: iphone69 | ipad13                          (default iphone69)
"""
import base64, json, random, sys
from pathlib import Path

ROOT   = Path("/Users/licurgen/Developer/Ephoemerous/AppStoreShots")
# Captures live under Current/<device family>; Deprecated/ holds the sets
# from earlier versions, kept for reference and never read from here.
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
    # The app icon's own gradient, top-light to bottom-gold — the same two
    # stops `AppIcon.icon` is built on (#FFDA59 → #FFA900), which is also
    # where the accent colour comes from. Ink goes DARK: white on this
    # would fail contrast at headline weight, the way it does on brass.
    # No stars — a whisper of white specks on gold reads as dust.
    "solar":    dict(bg="linear-gradient(180deg, #FFDA59 0%, #FFA900 100%)",
                     ink="#FFFFFF", stars=False),
}

# Per-device store geometry. `island` draws the Dynamic Island pill — iPhone
# only; iPad wears a uniform bezel and no cutout.
DEVICES = {
    "iphone69": dict(
        W=1320, H=2868, shots=ROOT / "Current" / "iPhone-6.9",
        frame_w=1120, frame_top=600, bezel=14, island=True,
        head_size=104, head_track=-2, copy_top=172, copy_pad=80, stars_n=90,
        # Device captures, supplied from a real iPhone — the zoomed star
        # field and the crown are compositions the simulator can't be
        # driven into headlessly (no pinch, no tap).
        # The SHIPPED set is 01 + 02 here plus the family panel from
        # make_family_panel.py. 03 stays defined so the crown panel can be
        # regenerated, but it isn't in the current three.
        panels=[
            ("01_hero_sky",     "01_named_stars.png",   "Look up.",   "Enjoy what you love."),
            ("02_hero_widgets", "05_home_widgets.png",  "Widgets.",   "For every body."),
            ("03_hero_wind",    "04_datecrown.png",     "Wind time.", "Travel anywhere."),
        ]),
    # iPad is nearly 3:4, so everything re-proportions: a wider frame, a
    # bigger headline, more air at the top. Not a rescale of the phone.
    "ipad13": dict(
        W=2064, H=2752, shots=ROOT / "Current" / "iPad-13",
        frame_w=1560, frame_top=760, bezel=22, island=False,
        head_size=140, head_track=-3, copy_top=210, copy_pad=180, stars_n=120,
        # Matches the phone, panel for panel and line for line. The widget
        # shot is the pre-fitted 2064x2752 build: the raw iPad portrait
        # capture is 1940x2778 (aspect 0.698) and this frame is 0.75, so
        # the raw one would be squashed — that file already carries the
        # blurred side fill that squares the aspect honestly.
        panels=[
            ("10_hero_ipad_sky",     "12_ipad_northin_105.png",
             "Look up.", "Enjoy what you love."),
            ("11_hero_ipad_widgets", "15_ipad_home_widgets_portrait_2064x2752.png",
             "Widgets.", "For every body."),
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
    # BEZEL-LESS: no black frame, no Dynamic Island pill. The capture is
    # the device — the store's own marketing does this now, and a bezel on
    # a coloured ground reads as a picture of a phone rather than as the
    # app. The screenshot keeps a device-ish corner radius and its shadow,
    # which is what still says "screen".
    island  = ""
    img_w   = frame_w
    img_h   = round(img_w * H / W)
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
             top:{dev["frame_top"]}px; width:{img_w}px;
             border-radius:{img_r}px;
             box-shadow:0 44px 90px rgba(0,0,0,.42); }}
  .device img {{ display:block; width:{img_w}px; height:{img_h}px;
                 border-radius:{img_r}px; }}
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
