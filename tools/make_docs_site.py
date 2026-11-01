"""Build the project page served at /docs/: story arc, storyboard, checklists and the voice tracker.

The story and checklists live in docs/site/story.json. Checks tick themselves from the repo:
  "done": true                  ticked by hand
  "files": [paths]              every file exists
  "voice": ["jack/zip-it", ...] every line is recorded (data/voice_manifest.json)
  "rows": n                     the card has at least n playable rows (data/levels.json)
Images come from docs/site/img/ (made by tools/make_docs_images.py). Standard library only, so CI
can run it on a bare runner.

Usage: python3 tools/make_docs_site.py <out dir>     (writes <out>/index.html and <out>/img/)
"""
import datetime
import html
import json
import os
import re
import subprocess
import shutil
import sys
from pathlib import Path
from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parent.parent
SITE = ROOT / "docs" / "site"
KIDS = {"jack": "Jack-Jack", "becca": "Becca"}
REPO = "https://github.com/polarispixels/cruise-adventure"
VOICE_EXTS = ("m4a", "wav", "mp3", "ogg")


def _json(root: Path, rel: str):
    p = root / rel
    return json.loads(p.read_text()) if p.exists() else None


def is_done(check: dict, root: Path) -> bool:
    if "files" in check:
        return all((root / f).exists() for f in check["files"])
    if "voice" in check:
        manifest = _json(root, "data/voice_manifest.json") or {}
        return all(manifest.get(k, {}).get("kind") == "recorded" for k in check["voice"])
    if "rows" in check:
        return len(_json(root, "data/levels.json") or []) >= check["rows"]
    return bool(check.get("done"))


def _recording(root: Path, folder: str, line_id: str) -> bool:
    return any((root / "recordings" / folder / f"{line_id}.{ext}").exists() for ext in VOICE_EXTS)


def voice_table(root: Path) -> list[dict]:
    """One row per line: whose voice says it for each speaker (kid | dad | robot)."""
    manifest = _json(root, "data/voice_manifest.json") or {}
    rows = []
    for line in _json(root, "data/voice_lines.json") or []:
        row = {"id": line["id"]}
        for kid in KIDS:
            row[f"{kid}_text"] = line.get("text_by_kid", {}).get(kid, line["text"])
            if manifest.get(f"{kid}/{line['id']}", {}).get("kind") != "recorded":
                row[kid] = "robot"
            elif _recording(root, kid, line["id"]) or not _recording(root, "shared", line["id"]):
                row[kid] = "kid"
            else:
                row[kid] = "dad"
        rows.append(row)
    return rows


def e(text) -> str:
    return html.escape(str(text))


def _img(name: str, caption: str = "") -> str:
    cap = f"<figcaption>{e(caption)}</figcaption>" if caption else ""
    return f'<figure><a href="img/{e(name)}.jpg"><img src="img/{e(name)}.jpg" alt="{e(caption)}" loading="lazy"></a>{cap}</figure>'


def _progress(done: int, total: int) -> str:
    pct = round(100 * done / total) if total else 0
    return (f'<div class="bar" role="img" aria-label="{done} of {total} done"><span style="width:{pct}%"></span></div>'
            f'<span class="count">{done} of {total}</span>')


def _status(done: int, total: int) -> tuple[str, str]:
    if total and done == total:
        return "shipped", "Done"
    if done:
        return "going", "In progress"
    return "later", "Not started"


def _chapter(ch: dict, root: Path) -> str:
    if ch.get("dropped"):
        return f"""
<article class="chapter dropped" id="ch{ch['number']}">
  <header><span class="num">\u2715</span><h3>{ch['number']}. {e(ch['title'])}</h3><span class="pill dropped">Dropped</span></header>
  <p>{e(ch['dropped'])}</p>
</article>"""
    ticks = [(c, is_done(c, root)) for c in ch.get("checks", [])]
    done = sum(1 for _, d in ticks if d)
    cls, label = _status(done, len(ticks))
    if ch.get("status") and cls != "shipped":
        # "Not started" keeps the quiet "later" color; any other status is work in motion.
        cls, label = ("later" if ch["status"].strip().lower() == "not started" else "going"), ch["status"]
    items = "".join(f'<li class="{"yes" if d else "no"}">{e(c["label"])}</li>' for c, d in ticks)
    pics = "".join(_img(n, c) for n, c in ch.get("images", []))
    panels = f' · storyboard panels {e(ch["panels"])}' if ch.get("panels") else ""
    return f"""
<article class="chapter {cls}" id="ch{ch['number']}">
  <header><span class="num">{ch['number']}</span><h3>{e(ch['title'])}</h3>
    <span class="pill {cls}">{label}</span><span class="rel">{e(ch.get('release', ''))}{panels}</span></header>
  <dl>
    <dt>Video</dt><dd>{e(ch.get('video', ''))}</dd>
    <dt>Play</dt><dd>{e(ch.get('play', ''))}</dd>
    <dt>Teaches</dt><dd>“{e(ch.get('teaches', ''))}”</dd>
  </dl>
  {f'<div class="pics">{pics}</div>' if pics else ''}
  <div class="progress">{_progress(done, len(ticks))}</div>
  <ul class="checks">{items}</ul>
</article>"""


def _panel(p: dict) -> str:
    if p.get("img"):
        art = _img(p["img"]) + (_img(p["img2"]) if p.get("img2") else "")
    else:
        art = '<div class="sketch">No keyframe yet</div>'
    cls, note = ("panel dropped", " \u2715 dropped") if p.get("dropped") else ("panel", "")
    return f"""<div class="{cls}"><div class="art">{art}</div>
  <p class="pn">Panel {e(p['n'])} · Ch {p['chapter']}{note}</p><p>{e(p['picture'])}</p><p class="dad">Dad: “{e(p['dad'])}”</p></div>"""


VOICE_NAMES = {"kid": "kid", "dad": "grown-up", "robot": "computer"}


def _voices(root: Path) -> str:
    rows = voice_table(root)
    def tally(kid: str) -> str:
        return ", ".join(f"{sum(1 for r in rows if r[kid] == v)} {VOICE_NAMES[v]}" for v in ("kid", "dad", "robot"))
    body = ""
    for r in rows:
        cells = "".join(f'<td class="v {r[k]}">{VOICE_NAMES[r[k]]}</td>' for k in ("becca", "jack"))
        text = r["jack_text"] if r["jack_text"] == r["becca_text"] else f'{r["becca_text"]} / {r["jack_text"]}'
        body += f"<tr><td><code>{e(r['id'])}</code></td><td>{e(text)}</td>{cells}</tr>"
    return f"""
<p>The helper sibling does the talking, so <b>Becca's voice plays in Jack-Jack's game</b> and <b>Jack-Jack's voice plays in Becca's game</b>.
Of {len(rows)} lines, Becca's side: {tally('becca')}. Jack-Jack's side: {tally('jack')}.
“Grown-up” is one grown-up take used for both kids until a kid records their own; “computer” is the computer voice.</p>
<div class="tablewrap"><table class="voices"><thead><tr><th>Line</th><th>Words (Becca says / Jack-Jack says)</th>
<th>Becca's voice<br><small>in Jack-Jack's game</small></th><th>Jack-Jack's voice<br><small>in Becca's game</small></th></tr></thead>
<tbody>{body}</tbody></table></div>"""


def _version(root: Path) -> str:
    m = re.search(r'config/version="([^"]+)"', (root / "project.godot").read_text()) if (root / "project.godot").exists() else None
    return m.group(1) if m else "?"


def _apk_badge(tag: str, version: str) -> str:
    """The newest release (playtests included); without one, the list of all builds."""
    if tag:
        return f'<a class="alt" href="{REPO}/releases/tag/{e(tag)}">Tablet APK ({e(tag)})</a>'
    return f'<a class="alt" href="{REPO}/releases">Tablet APK (v{e(version)})</a>'


def updated_stamp(iso_date: str, sha: str) -> str:
    """'Game last updated 11:00:15 AM, Sunday, November 1 · 46e421b' (Eastern time), linked to the commit."""
    if not iso_date:
        return "Game last updated: unknown"
    t = datetime.datetime.fromisoformat(iso_date).astimezone(ZoneInfo("America/New_York"))
    hour = t.hour % 12 or 12
    text = f"Game last updated {hour}:{t:%M:%S %p}, {t:%A}, {t:%B} {t.day}"
    return text + (f' \u00b7 <a href="{REPO}/commit/{sha}">{sha}</a>' if sha else "")


def _newest_commit(root: Path) -> tuple[str, str]:
    """ISO date and short hash of the newest commit, or empty strings outside a git checkout."""
    try:
        out = subprocess.run(["git", "log", "-1", "--format=%cI %h"], cwd=root, capture_output=True,
                             text=True, check=True).stdout.split()
        return out[0], out[1]
    except (OSError, subprocess.CalledProcessError, IndexError):
        return "", ""


def render(story: dict, root: Path, latest_release: str = "") -> str:
    chapters = story.get("chapters", [])
    parts_html = ""
    for i, part in enumerate(story.get("parts", [])):
        chs = "".join(_chapter(c, root) for c in chapters if c.get("part") == i)
        parts_html += f'<h2 id="part{i + 1}">{e(part["name"])}</h2><p class="lede">{e(part["blurb"])}</p>{chs}'
    if not story.get("parts"):
        parts_html = "".join(_chapter(c, root) for c in chapters)
    overview = ""
    for c in chapters:
        if c.get("dropped"):
            overview += (f'<a class="ov dropped" href="#ch{c["number"]}"><b>\u2715 {c["number"]}</b> {e(c["title"])}'
                         f'<small>dropped</small></a>')
            continue
        ticks = [is_done(k, root) for k in c.get("checks", [])]
        cls, _ = _status(sum(ticks), len(ticks))
        overview += (f'<a class="ov {cls}" href="#ch{c["number"]}"><b>{c["number"]}</b> {e(c["title"])}'
                     f'<small>{e(c.get("release", ""))}</small>{_progress(sum(ticks), len(ticks))}</a>')
    panels = "".join(_panel(p) for p in story.get("panels", []))
    routine = " → ".join(e(s) for s in story.get("routine", []))
    built = updated_stamp(*_newest_commit(root))
    return TEMPLATE.format(
        title=e(story.get("title", "")), tagline=e(story.get("tagline", "")), routine=routine,
        apk=_apk_badge(latest_release, _version(root)), repo=REPO, overview=overview, parts=parts_html, panels=panels,
        voices=_voices(root), built=built, characters="".join(_img(n, c) for n, c in CHARACTERS))


TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Cruise Adventure Docs</title>
<meta name="description" content="Story arc, storyboard and progress checklists for Jack-Jack and Becca's Cruise Adventure.">
<style>
  :root {{ --bg:#f4f9fc; --panel:#fff; --ink:#1f3347; --soft:#5d7286; --line:#dbe7ef; --sea:#1677b8; --deep:#0d4f7d;
    --sun:#ffc23d; --ok:#2f9e57; --no:#d64545; --go:#e58a17; --later:#9aa9b6; --pink:#e5679a; }}
  @media (prefers-color-scheme: dark) {{ :root {{ --bg:#0f1b26; --panel:#162636; --ink:#e6eef5; --soft:#9fb3c4; --line:#27405a;
    --sea:#5bb3f0; --deep:#0b2c46; }} }}
  * {{ box-sizing:border-box; }}
  body {{ margin:0; background:var(--bg); color:var(--ink); font:16px/1.6 -apple-system,"Segoe UI",Roboto,Helvetica,Arial,sans-serif; }}
  a {{ color:var(--sea); }}
  .stamp {{ font-size:.85rem; opacity:.85; margin:6px 0 0; }}
  .stamp a {{ color:#fff; }}
  .top {{ background:linear-gradient(160deg,#0d4f7d,#1677b8 60%,#4fb3e8); color:#fff; padding:40px 16px 34px; text-align:center; }}
  .top h1 {{ margin:0 0 6px; font-size:clamp(1.6rem,4vw,2.3rem); }}
  .top p {{ margin:4px auto; max-width:720px; color:#dff1ff; }}
  .routine {{ font-weight:700; letter-spacing:.5px; color:var(--sun) !important; }}
  .badges a {{ display:inline-block; margin:12px 4px 0; padding:5px 14px; border-radius:999px; background:var(--sun); color:#3a2a00;
    font-weight:700; text-decoration:none; font-size:.95rem; }}
  .badges a.alt {{ background:#ffffff26; color:#fff; border:1px solid #ffffff60; }}
  main {{ max-width:1040px; margin:0 auto; padding:16px 16px 80px; }}
  nav.toc {{ display:flex; flex-wrap:wrap; gap:6px 18px; justify-content:center; margin:18px 0 6px; font-size:.95rem; }}
  h2 {{ margin-top:48px; padding-bottom:6px; border-bottom:3px solid var(--sea); font-size:1.5rem; }}
  .lede {{ color:var(--soft); margin-top:4px; }}
  .overview {{ display:grid; grid-template-columns:repeat(auto-fill,minmax(180px,1fr)); gap:10px; }}
  .ov {{ display:block; background:var(--panel); border:1px solid var(--line); border-left:6px solid var(--later); border-radius:10px;
    padding:8px 10px; color:var(--ink); text-decoration:none; font-size:.95rem; }}
  .ov small {{ float:right; color:var(--soft); }}
  .ov.shipped {{ border-left-color:var(--ok); }} .ov.going {{ border-left-color:var(--go); }}
  .ov.dropped {{ border-left-color:var(--no); color:var(--soft); text-decoration:line-through; }}
  .ov.dropped b {{ color:var(--no); }}
  .bar {{ height:8px; background:var(--line); border-radius:99px; overflow:hidden; margin-top:6px; }}
  .bar span {{ display:block; height:100%; background:var(--ok); }}
  .count {{ font-size:.8rem; color:var(--soft); }}
  .chapter {{ background:var(--panel); border:1px solid var(--line); border-left:8px solid var(--later); border-radius:14px; padding:14px 20px 16px; margin:18px 0; }}
  .chapter.shipped {{ border-left-color:var(--ok); }} .chapter.going {{ border-left-color:var(--go); }}
  .chapter.dropped {{ border-left-color:var(--no); opacity:.75; }} .chapter.dropped h3 {{ text-decoration:line-through; }}
  .chapter.dropped .num {{ background:var(--no); }} .pill.dropped {{ background:var(--no); }}
  .chapter header {{ display:flex; flex-wrap:wrap; align-items:center; gap:8px 12px; }}
  .chapter h3 {{ margin:0; font-size:1.3rem; }}
  .num {{ display:inline-grid; place-items:center; width:34px; height:34px; border-radius:50%; background:var(--sea); color:#fff; font-weight:700; }}
  .pill {{ font-size:.78rem; font-weight:700; padding:2px 10px; border-radius:99px; color:#fff; background:var(--later); }}
  .pill.shipped {{ background:var(--ok); }} .pill.going {{ background:var(--go); }}
  .rel {{ color:var(--soft); font-size:.9rem; }}
  dl {{ display:grid; grid-template-columns:max-content 1fr; gap:2px 14px; margin:12px 0; }}
  dt {{ font-weight:700; color:var(--soft); }} dd {{ margin:0; }}
  .pics {{ display:grid; grid-template-columns:repeat(auto-fill,minmax(200px,1fr)); gap:10px; margin:10px 0; }}
  figure {{ margin:0; }} figure img {{ width:100%; border-radius:8px; display:block; border:1px solid var(--line); }}
  figcaption {{ font-size:.82rem; color:var(--soft); margin-top:3px; }}
  .progress {{ display:flex; align-items:center; gap:10px; }} .progress .bar {{ flex:1; margin:0; }}
  ul.checks {{ list-style:none; padding:0; margin:10px 0 0; columns:2 300px; }}
  ul.checks li {{ padding:2px 0 2px 28px; position:relative; break-inside:avoid; }}
  ul.checks li::before {{ position:absolute; left:0; top:2px; width:20px; height:20px; border-radius:5px; text-align:center; line-height:20px;
    font-size:.8rem; font-weight:700; }}
  ul.checks li.yes::before {{ content:"\\2713"; background:var(--ok); color:#fff; }}
  ul.checks li.no::before {{ content:""; border:2px solid var(--later); }}
  ul.checks li.yes {{ color:var(--soft); }}
  .board {{ display:grid; grid-template-columns:repeat(auto-fill,minmax(230px,1fr)); gap:14px; }}
  .panel {{ background:var(--panel); border:1px solid var(--line); border-radius:12px; padding:10px; font-size:.9rem; }}
  .panel p {{ margin:6px 0 0; }} .panel .pn {{ font-weight:700; color:var(--sea); }} .panel .dad {{ color:var(--soft); font-style:italic; }}
  .panel .art {{ display:grid; gap:6px; }}
  .panel.dropped {{ opacity:.55; }} .panel.dropped .pn {{ color:var(--no); }}
  .sketch {{ aspect-ratio:16/9; display:grid; place-items:center; border:2px dashed var(--line); border-radius:8px; color:var(--soft); font-size:.85rem; }}
  .tablewrap {{ overflow-x:auto; }}
  table {{ border-collapse:collapse; width:100%; font-size:.92rem; }}
  th, td {{ border:1px solid var(--line); padding:6px 9px; text-align:left; vertical-align:top; }}
  th {{ background:var(--panel); }}
  td.v {{ font-weight:600; white-space:nowrap; }}
  td.kid {{ color:var(--ok); }} td.dad {{ color:var(--sea); }} td.robot {{ color:var(--later); }}
  footer {{ text-align:center; color:var(--soft); font-size:.85rem; margin-top:50px; }}
</style>
</head>
<body>
<div class="top">
  <h1>{title}</h1>
  <p>“{tagline}”</p>
  <p class="routine">{routine}</p>
  <p class="stamp">{built}</p>
  <div class="badges"><a href="../">▶ Play in the browser</a>{apk}<a class="alt" href="{repo}">GitHub</a></div>
</div>
<main>
<nav class="toc"><a href="#where">Where we are</a><a href="#part1">Part 1: Packing</a><a href="#part2">Part 2: The trip</a>
<a href="#storyboard">Storyboard</a><a href="#voices">Voices</a><a href="media/">Media</a><a href="#characters">Characters</a><a href="#how">How we work</a></nav>

<h2 id="where">Where we are</h2>
<p class="lede">Every chapter's checklist, at a glance. Ticks come straight from the repo, so they update on every deploy.</p>
<div class="overview">{overview}</div>

{parts}

<h2 id="storyboard">Storyboard</h2>
<p class="lede">The 19 panels of the packing-video storyboard (v0.2). Keyframes are provisional; dashed boxes still need one.</p>
<div class="board">{panels}</div>

<h2 id="voices">Voices</h2>
{voices}

<h2 id="characters">Characters</h2>
<p class="lede">Character Sheets v0.4 win every argument: Becca's eyes are brown; Jack-Jack's hair is golden sandy dirty-blonde, no copper or orange.</p>
<div class="pics">{characters}</div>

<h2 id="how">How we work</h2>
<div class="tablewrap"><table>
<tr><th>Role</th><th>Who</th><th>Owns</th></tr>
<tr><td>Director</td><td>Ryan with Claude</td><td>Story, chapter plans, priorities, approvals</td></tr>
<tr><td>Developer</td><td>Claude Code</td><td>Game code, tests, import tools, builds, releases, this page</td></tr>
<tr><td>Designer</td><td>ChatGPT</td><td>Characters, rooms, props, cards, UI art</td></tr>
<tr><td>Video</td><td>Gemini (and Runway tests)</td><td>Short clips with the kids</td></tr>
</table></div>
<p>Every chapter follows the same loop: <b>video intro, play, video payoff</b>. Clips are 8-15 seconds and always skippable. Play needs no reading,
has no failure states, Becca's version is always easier, and the sibling is always the helper.
The full spec is <a href="{repo}/blob/main/docs/cruise-adventure-game-spec.md">cruise-adventure-game-spec.md</a>.</p>
<p><b>How work ships:</b> features are built on a version branch; at each checkpoint (tests green, code review fixed) the tablet gets a playtest build and the work merges to main, which updates the browser game and this page. Official versions are tagged only with Ryan's OK.
Details: <a href="{repo}/blob/main/docs/deployment.md">deployment.md</a> · <a href="{repo}/releases">all builds</a>.</p>

<footer>{built} · source: <a href="{repo}/blob/main/docs/site/story.json">docs/site/story.json</a></footer>
</main>
</body>
</html>
"""

CHARACTERS = [("character-sheets", "Character Sheets v0.4"), ("game-jack-cheer", "Jack-Jack in the game"),
              ("game-becca-cheer", "Becca in the game"), ("game-jack-card", "Jack-Jack's card"), ("game-becca-card", "Becca's card")]


# ---------------------------------------------------------------------------------------------
# Media page: every image, clip, voice line and sound, grouped by chapter, with its status.
# The functions below are pure (data in, rows out) so tests can pin each rule.
# ---------------------------------------------------------------------------------------------
PACKING = "Packing (1-3)"
SHARED = "Shared"
CHAPTER_NAMES = {7: "7 To the car", 8: "8 The airport", 9: "9 The flight", 10: "10 Hello Florida", 11: "11 Welcome aboard",
                 12: "12 Island days", 13: "13 Sea day", 14: "14 Beach hotel"}
CHAPTER_ORDER = [PACKING] + [CHAPTER_NAMES[n] for n in range(7, 15)] + [SHARED]
FOLDER_CHAPTER = {"backgrounds": PACKING, "props": PACKING, "cards": PACKING, "characters": PACKING,
                  "car": CHAPTER_NAMES[7], "airport": CHAPTER_NAMES[8], "flight": CHAPTER_NAMES[9], "florida": CHAPTER_NAMES[10],
                  "aboard": CHAPTER_NAMES[11], "island": CHAPTER_NAMES[12], "seaday": CHAPTER_NAMES[13], "beach": CHAPTER_NAMES[14]}
SFX_FUNCTION_CHAPTER = {"florida": 10, "aboard": 11, "flight": 9, "seaday": 13, "beach": 14, "island": 12}
ART_ROUND = {CHAPTER_NAMES[9]: "Art Round 7", CHAPTER_NAMES[10]: "Art Round 7", CHAPTER_NAMES[11]: "Art Round 8",
             CHAPTER_NAMES[13]: "Art Round 8", CHAPTER_NAMES[12]: "Art Round 9", CHAPTER_NAMES[14]: "Art Round 9",
             CHAPTER_NAMES[7]: "Art Round 5", CHAPTER_NAMES[8]: "Art Round 6"}
NEW_CHAPTERS = {CHAPTER_NAMES[n] for n in range(9, 15)}
TRUNK_LINES = {"load-car", "turn-it", "try-another-spot", "it-fits", "close-trunk", "lets-go"}
AIRPORT_LINES = {"tag-bags", "needs-tag", "on-the-belt", "bye-suitcases", "in-a-tray", "tablet-tray", "push-it", "comes-back",
                 "walk-through", "get-your-things", "find-gate", "match-airplane", "this-way", "not-this-one", "found-gate"}
VOICE_PREFIX_CHAPTER = {"sea-": 13, "isle-": 12, "beach-": 14}
NON_IMAGE = ("sfx", "music", "video", "voice")


def chapter_for_asset(game: str, spec: str = "") -> str:
    """'assets/<folder>/x.png' (or its spec file, for stills) -> the chapter group it belongs to."""
    parts = game.split("/")
    folder = parts[1] if len(parts) > 2 else ""
    if folder == "stills" and spec:
        m = re.search(r"data/chapters/([a-z]+)/", spec)
        if m and m[1] in FOLDER_CHAPTER:
            return FOLDER_CHAPTER[m[1]]
    return FOLDER_CHAPTER.get(folder, SHARED)


def art_round(chapter: str) -> str:
    return ART_ROUND.get(chapter, "Art Rounds 1-4")


def image_status(entry: dict) -> str:
    if entry.get("approved"):
        return "approved"
    return "placeholder" if entry.get("generator") == "placeholder" else "provisional"


def image_rows(manifest: list[dict]) -> list[dict]:
    rows = []
    for m in manifest:
        if m.get("generator") in NON_IMAGE:
            continue
        chapter = chapter_for_asset(m["game"], m.get("spec", ""))
        status = image_status(m)
        rows.append({"name": m["game"].removeprefix("assets/"), "chapter": chapter, "status": status,
                     "round": art_round(chapter), "done": status == "approved"})
    return rows


def clip_chapters(chapters: list[dict]) -> dict[str, tuple[str, list[str]]]:
    """Clip file name -> (chapter group, kids) for every clip chapters.json lists. {kid} and {row} are expanded."""
    out: dict[str, str] = {}
    for ch in chapters:
        if ch.get("dropped"):
            continue
        n = ch["number"]
        group = PACKING if n <= 3 else CHAPTER_NAMES.get(n, SHARED)
        for seg in ch.get("segments", []):
            if seg.get("kind") != "clip":
                continue
            names = [seg["name"]]
            if "{kid}" in seg["name"]:
                names = [seg["name"].replace("{kid}", k) for k in ("jack", "becca")]
            expanded = []
            for nm in names:
                if "{row}" in nm:
                    expanded += [nm.replace("{row}", str(r + 1)) for r in ch.get("rows", [])]
                else:
                    expanded.append(nm)
            for nm in expanded:
                out[nm] = group
    return out


def video_round(chapter: str) -> str:
    return "Video Round 4" if chapter in NEW_CHAPTERS else "Video Rounds 2-3"


def video_rows(chapters: list[dict], manifest: list[dict], present: set[str]) -> list[dict]:
    """Clips named in chapters.json or delivered; present = clip names that have an .ogv file."""
    listed = clip_chapters(chapters)
    approved = {Path(m["game"]).stem: bool(m.get("approved")) for m in manifest if m.get("generator") == "video"}
    names = dict(listed)
    for nm in list(approved) + sorted(present):
        if nm not in names:
            names[nm] = PACKING if nm.endswith("-done") else CHAPTER_NAMES[7] if nm.startswith("car-") else SHARED
    rows = []
    for nm, chapter in names.items():
        if nm not in present:
            status = "missing (still shown instead)"
        elif approved.get(nm):
            status = "approved"
        else:
            status = "delivered"
        rows.append({"name": nm + ".ogv", "chapter": chapter, "status": status, "round": video_round(chapter),
                     "done": status == "approved"})
    return rows


def voice_chapter(line_id: str, referenced: dict[str, str]) -> str:
    if line_id in referenced:
        return referenced[line_id]
    for prefix, n in VOICE_PREFIX_CHAPTER.items():
        if line_id.startswith(prefix):
            return CHAPTER_NAMES[n]
    if line_id in TRUNK_LINES:
        return CHAPTER_NAMES[7]
    if line_id in AIRPORT_LINES:
        return CHAPTER_NAMES[8]
    return PACKING


def voice_round(line_id: str, chapter: str) -> str:
    if chapter in NEW_CHAPTERS or chapter == CHAPTER_NAMES[8] or line_id == "next-stop":
        return "Voice Lines v1.0"
    return "Voice Lines v0.4" if chapter == CHAPTER_NAMES[7] else "Voice Lines v0.3"


VOICE_LABEL = {"robot": "computer", "dad": "grown-up", "kid": "kid recording"}


def voice_rows(table: list[dict], referenced: dict[str, str]) -> list[dict]:
    """One row per line; it is done when both kids' voices are kid recordings."""
    rows = []
    for r in table:
        chapter = voice_chapter(r["id"], referenced)
        status = " / ".join(f"{KIDS[k]}: {VOICE_LABEL[r[k]]}" for k in KIDS)
        rows.append({"name": r["id"], "chapter": chapter, "status": status, "round": voice_round(r["id"], chapter),
                     "done": all(r[k] == "kid" for k in KIDS), "text": r["jack_text"]})
    return rows


def sfx_function_chapters(make_sfx_source: str) -> dict[str, str]:
    """Sound name -> chapter group, from the *_sounds() function in tools/make_sfx.py that makes it."""
    out, current = {}, None
    for line in make_sfx_source.splitlines():
        m = re.match(r"def (\w+)\(", line)
        if m:
            fn = m[1]
            if fn == "sounds":
                current = CHAPTER_NAMES[8]
            elif fn.endswith("_sounds") and fn[:-7] in SFX_FUNCTION_CHAPTER:
                current = CHAPTER_NAMES[SFX_FUNCTION_CHAPTER[fn[:-7]]]
            else:
                current = None
            continue
        k = re.match(r'\s+"([a-z0-9-]+)":', line)
        if k and current:
            out[k[1]] = current
    return out


def music_chapter(name: str) -> str:
    for folder, group in FOLDER_CHAPTER.items():
        if name == folder or name.startswith(folder + "-"):
            return group
    return SHARED


def audio_rows(manifest: list[dict], sfx_chapters: dict[str, str]) -> list[dict]:
    rows = []
    for m in manifest:
        gen = m.get("generator")
        if gen not in ("sfx", "music") and not (m["game"].startswith(("assets/sfx/", "assets/music/")) and gen == "copy"):
            continue
        name = Path(m["game"]).stem
        music = m["game"].startswith("assets/music/")
        chapter = music_chapter(name) if music else sfx_chapters.get(name, SHARED)
        final = gen == "copy"
        rows.append({"name": ("music/" if music else "sfx/") + name + ".ogg", "chapter": chapter,
                     "status": "final" if final else "synthesized stand-in", "round": "synthesized (no round)" if not final else "recorded",
                     "done": final})
    return rows


def media_summary(*row_lists: list[dict]) -> list[tuple[int, int]]:
    return [(sum(1 for r in rows if r["done"]), len(rows)) for rows in row_lists]


def _referenced_voice_ids(root: Path) -> dict[str, str]:
    """Voice line id -> chapter group, for ids named in a chapter's data files (data/chapters/<folder>/*.json)."""
    ids = {l["id"] for l in _json(root, "data/voice_lines.json") or []}
    out: dict[str, str] = {}
    base = root / "data" / "chapters"
    if not base.is_dir():
        return out
    for folder in sorted(p for p in base.iterdir() if p.is_dir() and p.name in FOLDER_CHAPTER):
        for f in sorted(folder.glob("*.json")):
            if f.name == "art.json":
                continue
            for lid in re.findall(r'"([a-z0-9-]+)"', f.read_text()):
                if lid in ids:
                    out.setdefault(lid, FOLDER_CHAPTER[folder.name])
    return out


def _media_table(rows: list[dict], voice: bool = False) -> str:
    out = ""
    for chapter in CHAPTER_ORDER:
        group = [r for r in rows if r["chapter"] == chapter]
        if not group:
            continue
        done = sum(1 for r in group if r["done"])
        out += f'<h3>{e(chapter)} <span class="count">{done} of {len(group)}</span></h3><div class="tablewrap"><table class="media"><thead><tr><th>{"Line" if voice else "File"}</th>'
        out += ("<th>Words</th>" if voice else "") + "<th>Status</th><th>Request</th></tr></thead><tbody>"
        for r in group:
            cls = "done" if r["done"] else "todo"
            key = "".join(c if c.isalnum() else "-" for c in r["status"].split(" ")[0].split(":")[0])
            out += (f'<tr class="{cls}"><td><code>{e(r["name"])}</code></td>' + (f'<td>{e(r.get("text", ""))}</td>' if voice else "")
                    + f'<td class="st {e(key)}">{e(r["status"])}</td><td>{e(r["round"])}</td></tr>')
        out += "</tbody></table></div>"
    return out


def render_media(root: Path) -> str:
    manifest = _json(root, "data/art_manifest.json") or []
    chapters = (_json(root, "data/chapters.json") or {}).get("chapters", [])
    vdir = root / "assets" / "video"
    present = {p.stem for p in vdir.glob("*.ogv")} if vdir.is_dir() else set()
    sfx_src = (root / "tools" / "make_sfx.py")
    sfx_map = sfx_function_chapters(sfx_src.read_text()) if sfx_src.exists() else {}
    images = image_rows(manifest)
    videos = video_rows(chapters, manifest, present)
    audio = audio_rows(manifest, sfx_map) + voice_rows(voice_table(root), _referenced_voice_ids(root))
    sound = audio_rows(manifest, sfx_map)
    voices = voice_rows(voice_table(root), _referenced_voice_ids(root))
    (di, ti), (dv, tv), (da, ta) = media_summary(images, videos, sound + voices)
    summary = "".join(
        f'<div class="ov {"shipped" if d == t and t else "going" if d else ""}"><b>{label}</b><small>{d} of {t}</small>{_progress(d, t)}</div>'
        for label, d, t in (("Images", di, ti), ("Video", dv, tv), ("Audio", da, ta)))
    css = TEMPLATE[TEMPLATE.index("<style>") + 7:TEMPLATE.index("</style>")].replace("{{", "{").replace("}}", "}")
    built = updated_stamp(*_newest_commit(root))
    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Media - Jack-Jack and Becca's Cruise Adventure</title>
<style>{css}
  .media td.st {{ font-weight:600; white-space:nowrap; }} .media tr.done td.st {{ color:var(--ok); }} .media tr.todo td.st {{ color:var(--later); }}
  body.only-needed tr.done {{ display:none; }} .toggle {{ margin:16px 0; font-weight:600; }}
  h3 {{ margin:26px 0 6px; }} h3 .count {{ font-weight:400; }}
</style></head>
<body>
<div class="top"><h1>Media</h1><p>Every picture, clip, voice line and sound, and what is still needed.</p><p class="stamp">{built}</p>
<div class="badges"><a href="../">&#9654; Play in the browser</a><a class="alt" href="../docs/">Project page</a></div></div>
<main>
<nav class="toc"><a href="#images">Images</a><a href="#video">Video</a><a href="#sounds">Sounds and music</a><a href="#voices">Voice lines</a></nav>
<div class="overview">{summary}</div>
<p class="lede">Done means approved art, an approved clip, a voice recorded by the kid, or a final sound. The page is generated on every deploy.</p>
<label class="toggle"><input type="checkbox" id="needed"> Still needed only</label>
<h2 id="images">Images</h2>{_media_table(images)}
<h2 id="video">Video</h2>{_media_table(videos)}
<h2 id="sounds">Sounds and music</h2>{_media_table(sound)}
<h2 id="voices">Voice lines</h2>{_media_table(voices, voice=True)}
<footer>{built}</footer>
</main>
<script>document.getElementById("needed").addEventListener("change",function(){{document.body.classList.toggle("only-needed",this.checked);}});</script>
</body></html>
"""


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    out = Path(sys.argv[1])
    story = json.loads((SITE / "story.json").read_text())
    page = render(story, ROOT, os.environ.get("LATEST_RELEASE", ""))
    out.mkdir(parents=True, exist_ok=True)
    (out / "index.html").write_text(page, encoding="utf-8")
    shutil.copytree(SITE / "img", out / "img", dirs_exist_ok=True)
    (out / "media").mkdir(exist_ok=True)
    (out / "media" / "index.html").write_text(render_media(ROOT), encoding="utf-8")
    print("wrote", out / "index.html")


if __name__ == "__main__":
    main()
