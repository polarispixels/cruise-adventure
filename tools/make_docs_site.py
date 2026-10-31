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
import shutil
import sys
from pathlib import Path

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
    ticks = [(c, is_done(c, root)) for c in ch.get("checks", [])]
    done = sum(1 for _, d in ticks if d)
    cls, label = _status(done, len(ticks))
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
    return f"""<div class="panel"><div class="art">{art}</div>
  <p class="pn">Panel {e(p['n'])} · Ch {p['chapter']}</p><p>{e(p['picture'])}</p><p class="dad">Dad: “{e(p['dad'])}”</p></div>"""


VOICE_NAMES = {"kid": "recorded", "dad": "Dad (shared)", "robot": "robot"}


def _voices(root: Path) -> str:
    rows = voice_table(root)
    counts = {kid: sum(1 for r in rows if r[kid] != "robot") for kid in KIDS}
    body = ""
    for r in rows:
        cells = "".join(f'<td class="v {r[k]}">{VOICE_NAMES[r[k]]}</td>' for k in ("becca", "jack"))
        text = r["jack_text"] if r["jack_text"] == r["becca_text"] else f'{r["becca_text"]} / {r["jack_text"]}'
        body += f"<tr><td><code>{e(r['id'])}</code></td><td>{e(text)}</td>{cells}</tr>"
    return f"""
<p>The helper sibling does the talking, so <b>Becca's voice plays in Jack-Jack's game</b> and <b>Jack-Jack's voice plays in Becca's game</b>.
Real voices so far: Becca's side {counts['becca']} of {len(rows)}, Jack-Jack's side {counts['jack']} of {len(rows)}.
“Dad (shared)” is one grown-up take used for both kids until a kid records their own.</p>
<div class="tablewrap"><table class="voices"><thead><tr><th>Line</th><th>Words (Becca says / Jack-Jack says)</th>
<th>Becca's voice<br><small>in Jack-Jack's game</small></th><th>Jack-Jack's voice<br><small>in Becca's game</small></th></tr></thead>
<tbody>{body}</tbody></table></div>"""


def _version(root: Path) -> str:
    m = re.search(r'config/version="([^"]+)"', (root / "project.godot").read_text()) if (root / "project.godot").exists() else None
    return m.group(1) if m else "?"


def render(story: dict, root: Path) -> str:
    chapters = story.get("chapters", [])
    parts_html = ""
    for i, part in enumerate(story.get("parts", [])):
        chs = "".join(_chapter(c, root) for c in chapters if c.get("part") == i)
        parts_html += f'<h2 id="part{i + 1}">{e(part["name"])}</h2><p class="lede">{e(part["blurb"])}</p>{chs}'
    if not story.get("parts"):
        parts_html = "".join(_chapter(c, root) for c in chapters)
    overview = ""
    for c in chapters:
        ticks = [is_done(k, root) for k in c.get("checks", [])]
        cls, _ = _status(sum(ticks), len(ticks))
        overview += (f'<a class="ov {cls}" href="#ch{c["number"]}"><b>{c["number"]}</b> {e(c["title"])}'
                     f'<small>{e(c.get("release", ""))}</small>{_progress(sum(ticks), len(ticks))}</a>')
    panels = "".join(_panel(p) for p in story.get("panels", []))
    routine = " → ".join(e(s) for s in story.get("routine", []))
    stamp = datetime.date.today().isoformat()
    sha = os.environ.get("GITHUB_SHA", "")[:7]
    built = f"Built {stamp}" + (f' from <a href="{REPO}/commit/{sha}">{sha}</a>' if sha else "")
    return TEMPLATE.format(
        title=e(story.get("title", "")), tagline=e(story.get("tagline", "")), routine=routine,
        version=e(_version(root)), repo=REPO, overview=overview, parts=parts_html, panels=panels,
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
    --sun:#ffc23d; --ok:#2f9e57; --go:#e58a17; --later:#9aa9b6; --pink:#e5679a; }}
  @media (prefers-color-scheme: dark) {{ :root {{ --bg:#0f1b26; --panel:#162636; --ink:#e6eef5; --soft:#9fb3c4; --line:#27405a;
    --sea:#5bb3f0; --deep:#0b2c46; }} }}
  * {{ box-sizing:border-box; }}
  body {{ margin:0; background:var(--bg); color:var(--ink); font:16px/1.6 -apple-system,"Segoe UI",Roboto,Helvetica,Arial,sans-serif; }}
  a {{ color:var(--sea); }}
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
  .bar {{ height:8px; background:var(--line); border-radius:99px; overflow:hidden; margin-top:6px; }}
  .bar span {{ display:block; height:100%; background:var(--ok); }}
  .count {{ font-size:.8rem; color:var(--soft); }}
  .chapter {{ background:var(--panel); border:1px solid var(--line); border-left:8px solid var(--later); border-radius:14px; padding:14px 20px 16px; margin:18px 0; }}
  .chapter.shipped {{ border-left-color:var(--ok); }} .chapter.going {{ border-left-color:var(--go); }}
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
  <div class="badges"><a href="../">▶ Play in the browser</a><a class="alt" href="{repo}/releases/latest">Tablet APK (v{version})</a><a class="alt" href="{repo}">GitHub</a></div>
</div>
<main>
<nav class="toc"><a href="#where">Where we are</a><a href="#part1">Part 1: Packing</a><a href="#part2">Part 2: The trip</a>
<a href="#storyboard">Storyboard</a><a href="#voices">Voices</a><a href="#characters">Characters</a><a href="#how">How we work</a></nav>

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
<p class="lede">Character Sheets v0.4 win every argument: Becca's eyes are brown; Jack-Jack's hair is sandy light brown.</p>
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

<footer>{built} · source: <a href="{repo}/blob/main/docs/site/story.json">docs/site/story.json</a></footer>
</main>
</body>
</html>
"""

CHARACTERS = [("character-sheets", "Character Sheets v0.4"), ("game-jack-cheer", "Jack-Jack in the game"),
              ("game-becca-cheer", "Becca in the game"), ("game-jack-card", "Jack-Jack's card"), ("game-becca-card", "Becca's card")]


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    out = Path(sys.argv[1])
    story = json.loads((SITE / "story.json").read_text())
    page = render(story, ROOT)
    out.mkdir(parents=True, exist_ok=True)
    (out / "index.html").write_text(page, encoding="utf-8")
    shutil.copytree(SITE / "img", out / "img", dirs_exist_ok=True)
    print("wrote", out / "index.html")


if __name__ == "__main__":
    main()
