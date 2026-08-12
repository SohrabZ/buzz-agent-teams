#!/usr/bin/env python3
"""Generate hive-vs-swarm.{light,dark}.svg from one geometry definition.

Standalone SVGs: every colour is literal, so they render correctly on GitHub,
in an <img>, or anywhere outside a themed host.

Layout mirrors the two topologies in Block's article:
  Hive  — you talk to each agent directly; each keeps its own memory slice.
  Swarm — you talk to one coordinator, which fans work out and absorbs
          escalation; only new edge cases come back to you.
"""
import pathlib

OUT = pathlib.Path(__file__).parent
W, H = 680, 556

THEMES = {
    "light": dict(
        text="#2C2C2A", muted="#5F5E5A", faint="#888780", line="#888780", dash="#B4B2A9",
        memfill="#FFFFFF", memstroke="#D3D1C7",
        purple=("#EEEDFE", "#7F77DD", "#3C3489", "#534AB7"),
        teal=("#E1F5EE", "#1D9E75", "#085041", "#0F6E56"),
        coral=("#FAECE7", "#D85A30", "#712B13", "#993C1D"),
        gray=("#F1EFE8", "#888780", "#2C2C2A", "#5F5E5A"),
    ),
    "dark": dict(
        text="#D3D1C7", muted="#B4B2A9", faint="#888780", line="#888780", dash="#5F5E5A",
        memfill="#2C2C2A", memstroke="#5F5E5A",
        purple=("#26215C", "#7F77DD", "#CECBF6", "#AFA9EC"),
        teal=("#04342C", "#1D9E75", "#9FE1CB", "#5DCAA5"),
        coral=("#4A1B0C", "#D85A30", "#F5C4B3", "#F0997B"),
        gray=("#2C2C2A", "#888780", "#D3D1C7", "#B4B2A9"),
    ),
}

HEADERS = [
    (40, 26, "YOU"), (200, 26, "YOUR HIVE TEAM"), (420, 26, "WHAT EACH ONE REMEMBERS"),
    (40, 272, "YOU"), (200, 272, "COORDINATOR"), (430, 272, "SWARM"),
]

# x, y, w, h, ramp, title, subtitle, meta
NODES = [
    (40, 108, 110, 58, "gray", "You", "ask directly", None),
    (200, 40, 180, 58, "purple", "Mason", "reviews and judges", "SmartBee · Opus 5"),
    (200, 108, 180, 58, "teal", "Thistle", "designs and builds", "WorkerBee · Sonnet 5"),
    (200, 176, 180, 58, "coral", "Pollen", "runs the legwork", "QuickBee · Haiku 4.5"),
    (40, 330, 110, 58, "gray", "You", "set the goal", None),
    (200, 330, 180, 58, "purple", "Comet", "decides, never migrates", "SmartBee · Opus 5"),
    (430, 296, 210, 58, "teal", "1–10 × Clover", "parallel migrators", "WorkerBee · Sonnet 5"),
    (430, 382, 210, 58, "coral", "1 × Willow", "independent verifier", "QuickBee · Haiku 4.5"),
]

# x, y, w, h, title, subtitle
MEMORY = [
    (420, 40, 220, 58, "Your review bar", "what you always send back"),
    (420, 108, 220, 58, "How you work", "conventions and patterns"),
    (420, 176, 220, 58, "The boring facts", "build commands, test flags"),
    (200, 428, 180, 48, "Coordinator memory", "rulings, written down"),
]

SOLID = [
    "M150 137 L200 69", "M150 137 L200 137", "M150 137 L200 205",   # you -> each agent
    "M150 348 L200 348",                                            # you -> coordinator
    "M380 344 L430 325", "M380 374 L430 411",                       # coordinator -> swarm
]
DASHED_HEAD = [
    "M200 372 L150 372",                                            # new edge cases -> you
    "M430 340 L406 359 L380 359",                                   # workers escalate
]
DASHED_PLAIN = ["M430 396 L406 359"]                                # verifier escalates
BIDIR = [
    "M384 69 L416 69", "M384 137 L416 137", "M384 205 L416 205",    # agent <-> memory
    "M290 392 L290 424",                                            # coordinator <-> memory
]

LEGEND = [
    [(40, "purple", "SmartBee"), (130, "teal", "WorkerBee"), (226, "coral", "QuickBee")],
]


def svg(name):
    c = THEMES[name]
    p = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
         f'viewBox="0 0 {W} {H}" role="img">',
         "<title>Hive and Swarm team topologies</title>",
         "<desc>Two diagrams. Top, the Hive: a person on the left talks directly to three "
         "agents — Mason a SmartBee who reviews and judges, Thistle a WorkerBee who designs "
         "and builds, and Pollen a QuickBee who runs the legwork. Each agent reads and writes "
         "its own slice of memory about the person. Bottom, the Swarm: the person sets a goal "
         "with a single coordinator, which fans work out to a pool of migrators and an "
         "independent verifier. Those escalate back to the coordinator, which writes each "
         "ruling to memory and forwards only new edge cases to the person.</desc>",
         f'<style>text{{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Helvetica,Arial,sans-serif}}'
         f'.t{{font-size:14px;font-weight:600;fill:{c["text"]}}}'
         f'.s{{font-size:12px;fill:{c["muted"]}}}'
         f'.h{{font-size:11px;font-weight:600;fill:{c["faint"]};letter-spacing:0.08em}}</style>',
         f'<defs><marker id="a" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" '
         f'markerHeight="6" orient="auto-start-reverse"><path d="M2 1L8 5L2 9" fill="none" '
         f'stroke="{c["line"]}" stroke-width="1.5" stroke-linecap="round" '
         f'stroke-linejoin="round"/></marker></defs>']

    for x, y, label in HEADERS:
        p.append(f'<text class="h" x="{x}" y="{y}">{label}</text>')
    for d in SOLID:
        p.append(f'<path d="{d}" fill="none" stroke="{c["line"]}" stroke-width="1.5" '
                 f'marker-end="url(#a)"/>')
    for d in DASHED_HEAD:
        p.append(f'<path d="{d}" fill="none" stroke="{c["line"]}" stroke-width="1.5" '
                 f'stroke-dasharray="4 3" marker-end="url(#a)"/>')
    for d in DASHED_PLAIN:
        p.append(f'<path d="{d}" fill="none" stroke="{c["line"]}" stroke-width="1.5" '
                 f'stroke-dasharray="4 3"/>')
    for d in BIDIR:
        p.append(f'<path d="{d}" fill="none" stroke="{c["line"]}" stroke-width="1.5" '
                 f'marker-end="url(#a)" marker-start="url(#a)"/>')

    for x, y, w, h, ramp, title, sub, meta in NODES:
        fill, stroke, tc, sc = c[ramp]
        cx = x + w // 2
        p.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="4" fill="{fill}" '
                 f'stroke="{stroke}" stroke-width="0.5"/>')
        if meta:
            rows = [(title, 18, "t", tc), (sub, 34, "s", sc), (meta, 50, "s", sc)]
        else:
            rows = [(title, 26, "t", tc), (sub, 43, "s", sc)]
        for txt, dy, cls, col in rows:
            p.append(f'<text class="{cls}" x="{cx}" y="{y + dy}" text-anchor="middle" '
                     f'fill="{col}">{txt}</text>')

    for x, y, w, h, title, sub in MEMORY:
        cx = x + w // 2
        p.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="4" fill="{c["memfill"]}" '
                 f'stroke="{c["memstroke"]}" stroke-width="0.5" stroke-dasharray="5 4"/>')
        p.append(f'<text class="t" x="{cx}" y="{y + (24 if h > 50 else 20)}" '
                 f'text-anchor="middle">{title}</text>')
        p.append(f'<text class="s" x="{cx}" y="{y + (42 if h > 50 else 37)}" '
                 f'text-anchor="middle">{sub}</text>')

    for x, ramp, label in LEGEND[0]:
        fill, stroke, _, _ = c[ramp]
        p.append(f'<rect x="{x}" y="{H - 58}" width="12" height="12" rx="2" fill="{fill}" '
                 f'stroke="{stroke}" stroke-width="0.5"/>')
        p.append(f'<text class="s" x="{x + 18}" y="{H - 48}">{label}</text>')
    p.append(f'<rect x="330" y="{H - 58}" width="12" height="12" rx="2" fill="{c["memfill"]}" '
             f'stroke="{c["memstroke"]}" stroke-width="0.5" stroke-dasharray="3 2"/>')
    p.append(f'<text class="s" x="348" y="{H - 48}">persona memory</text>')
    p.append(f'<path d="M40 {H - 26} L60 {H - 26}" fill="none" stroke="{c["line"]}" '
             f'stroke-width="1.5" marker-end="url(#a)"/>')
    p.append(f'<text class="s" x="68" y="{H - 22}">work</text>')
    p.append(f'<path d="M130 {H - 26} L150 {H - 26}" fill="none" stroke="{c["line"]}" '
             f'stroke-width="1.5" stroke-dasharray="4 3" marker-end="url(#a)"/>')
    p.append(f'<text class="s" x="158" y="{H - 22}">escalation — stops at the coordinator</text>')
    p.append("</svg>")
    return "\n".join(p) + "\n"


for n in THEMES:
    f = OUT / f"hive-vs-swarm.{n}.svg"
    f.write_text(svg(n))
    print("wrote", f.name, f.stat().st_size, "bytes")
