"""Export the ARK BUSTERS TEEN web stage pages to JSON question packs.

All 21 subject pages run the same battle engine; only the question data
(`var PROBLEMS_BY_LEVEL = {...}`), the title, the balloon label and a few
image fallback lists differ. This script extracts those from each page into
`assets/data/<page>.json`, the format `ArkContent.loadPack()` serves and the
Google-Sheet updater edits generically:

    {
      "version": 1, "id": "e-bunpou", "subject": "english",
      "title": "文法の要塞", "label": "文",
      "timeLimitMs": 5000, "maxQuestions": 15,
      "images": {"art": "e-bunpou", "boss": "e-boss", "chara": "uta",
                 "win": "win", "lose": "lose2"},
      "levels": {"Lv1": [{"q": "...", "a": "...", "choices": [...], "e": "..."}, ...], ...}
    }

Image names are resolved exactly like the web's onerror fallback chains:
the first candidate that exists in the web pack's `illust/` folder wins (the
live site serves the same file set — m-kansu / m-zukei / s-chizu have no
title art there, so their start screen uses the non-illustrated layout and
`images.art` is null).

    python tools/export_teen_packs.py            # from the local web source
    python tools/export_teen_packs.py --live     # download pages from the live site
"""
import argparse
import json
import re
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT.parent / "ark-busters-teen-20260910T174325Z-1-001" / "ark-busters-teen"
LIVE = "https://arkbusters-teen.netlify.app"
CACHE = ROOT / "tools" / ".cache" / "pages"
OUT = ROOT / "assets" / "data"

SUBJECTS = {"e": "english", "k": "japanese", "m": "math", "r": "science", "s": "society"}
PAGES = [
    "m-seifu", "m-keisu", "m-shisu", "m-zukei", "m-kansu",
    "e-goi", "e-bunpou", "e-choubun", "e-hyougen",
    "k-kanji", "k-kotoba", "k-bunpou", "k-koten",
    "r-genso", "r-inochi", "r-daichi", "r-rikigaku",
    "s-chizu", "s-rekishi", "s-jidai", "s-seigi",
]
LEVELS = ["Lv1", "Lv2", "Lv3", "Lv4"]  # web showLevelSelect() order


def read_page(name: str, live: bool) -> str:
    if live:
        CACHE.mkdir(parents=True, exist_ok=True)
        path = CACHE / f"{name}.html"
        with urllib.request.urlopen(f"{LIVE}/{name}.html", timeout=60) as r:
            path.write_bytes(r.read())
        return path.read_text(encoding="utf-8")
    return (WEB / f"{name}.html").read_text(encoding="utf-8")


def js_list(src: str, pattern: str) -> list[str]:
    m = re.search(pattern + r"\s*=\s*\[([^\]]*)\]", src)
    if not m:
        raise ValueError(f"list not found: {pattern}")
    return re.findall(r"'([^']*)'", m.group(1))


def first_existing(cands: list[str], available: set[str]) -> str | None:
    for c in cands:
        if c in available:
            return Path(c).stem
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--live", action="store_true", help="download the pages from the live site")
    args = ap.parse_args()

    available = {p.name for p in (WEB / "illust").iterdir() if p.is_file()}
    OUT.mkdir(parents=True, exist_ok=True)
    total = 0
    summary = {}
    for name in PAGES:
        src = read_page(name, args.live)
        m = re.search(r"^var PROBLEMS_BY_LEVEL = (.*?);?\s*$", src, re.M)
        levels_raw = json.loads(m.group(1))
        levels = {}
        for lv in LEVELS:
            arr = levels_raw.get(lv) or []
            if not arr:
                continue
            out = []
            for p in arr:
                q = {"q": p["q"], "a": p["a"], "choices": list(p["choices"])}
                if p.get("e"):
                    q["e"] = p["e"]
                out.append(q)
            levels[lv] = out
        extra = set(levels_raw) - set(LEVELS)
        if extra:
            print(f"WARNING {name}: levels {extra} are never shown by the web engine")

        title = re.search(r'<h1 class="game-title">([^<]*)</h1>', src).group(1)
        label = re.search(r'<div class="balloon-label">([^<]*)</div>', src).group(1)
        art_m = re.search(r"var list=\[([^\]]*)\];\s*list=__img\(list\);var i=0;\(function n\(\)\{ if\(i>=list.length\) return;", src)
        art = first_existing(re.findall(r"'([^']*)'", art_m.group(1)), available)
        boss = first_existing(js_list(src, r"var BOSS"), available)
        kn = js_list(src, r"var KN")
        chara = kn[0].split("-")[0]  # 'uta' or 'kanade'
        lose_m = re.search(r"won \? \[([^\]]*)\] : \[([^\]]*)\]", src)
        win = first_existing(re.findall(r"'([^']*)'", lose_m.group(1)), available)
        lose = first_existing(re.findall(r"'([^']*)'", lose_m.group(2)), available)
        time_limit = int(re.search(r"const TIME_LIMIT = (\d+);", src).group(1))
        max_q = int(re.search(r"TOTAL_Q=Math.min\((\d+),", src).group(1))

        pack = {
            "version": 1,
            "id": name,
            "subject": SUBJECTS[name[0]],
            "title": title,
            "label": label,
            "timeLimitMs": time_limit,
            "maxQuestions": max_q,
            "images": {"art": art, "boss": boss, "chara": chara, "win": win, "lose": lose},
            "levels": levels,
        }
        (OUT / f"{name}.json").write_text(
            json.dumps(pack, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        n = sum(len(v) for v in levels.values())
        total += n
        summary[name] = {lv: len(v) for lv, v in levels.items()}
        print(f"{name:11s} {n:4d}  {summary[name]}  art={art} boss={boss} chara={chara} lose={lose}")
    print(f"TOTAL {total} questions in {len(PAGES)} packs")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
