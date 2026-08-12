#!/usr/bin/env python3
"""Generate hive-vs-swarm.{light,dark}.svg from one geometry definition.

Standalone SVGs: all colours are literal, so they render correctly on GitHub,
in an <img>, or anywhere else outside a themed host.
"""
import pathlib

OUT = pathlib.Path(__file__).parent

THEMES = {
    "light": dict(
        text="#2C2C2A", muted="#5F5E5A", line="#888780", dash="#B4B2A9",
        boxfill="#FFFFFF", boxstroke="#D3D1C7",
        purple=("#EEEDFE", "#7F77DD", "#3C3489", "#534AB7"),
        teal=("#E1F5EE", "#1D9E75", "#085041", "#0F6E56"),
        coral=("#FAECE7", "#D85A30", "#712B13", "#993C1D"),
        gray=("#F1EFE8", "#888780", "#2C2C2A", "#5F5E5A"),
    ),
    "dark": dict(
        text="#D3D1C7", muted="#B4B2A9", line="#888780", dash="#5F5E5A",
        boxfill="#2C2C2A", boxstroke="#5F5E5A",
        purple=("#26215C", "#7F77DD", "#CECBF6", "#AFA9EC"),
        teal=("#04342C", "#1D9E75", "#9FE1CB", "#5DCAA5"),
        coral=("#4A1B0C", "#D85A30", "#F5C4B3", "#F0997B"),
        gray=("#2C2C2A", "#888780", "#D3D1C7", "#B4B2A9"),
    ),
}

# (x, y, w, h, ramp, title, subtitle)
NODES = [
    (130, 40, 100, 34, "gray", "You", None),
    (110, 140, 140, 48, "purple", "Mason", "never implements"),
    (54, 224, 116, 44, "teal", "Thistle", "implements"),
    (190, 224, 116, 44, "teal", "Bramble", "implements"),
    (450, 40, 100, 34, "gray", "You", None),
    (430, 140, 140, 48, "purple", "Comet", "owns the rulebook"),
    (430, 216, 140, 44, "teal", "Clover", "does the work"),
    (430, 288, 140, 44, "coral", "Willow", "verifies batches"),
]

REGIONS = [(40, 96, 280, 250, "Hive · permanent"), (360, 96, 280, 250, "Swarm · temporary")]

SOLID = [
    ("M180 188 L180 206 L112 206 L112 224", True),
    ("M180 188 L180 206 L248 206 L248 224", True),
    ("M500 188 L500 216", True),
    ("M500 260 L500 288", True),
]
DASHED = [
    ("M112 268 L112 284 L248 284 L248 268", False),
    ("M180 284 L180 296", False),
    ("M570 310 L610 310 L610 164 L570 164", True),
]
BIDIR = [("M180 74 L180 136"), ("M500 74 L500 136")]

LEGEND = [(40, "purple", "SmartBee"), (130, "teal", "WorkerBee"), (226, "coral", "QuickBee")]


def svg(theme_name):
    c = THEMES[theme_name]
    p = [
        '<svg xmlns="http://www.w3.org/2000/svg" width="680" height="406" '
        'viewBox="0 0 680 406" role="img">',
        "<title>Hive versus Swarm team shapes</title>",
        "<desc>Side by side. The Hive is a permanent team: you talk to Mason, who assigns "
        "work to Thistle and Bramble, and those two verify each other. The Swarm is a "
        "temporary team: you talk to Comet, who assigns batches to Clover, whose work goes "
        "to Willow for verification, and the verdict returns to Comet.</desc>",
        f'<style>text{{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Helvetica,Arial,sans-serif}}'
        f'.t{{font-size:14px;font-weight:500;fill:{c["text"]}}}'
        f'.s{{font-size:12px;fill:{c["muted"]}}}</style>',
        f'<defs><marker id="a" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" '
        f'markerHeight="6" orient="auto-start-reverse"><path d="M2 1L8 5L2 9" fill="none" '
        f'stroke="{c["line"]}" stroke-width="1.5" stroke-linecap="round" '
        f'stroke-linejoin="round"/></marker></defs>',
    ]
    for x, y, w, h, label in REGIONS:
        p.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="8" fill="none" '
                 f'stroke="{c["dash"]}" stroke-width="0.5" stroke-dasharray="5 4"/>')
        p.append(f'<text class="s" x="{x + 14}" y="{y + 20}">{label}</text>')
    for d, head in SOLID:
        p.append(f'<path d="{d}" fill="none" stroke="{c["line"]}" stroke-width="1.5"'
                 + (' marker-end="url(#a)"' if head else "") + "/>")
    for d, head in DASHED:
        p.append(f'<path d="{d}" fill="none" stroke="{c["line"]}" stroke-width="1.5" '
                 f'stroke-dasharray="4 3"' + (' marker-end="url(#a)"' if head else "") + "/>")
    for d in BIDIR:
        p.append(f'<path d="{d}" fill="none" stroke="{c["line"]}" stroke-width="1.5" '
                 f'marker-end="url(#a)" marker-start="url(#a)"/>')
    for x, y, w, h, ramp, title, sub in NODES:
        fill, stroke, tc, sc = c[ramp]
        cx = x + w // 2
        p.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="4" fill="{fill}" '
                 f'stroke="{stroke}" stroke-width="0.5"/>')
        if sub:
            p.append(f'<text class="t" x="{cx}" y="{y + 20}" text-anchor="middle" '
                     f'fill="{tc}">{title}</text>')
            p.append(f'<text class="s" x="{cx}" y="{y + 36}" text-anchor="middle" '
                     f'fill="{sc}">{sub}</text>')
        else:
            p.append(f'<text class="t" x="{cx}" y="{y + 22}" text-anchor="middle" '
                     f'fill="{tc}">{title}</text>')
    p.append(f'<rect x="110" y="296" width="140" height="26" rx="4" fill="{c["boxfill"]}" '
             f'stroke="{c["boxstroke"]}" stroke-width="0.5"/>')
    p.append('<text class="s" x="180" y="313" text-anchor="middle">verify each other</text>')
    for x, ramp, label in LEGEND:
        fill, stroke, _, _ = c[ramp]
        p.append(f'<rect x="{x}" y="370" width="12" height="12" rx="2" fill="{fill}" '
                 f'stroke="{stroke}" stroke-width="0.5"/>')
        p.append(f'<text class="s" x="{x + 18}" y="380">{label}</text>')
    p.append(f'<path d="M316 376 L336 376" fill="none" stroke="{c["line"]}" '
             f'stroke-width="1.5" stroke-dasharray="4 3"/>')
    p.append('<text class="s" x="344" y="380">verification path</text>')
    p.append("</svg>")
    return "\n".join(p) + "\n"


for name in THEMES:
    path = OUT / f"hive-vs-swarm.{name}.svg"
    path.write_text(svg(name))
    print("wrote", path.name, path.stat().st_size, "bytes")
