"""Package only screenshots listed in each completed portrait QA manifest."""
import lib.session
from pathlib import Path
import json
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SHOTS = ROOT / "screenshots"

HTML = r'''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Business COMB · Portrait review</title><style>*{box-sizing:border-box}body{margin:0;background:#f5f5ef;color:#171917;font:14px system-ui}header{padding:24px;background:#d4ff33;position:sticky;top:0;z-index:2}h1{font-size:24px;margin:0 0 8px}p{line-height:1.5;margin:6px 0}nav{display:flex;gap:8px;flex-wrap:wrap;margin-top:16px}button,input{font:inherit;border:1px solid #bbb;border-radius:9px;background:white;padding:9px 12px}button{cursor:pointer}button.active{background:#171917;color:white;border-color:#171917}input{min-width:200px;flex:1;max-width:420px}main{padding:24px;max-width:1450px;margin:auto}.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(230px,1fr));gap:20px}figure{margin:0;border-bottom:1px solid #ccc;padding-bottom:12px}figure img{width:100%;height:340px;object-fit:contain;object-position:top;background:white;cursor:zoom-in}figcaption{padding-top:10px;font-weight:600;line-height:1.4}small{color:#5e6256}#count{margin-bottom:20px}dialog{border:0;border-radius:12px;max-width:96vw;max-height:96vh;padding:14px}dialog::backdrop{background:#000b}dialog img{display:block;max-width:90vw;max-height:82vh;object-fit:contain}dialog .bar{display:flex;align-items:center;justify-content:space-between;gap:12px;margin-bottom:12px}a{color:inherit}</style><header><h1>Business COMB · __GROUP__ portrait photos</h1><p>From registration and login through drawer, billing, staff, expenses, reports, receipts and dialogs.</p><small>Actual Flutter widgets with Android fonts and local test data. Portrait only. These are widget renders, not Samsung device screenshots; native gallery, camera, print and share sheets need a real device.</small><nav id="profiles"></nav><nav><input id="search" placeholder="Find a screen or flow…" aria-label="Find a screen"></nav></header><main><p id="count"></p><div class="grid" id="grid"></div></main><dialog id="preview"><div class="bar"><strong id="title"></strong><a id="original" target="_blank">Original PNG</a><button id="close" aria-label="Close preview">Close</button></div><img id="full" alt=""></dialog><script>const profiles=__DATA__;let selected=0;const label=s=>s.replace(/^d+_/,'').replaceAll('_',' ').replace(/w/g,c=>c.toUpperCase());const nav=document.querySelector('#profiles'),grid=document.querySelector('#grid'),search=document.querySelector('#search'),dialog=document.querySelector('#preview');profiles.forEach((p,i)=>{const b=document.createElement('button');b.textContent=p.name.replaceAll('_',' ')+' · '+p.width+' × '+p.height+' dp';b.onclick=()=>{selected=i;render()};nav.append(b)});function render(){[...nav.children].forEach((b,i)=>b.classList.toggle('active',i===selected));const p=profiles[selected],rows=p.captures.filter(r=>label(r.screen).toLowerCase().includes(search.value.toLowerCase()));document.querySelector('#count').textContent=rows.length+' photos · '+p.issues.length+' captured layout/runtime issues · tap an image to enlarge';grid.replaceChildren(...rows.map((r,i)=>{const fig=document.createElement('figure'),img=document.createElement('img'),cap=document.createElement('figcaption');img.src=p.name+'/'+r.file;img.alt=label(r.screen);img.loading='lazy';cap.textContent=r.file.slice(0,3)+' · '+img.alt;img.onclick=()=>{document.querySelector('#full').src=img.src;document.querySelector('#full').alt=img.alt;document.querySelector('#title').textContent=img.alt;document.querySelector('#original').href=img.src;dialog.showModal()};fig.append(img,cap);return fig}));}search.oninput=render;document.querySelector('#close').onclick=()=>dialog.close();dialog.onclick=e=>{if(e.target===dialog)dialog.close()};render();</script></html>'''

summary = []
for group in ("tablet", "mobile"):
    destination = SHOTS / f"{group}_photos"
    destination.mkdir(parents=True, exist_ok=True)
    profiles = []
    for manifest in sorted((SHOTS / f"{group}_review").glob("*/coverage.json")):
        data = json.loads(manifest.read_text(encoding="utf-8"))
        name = manifest.parent.name
        target = destination / name
        target.mkdir(parents=True, exist_ok=True)
        for capture in data["captures"]:
            shutil.copy2(manifest.parent / capture["file"], target / capture["file"])
        shutil.copy2(manifest, target / "coverage.json")
        first = data["captures"][0]
        profiles.append({"name": name, "width": first["logicalWidth"], "height": first["logicalHeight"], **data})
        summary.append({"group": group, "profile": name, "photos": len(data["captures"]), "issues": data["issues"]})
    (destination / "index.html").write_text(HTML.replace("__GROUP__", group.title()).replace("__DATA__", json.dumps(profiles)), encoding="utf-8")
    (destination / "README.md").write_text(
        f"# {group.title()} portrait photos\n\nOpen index.html in a browser. Each profile has original PNGs and coverage.json.\n\n"
        "These are Android-styled Flutter widget renders with isolated local test data, not captures from a physical tablet. "
        "System status/navigation bars are excluded, but their safe-area insets are exercised. Passwords are obscured. "
        "No live shop data was modified. Landscape is excluded.\n\n"
        "Read ../../docs/portrait_qa_notes.md for known issues and unverified native flows.\n", encoding="utf-8")
    with zipfile.ZipFile(SHOTS / f"{group}_portrait_photos.zip", "w", zipfile.ZIP_DEFLATED) as archive:
        for name in ("index.html", "README.md"):
            archive.write(destination / name, name)
        for profile in profiles:
            archive.write(destination / profile["name"] / "coverage.json", f"{profile['name']}/coverage.json")
            for capture in profile["captures"]:
                relative = Path(profile["name"]) / capture["file"]
                archive.write(destination / relative, relative)

(SHOTS / "portrait_summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
print(json.dumps(summary, indent=2))
