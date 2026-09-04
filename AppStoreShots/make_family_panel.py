#!/usr/bin/env python3
"""Ephemerous "device family" hero panel — iPad, iPhone and Watch under one line.

The Tmpr multi-device layout in the app's own colours. Two arrangements,
because the canvases differ in kind, not just size:

  iphone69 (1320x2868, ~1:2.17) — stacked: iPad above, phone and watch below,
                                  the iPad bleeding off the right edge.
  ipad13   (2064x2752, ~3:4)    — bottom-aligned cluster: watch, iPad, phone
                                  in a row. A stacked iPhone would have to
                                  shrink to ~230px wide to fit under the iPad.

    python3 make_family_panel.py OUTDIR [ground] [device]
    ./render.sh OUTDIR WIDTH HEIGHT
"""
import base64, random, sys
from pathlib import Path

ROOT   = Path("/Users/licurgen/Developer/Ephoemerous/AppStoreShots")
OUT    = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
GROUND = sys.argv[2] if len(sys.argv) > 2 else "dusk"
DEVICE = sys.argv[3] if len(sys.argv) > 3 else "iphone69"
OUT.mkdir(parents=True, exist_ok=True)

GROUNDS = {
    "canvas":   dict(bg="#0C1F36", ink="#FFFFFF", stars=True),
    "midnight": dict(bg="#1B3A5C", ink="#FFFFFF", stars=True),
    "dusk":     dict(bg="#2E3A63", ink="#FFFFFF", stars=True),
    "brass":    dict(bg="#D8A857", ink="#20180B", stars=False),
}

SHOT_PAD      = ROOT / "iPad-13_2064x2752" / "12_ipad_northin_105.png"
SHOT_PAD_LAND = ROOT / "iPad-13_2064x2752" / "13_ipad_landscape_2778x1940.png"
SHOT_PHONE = ROOT / "iPhone-6.9_1320x2868"  / "01_launch_northin.png"
SHOT_WATCH = ROOT / "AppleWatch-Ultra_410x502" / "21_watch_orloj_105.png"


def aspect(path: Path) -> float:
    """Height/width, read from the PNG's own IHDR header rather than
    hardcoded — so swapping a portrait shot for a landscape one (or any
    other capture) re-proportions its frame automatically instead of
    silently squashing the screenshot into the wrong shape."""
    head = path.read_bytes()[:24]
    if head[:8] != b"\x89PNG\r\n\x1a\n" or head[12:16] != b"IHDR":
        raise ValueError(f"{path.name} is not a PNG")
    w = int.from_bytes(head[16:20], "big")
    h = int.from_bytes(head[20:24], "big")
    return h / w


AR_PHONE, AR_WATCH = aspect(SHOT_PHONE), aspect(SHOT_WATCH)

LINE1, LINE2 = "Powered", "by iCloud."

LAYOUTS = {
    "iphone69": dict(
        W=1320, H=2868, head_size=104, head_track=-2, copy_top=190, copy_pad=80,
        stars_n=90,
        # LANDSCAPE iPad, bleeding off the right edge like the reference.
        # It costs far less height than the portrait one, so the phone and
        # watch below get to be bigger. Bottoms aligned at 2648.
        pad_shot = "land",
        pad   = dict(left=240,  top=640,  w=1280),
        phone = dict(left=690,  top=1720, w=440),
        watch = dict(left=180,  top=2183, w=380),
    ),
    "ipad13": dict(
        W=2064, H=2752, head_size=140, head_track=-3, copy_top=220, copy_pad=180,
        stars_n=120,
        # Bottoms aligned at 2520 — watch, iPad, phone in one row.
        pad_shot = "portrait",
        pad   = dict(left=447,  top=1001, w=1150),
        phone = dict(left=1667, top=1809, w=320),
        watch = dict(left=77,   top=2116, w=300),
    ),
}


def b64(p: Path) -> str:
    return base64.b64encode(p.read_bytes()).decode()


def starfield(seed, w, h, n):
    rnd = random.Random(seed)
    return "".join(
        f'<circle cx="{rnd.uniform(0,w):.0f}" cy="{rnd.uniform(0,h):.0f}" '
        f'r="{rnd.choice([1.0,1.3,1.7,2.2])}" fill="#fff" '
        f'opacity="{rnd.uniform(0.15,0.5):.2f}"/>' for _ in range(n))


def slab(cls, box, ar, shot, bezel, radius_f, radius_i, island=False):
    """A device: black bezel, screenshot inside, honest aspect ratio."""
    w     = box["w"]
    img_w = w - bezel * 2
    img_h = round(img_w * ar)
    isl = ""
    if island:
        iw, ih = round(img_w * 0.284), round(img_w * 0.084)
        isl = (f'<div class="isl" style="width:{iw}px;height:{ih}px;'
               f'top:{bezel + round(img_w*0.030)}px;border-radius:{ih//2}px"></div>')
    return f"""<div class="dev {cls}" style="left:{box['left']}px; top:{box['top']}px;
       width:{w}px; padding:{bezel}px; border-radius:{round(w*radius_f)}px;">
     <img src="data:image/png;base64,{shot}"
          style="width:{img_w}px; height:{img_h}px; border-radius:{round(w*radius_i)}px;">
     {isl}
   </div>"""


def watch(box, shot):
    """Apple Watch: cushioned case, screen, digital crown — no strap, so the
    watch reads as a device beside the others rather than a worn object."""
    w      = box["w"]
    case_h = round(w * AR_WATCH)
    inset  = round(w * 0.055)
    return f"""
   <div class="crown" style="left:{box['left'] + w - round(w*0.012)}px;
        top:{box['top'] + round(case_h*0.30)}px;
        width:{round(w*0.040)}px; height:{round(case_h*0.13)}px;
        border-radius:{round(w*0.018)}px;"></div>
   <div class="case" style="left:{box['left']}px; top:{box['top']}px;
        width:{w}px; height:{case_h}px; border-radius:{round(w*0.30)}px;">
     <img src="data:image/png;base64,{shot}"
          style="position:absolute; left:{inset}px; top:{inset}px;
                 width:{w - inset*2}px; height:{case_h - inset*2}px;
                 border-radius:{round(w*0.255)}px;">
   </div>"""


g, L = GROUNDS[GROUND], LAYOUTS[DEVICE]
PAD_SHOT = SHOT_PAD_LAND if L["pad_shot"] == "land" else SHOT_PAD
W, H = L["W"], L["H"]
stars = (f'<svg class="stars" viewBox="0 0 {W} {H}">'
         f'{starfield(29, W, H, L["stars_n"])}</svg>') if g["stars"] else ""

html = f"""<!doctype html>
<meta charset="utf-8">
<style>
  * {{ margin:0; padding:0; box-sizing:border-box; }}
  html, body {{ width:{W}px; height:{H}px; overflow:hidden; }}
  .panel {{ position:relative; width:{W}px; height:{H}px; overflow:hidden;
            background:{g["bg"]};
            font-family:-apple-system,"SF Pro Display","Helvetica Neue",Arial,sans-serif; }}
  svg.stars {{ position:absolute; inset:0; }}
  .copy {{ position:absolute; top:{L["copy_top"]}px; left:0; right:0;
           text-align:center; padding:0 {L["copy_pad"]}px; }}
  h1 {{ font-size:{L["head_size"]}px; line-height:1.15; font-weight:700;
        letter-spacing:{L["head_track"]}px; color:{g["ink"]}; }}
  .dev {{ position:absolute; background:#000;
          box-shadow:0 44px 90px rgba(0,0,0,.42),
                     0 0 0 2px rgba(255,255,255,.10) inset; }}
  .dev img {{ display:block; }}
  .isl {{ position:absolute; left:50%; transform:translateX(-50%); background:#000; }}
  /* Watch: crown sits just proud of the case's right edge. */
  .crown {{ position:absolute; background:linear-gradient(#6b6b73,#3a3a40); }}
  .case {{ position:absolute; background:linear-gradient(155deg,#43434a,#1d1d21);
           box-shadow:0 30px 60px rgba(0,0,0,.45),
                      0 0 0 2px rgba(255,255,255,.09) inset; }}
</style>
<div class="panel">
  {stars}
  <div class="copy"><h1>{LINE1}<br>{LINE2}</h1></div>
  {slab("pad",   L["pad"],   aspect(PAD_SHOT), b64(PAD_SHOT), 22, 0.045, 0.036)}
  {watch(L["watch"], b64(SHOT_WATCH))}
  {slab("phone", L["phone"], AR_PHONE, b64(SHOT_PHONE), 12, 0.115, 0.098, island=True)}
</div>
"""

name = f"family_icloud_{DEVICE}_{GROUND}"
(OUT / f"{name}.html").write_text(html)
print(f"{DEVICE} {GROUND}: {W}x{H} -> {name}.png")
