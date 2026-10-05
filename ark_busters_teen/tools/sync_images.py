"""Sync the TEEN web art into assets/images as WebP (quality 90, alpha kept).

Source priority for every image (first that exists wins):
  1. an AI-upscaled copy in UPSCALED (C:/dev/upscale/out_teen/<name>.png,
     produced later by C:/dev/upscale/upscale.py — slow, not run here),
  2. the live site's original (https://arkbusters-teen.netlify.app/illust/),
     downloaded once into tools/.cache/illust/ — the live files are higher
     resolution than the local web pack (e.g. 941x1672 vs 506x900),
  3. the local web pack's illust/ folder.

Re-run any time; only changed sources are re-encoded.

    python tools/sync_images.py            # download missing live originals
    python tools/sync_images.py --offline  # never touch the network
"""
import argparse
import json
import sys
import urllib.parse
import urllib.request
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT.parent / "ark-busters-teen-20260910T174325Z-1-001" / "ark-busters-teen" / "illust"
LIVE = "https://arkbusters-teen.netlify.app/illust/"
CACHE = ROOT / "tools" / ".cache" / "illust"
UPSCALED = Path("C:/dev/upscale/out_teen")
ASSETS = ROOT / "assets" / "images"
STATE = ROOT / "tools" / ".cache" / "sync_state.json"
QUALITY = 90

# web file name (without .png) -> assets/images/<folder>
IMAGES = {
    "top": "hub",
    **{f"{s}-boss": "boss" for s in "ekmrs"},
    # stage title art (start screen "artmode"). s-tizu is the 地図の迷宮 art,
    # which the live page never finds (it looks for s-chizu.png) — bundled so
    # the pack can switch to it with images.art = "s-tizu".
    **{n: "title" for n in [
        "e-bunpou", "e-choubun", "e-goi", "e-hyougen",
        "k-bunpou", "k-kanji", "k-koten", "k-kotoba",
        "m-keisuu", "m-seifu", "m-shisu",
        "r-daichi", "r-genso", "r-inochi", "r-rikigaku",
        "s-jidai", "s-rekishi", "s-seigi", "s-tizu",
    ]},
    **{f"{c}-{m}": "chara" for c in ("uta", "kanade") for m in ("normal", "asette", "dame")},
    "win": "result", "lose": "result", "lose2": "result",
}
# Not used by any live page: m-iko / m-root (paid 移項・ルート stages, still
# 準備中), m-sisuu (duplicate of m-shisu), 04_study_support_transparent.png.


def source_for(name: str, offline: bool) -> Path:
    up = UPSCALED / f"{name}.png"
    if up.exists():
        return up
    cached = CACHE / f"{name}.png"
    if not cached.exists() and not offline:
        CACHE.mkdir(parents=True, exist_ok=True)
        try:
            with urllib.request.urlopen(LIVE + urllib.parse.quote(f"{name}.png"), timeout=120) as r:
                if r.headers.get_content_type().startswith("image/"):
                    cached.write_bytes(r.read())
        except Exception as e:  # noqa: BLE001 - fall back to the local pack
            print(f"  live download failed for {name}: {e}")
    if cached.exists():
        return cached
    return WEB / f"{name}.png"


def save_webp(src: Path, dst: Path):
    im = Image.open(src)
    im = im.convert("RGBA") if im.mode in ("RGBA", "LA", "P") else im.convert("RGB")
    dst.parent.mkdir(parents=True, exist_ok=True)
    im.save(dst, "WEBP", quality=QUALITY, method=6)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--offline", action="store_true")
    args = ap.parse_args()
    state = json.loads(STATE.read_text(encoding="utf-8")) if STATE.exists() else {}
    written = 0
    kinds = {"upscaled": 0, "live": 0, "local": 0}
    for name, folder in IMAGES.items():
        src = source_for(name, args.offline)
        kind = "upscaled" if src.parent == UPSCALED else "live" if src.parent == CACHE else "local"
        kinds[kind] += 1
        dst = ASSETS / folder / f"{name}.webp"
        key = dst.relative_to(ASSETS).as_posix()
        sig = f"{src}|{src.stat().st_mtime_ns}"
        if dst.exists() and state.get(key) == sig:
            continue
        save_webp(src, dst)
        state[key] = sig
        written += 1
        w, h = Image.open(src).size
        print(f"  {key:24s} <- {kind:8s} {w}x{h}  {dst.stat().st_size // 1024} KB")
    STATE.parent.mkdir(parents=True, exist_ok=True)
    STATE.write_text(json.dumps(state, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"{len(IMAGES)} images: {written} written; sources {kinds}")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
