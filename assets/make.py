"""Writes the README figures, each in a light and a dark palette.

Run from the repository root: python3 assets/make.py
"""

from html import escape
from pathlib import Path

LIGHT = dict(
    text="#1f2328", muted="#59636e", faint="#8c959f", card="#f6f8fa", line="#d0d7de",
    accent="#8250df", accent_soft="#f5f0ff", green="#1a7f37", green_soft="#ecfdf0",
    orange="#bc4c00", orange_soft="#fff4e8", blue="#0969da", blue_soft="#eef6ff",
    shadow="#1f2328", shadow_opacity="0.10",
)
DARK = dict(
    text="#e6edf3", muted="#9198a1", faint="#6e7681", card="#161b22", line="#30363d",
    accent="#b58cff", accent_soft="#221a38", green="#3fb950", green_soft="#12261a",
    orange="#f0883e", orange_soft="#2b1d12", blue="#58a6ff", blue_soft="#0f2136",
    shadow="#000000", shadow_opacity="0.55",
)

SANS = "-apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif"
MONO = "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"


def svg(p, width, height, label, body):
    markers = "".join(
        f'<marker id="arrow-{name}" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" '
        f'markerHeight="7" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="{p[name]}"/></marker>'
        for name in ("muted", "accent", "green", "orange", "blue")
    )
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" width="{width}" '
        f'height="{height}" role="img" aria-label="{escape(label)}"><style>'
        f"text {{ font-family: {SANS}; fill: {p['text']}; }}"
        f".mono {{ font-family: {MONO}; white-space: pre; }}"
        f".muted {{ fill: {p['muted']}; }} .faint {{ fill: {p['faint']}; }}"
        f".accent {{ fill: {p['accent']}; }} .green {{ fill: {p['green']}; }}"
        f".orange {{ fill: {p['orange']}; }} .blue {{ fill: {p['blue']}; }}"
        ".flow { stroke-dasharray: 6 8; animation: flow 1.1s linear infinite; }"
        "@keyframes flow { to { stroke-dashoffset: -28; } }"
        ".pulse { animation: pulse 2.2s ease-in-out infinite; }"
        "@keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.35; } }"
        "@media (prefers-reduced-motion: reduce) { .flow, .pulse { animation: none; } }"
        f"</style><defs>{markers}"
        f'<filter id="lift" x="-5%" y="-5%" width="110%" height="125%"><feDropShadow dx="0" dy="2" '
        f'stdDeviation="3" flood-color="{p["shadow"]}" flood-opacity="{p["shadow_opacity"]}"/></filter>'
        f'<linearGradient id="glow" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="{p["accent"]}"/>'
        f'<stop offset="1" stop-color="{p["blue"]}"/></linearGradient>'
        f"</defs>{body}</svg>"
    )


def box(x, y, w, h, fill, stroke, rx=12, dash=None, width=1, lift=False):
    dashed = f' stroke-dasharray="{dash}"' if dash else ""
    lifted = ' filter="url(#lift)"' if lift else ""
    return (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" '
            f'stroke="{stroke}" stroke-width="{width}"{dashed}{lifted}/>')


def text(x, y, content, size=13, cls="", weight=None, anchor="start", raw=False, fill=None):
    attrs = f' class="{cls}"' if cls else ""
    attrs += f' style="fill:{fill}"' if fill else ""
    attrs += f' font-weight="{weight}"' if weight else ""
    attrs += f' text-anchor="{anchor}"' if anchor != "start" else ""
    body = content if raw else escape(content)
    return f'<text x="{x}" y="{y}" font-size="{size}" xml:space="preserve"{attrs}>{body}</text>'


def span(content, cls):
    return f'<tspan class="{cls}">{escape(content)}</tspan>'


def arrow(p, x1, y1, x2, y2, color="muted", flow=False, width=1.6):
    cls = ' class="flow"' if flow else ""
    return (f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{p[color]}" '
            f'stroke-width="{width}" marker-end="url(#arrow-{color})"{cls}/>')


def curve(p, d, color="muted", flow=False, width=1.6):
    cls = ' class="flow"' if flow else ""
    return (f'<path d="{d}" fill="none" stroke="{p[color]}" stroke-width="{width}" '
            f'marker-end="url(#arrow-{color})"{cls}/>')


def logo(p):
    body = (
        box(6, 6, 108, 108, p["card"], p["text"], rx=26, width=3)
        + f'<polyline points="34,38 18,60 34,82" fill="none" stroke="{p["text"]}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>'
        + f'<polyline points="86,38 102,60 86,82" fill="none" stroke="{p["text"]}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>'
        + box(42, 44, 36, 32, "none", p["muted"], rx=9, dash="5 4", width=2.2)
        + f'<rect x="48" y="50" width="24" height="20" rx="6" fill="{p["accent"]}" class="pulse"/>'
    )
    return svg(p, 120, 120, "Melact: a template with a hole in it", body)


def overview(p):
    def chips(x, y, width, labels, tone):
        out, cx, cy = "", x, y
        for label in labels:
            w = int(len(label) * 7.6) + 24
            if cx + w > x + width:
                cx, cy = x, cy + 38
            fill = {"gone": p["card"], "stays": p["accent_soft"]}[tone]
            stroke = {"gone": p["line"], "stays": p["accent"]}[tone]
            out += box(cx, cy, w, 28, fill, stroke, rx=14, width=1.2)
            out += text(cx + w / 2, cy + 19, label, size=12, cls="muted" if tone == "gone" else "accent",
                        weight=600, anchor="middle")
            if tone == "gone":
                out += f'<line x1="{cx + 12}" y1="{cy + 15}" x2="{cx + w - 12}" y2="{cy + 15}" stroke="{p["orange"]}" stroke-width="1.6"/>'
            cx += w + 10
        return out

    def step(x, y, n, title):
        return (f'<circle cx="{x + 11}" cy="{y - 5}" r="11" fill="{p["accent"]}"/>'
                + text(x + 11, y, n, size=12, weight=700, anchor="middle", fill="#ffffff")
                + text(x + 30, y, title, size=14.5, weight=600))

    body = step(0, 24, "1", "Your reason-react app") + step(305, 24, "2", "melact-ppx, at build time") + step(610, 24, "3", "In the browser")

    body += box(0, 40, 270, 158, p["card"], p["line"], lift=True)
    code = [
        [("let[@react.component] make () =", "")],
        [("  let n, set =", "")],
        [("    React.useState (fun () -> 0) in", "")],
        [("  <button onClick=", ""), ("(fun _ ->", "accent")],
        [("      set (fun n -> n + 1))", "accent"), (">", "")],
        [("    ", ""), ("(React.int n)", "accent")],
        [("  </button>", "")],
    ]
    for i, parts in enumerate(code):
        line = "".join(span(t, c) if c else escape(t) for t, c in parts)
        body += text(12, 68 + i * 19, line, size=11.2, cls="mono", raw=True)

    body += box(0, 208, 270, 92, p["card"], p["line"], lift=True)
    body += text(12, 228, "dune: the whole migration", size=11.5, cls="muted", weight=600)
    for i, (line, cls) in enumerate([("- (libraries reason-react)", "orange"), ("+ (libraries melact)", "green"),
                                     ("- (pps reason-react-ppx)", "orange"), ("+ (pps melact-ppx)", "green")]):
        body += text(12, 248 + i * 15, line, size=11.2, cls=f"mono {cls}")

    body += box(305, 40, 270, 120, p["accent_soft"], p["accent"], dash="4 4")
    body += text(321, 62, "template · parsed once", size=12, cls="accent", weight=700)
    tpl = escape("<button>") + span("●", "accent") + escape("</button>")
    body += text(321, 92, tpl, size=13, cls="mono", raw=True)
    body += text(321, 118, "static markup: cloned per mount,", size=12, cls="muted")
    body += text(321, 136, "never rebuilt, never compared", size=12, cls="muted")
    body += text(321, 152, "+ hole paths: Handler [] · Text [] @0", size=10.5, cls="mono faint")

    body += box(305, 172, 270, 128, p["blue_soft"], p["blue"], lift=True)
    body += text(321, 194, "refresh · all a render runs", size=12, cls="blue", weight=700)
    for i, (label, value) in enumerate([("check n", "=== once"), ("put HText", "if n changed")]):
        y = 208 + i * 34
        body += box(321, y, 238, 26, p["card"], p["line"], rx=8)
        body += text(333, y + 18, label, size=12, cls="mono blue", weight=600)
        body += text(549, y + 18, value, size=11.5, cls="muted", anchor="end")
    body += text(321, 290, "generated per template, like Svelte", size=12, cls="muted")

    body += box(610, 40, 270, 260, p["card"], p["line"], lift=True)
    flow = [("setState", "orange"), ("only this component renders", "line"),
            ("n: === once", "accent"), ("text.data = \"1\"", "green")]
    for i, (label, tone) in enumerate(flow):
        y = 56 + i * 61
        fill = {"orange": p["orange_soft"], "line": p["card"], "accent": p["accent_soft"], "green": p["green_soft"]}[tone]
        stroke = {"orange": p["orange"], "line": p["line"], "accent": p["accent"], "green": p["green"]}[tone]
        body += box(626, y, 238, 40, fill, stroke, rx=10, width=1.4)
        body += text(745, y + 25, label, size=13, weight=600, anchor="middle",
                     cls="mono green" if tone == "green" else ("mono accent" if tone == "accent" else ""))
        if i < len(flow) - 1:
            body += arrow(p, 745, y + 42, 745, y + 57, "accent", width=1.4)
    body += text(745, 296, "the handler is swapped, not diffed", size=11, cls="faint", anchor="middle")

    body += arrow(p, 273, 170, 301, 170, "accent", flow=True)
    body += arrow(p, 578, 170, 606, 170, "accent", flow=True)

    body += box(0, 326, 430, 124, p["card"], p["line"], rx=14)
    body += text(18, 352, "Gone", size=14.5, weight=700)
    body += text(62, 352, "from the bundle and from every render", size=12.5, cls="muted")
    body += chips(18, 366, 400, ["React", "react-dom", "virtual DOM", "a tree per render",
                                 "tree diff", "fiber"], "gone")
    body += box(450, 326, 430, 124, p["accent_soft"], p["accent"], rx=14)
    body += text(468, 352, "Stays", size=14.5, weight=700)
    body += text(512, 352, "your code compiles unchanged", size=12.5, cls="muted")
    body += chips(468, 366, 400, ["your components", "hooks", "mlx · Reason · OCaml",
                                  "ReactDOM", "ReactEvent"], "stays")
    return svg(p, 880, 452, "Melact in one picture: a reason-react component in mlx switches two dune lines; melact-ppx splits its JSX into a template parsed once and a hole array built per render; in the browser a setState re-renders only that component, compares each hole with === and writes only what changed. Gone: React, react-dom, the virtual DOM, the element tree per render, the tree diff, fiber. Stays: your components, hooks, JSX, ReactDOM.Client, ReactEvent", body)


def pipeline(p):
    body = ""
    heads = [(0, "1 · You write JSX in mlx"), (290, "2 · melact-ppx hoists a template"), (650, "3 · The DOM")]
    for x, title in heads:
        body += text(x + 2, 22, title, size=14, weight=600)

    body += box(0, 40, 230, 236, p["card"], p["line"], lift=True)
    jsx = [
        [("<div className=\"counter\">", "")],
        [("  <button onClick=", ""), ("dec", "accent"), (">", "")],
        [("    (React.string \"-\")", "")],
        [("  </button>", "")],
        [("  <output className=", ""), ("tone", "accent"), (">", "")],
        [("    ", ""), ("(React.int count)", "accent")],
        [("  </output>", "")],
        [("</div>", "")],
    ]
    for i, parts in enumerate(jsx):
        line = "".join(span(t, c) if c else escape(t) for t, c in parts)
        body += text(14, 74 + i * 22, line, size=12, cls="mono", raw=True)
    body += text(14, 262, "purple: dynamic, everything else static", size=11.5, cls="muted")

    body += box(290, 40, 300, 118, p["accent_soft"], p["accent"], dash="4 4")
    body += text(306, 62, "once, at module level", size=11.5, cls="accent", weight=600)
    html = [
        [("<div class=\"counter\">", "")],
        [(" <button>-</button>", "")],
        [(" <output", ""), (" ●", "accent"), (">", ""), ("●", "accent"), ("</output>", "")],
        [("</div>", "")],
    ]
    for i, parts in enumerate(html):
        line = "".join(span(t, c) if c else escape(t) for t, c in parts)
        body += text(306, 84 + i * 18, line, size=12, cls="mono", raw=True)
    body += text(486, 84, "holes", size=11.5, cls="muted")
    for i, hole in enumerate(["Handler [0]", "Attr [1] class", "Text [1] @0"]):
        body += text(486, 102 + i * 16, hole, size=10.5, cls="mono accent")

    body += box(290, 172, 300, 104, p["card"], p["line"])
    body += text(306, 194, "every render: the compiled refresh", size=11.5, cls="blue", weight=600)
    for i, line in enumerate(["check count; check tone", "if tone: put class", "if count: put text"]):
        body += text(306, 216 + i * 18, line, size=12, cls="mono")
    body += text(500, 234, "others:", size=11.5, cls="muted")
    body += text(500, 250, "not evaluated", size=11.5, cls="muted")

    body += box(650, 40, 230, 236, p["card"], p["line"], lift=True)
    tree = [
        (664, 76, "div.counter", ""),
        (680, 106, "button", "click → dec"),
        (696, 130, "\"-\"", ""),
        (680, 166, "output", "class=\"warm\""),
        (696, 196, "\"42\"", "text node"),
    ]
    for x, y, node, hole in tree:
        body += text(x, y, node, size=12.5, cls="mono")
        if hole:
            body += box(774, y - 14, 96, 20, p["accent_soft"], p["accent"], rx=10)
            body += text(822, y, hole, size=10.5, cls="accent", anchor="middle")
    body += f'<path d="M670,82 V166 M670,106 H676 M670,166 H676 M686,112 V130 M686,130 H692 M686,172 V196 M686,196 H692" fill="none" stroke="{p["line"]}" stroke-width="1.4"/>'
    body += text(664, 236, "3 holes bound by path,", size=11.5, cls="muted")
    body += text(664, 254, "the rest is never touched", size=11.5, cls="muted")

    body += arrow(p, 234, 140, 284, 140, "accent", flow=True)
    body += text(259, 124, "ppx", size=11, cls="muted", anchor="middle")
    body += arrow(p, 594, 98, 644, 98, "accent", flow=True)
    body += text(619, 84, "clone", size=11, cls="muted", anchor="middle")
    body += arrow(p, 594, 224, 644, 224, "blue", flow=True)
    body += text(619, 210, "patch", size=11, cls="muted", anchor="middle")
    return svg(p, 880, 280, "mlx JSX is compiled by melact-ppx into a template hoisted to module level, with three holes; each render builds only an array of three hole values; the template is cloned once per mount and the hole array patches the clone", body)


def patch(p):
    columns = [(16, "hole"), (190, "render 41"), (340, "render 42"), (500, "compared"), (630, "DOM work")]
    body = "".join(text(x, 22, c, size=12, cls="muted", weight=600) for x, c in columns)
    rows = [
        ("HHandler", "onClick", "fun#1", "fun#2", "never", "muted", "property swapped, 0 DOM calls", "blue", None),
        ("HAttr", "class", "\"warm\"", "\"warm\"", "=== ✓", "green", "skipped", "green", None),
        ("HText", "count", "\"41\"", "\"42\"", "!==", "orange", "text.data = \"42\"", "orange", "pulse"),
        ("HChild", "list", "rows #7", "rows #7", "=== ✓", "green", "whole subtree skipped", "green", None),
    ]
    for i, (kind, what, old, new, compared, ccls, work, wcls, anim) in enumerate(rows):
        y = 36 + i * 54
        changed = ccls == "orange"
        body += box(0, y, 880, 44, p["orange_soft"] if changed else p["card"], p["orange"] if changed else p["line"], rx=10)
        body += text(16, y + 27, kind, size=13, cls="mono", weight=600)
        body += text(96, y + 27, what, size=12, cls="muted")
        for x, value in ((190, old), (340, new)):
            body += box(x, y + 10, 118, 24, "none", p["line"], rx=6)
            body += text(x + 59, y + 27, value, size=12, cls="mono", anchor="middle")
        body += arrow(p, 312, y + 22, 334, y + 22, "muted", width=1.2)
        body += text(500, y + 27, compared, size=13, cls=f"mono {ccls}", weight=600)
        body += text(630, y + 27, work, size=12.5, cls=f"{wcls}{' pulse' if anim else ''}", weight=600 if changed else None)
    body += text(0, 268, "One patch: a template identity check, then one === per hole. Static markup is not in the array, so it is never compared.", size=12, cls="muted")
    return svg(p, 880, 276, "Patching compares hole values with ===: the handler is swapped without DOM calls, the unchanged class and the unchanged child list are skipped, only the changed text is written", body)


def reconcile(p):
    old = ["a", "b", "c", "d", "e", "f"]
    new = ["a", "e", "c", "d", "b", "f"]
    kind = {"a": "muted", "f": "muted", "c": "green", "d": "green", "b": "accent", "e": "accent"}
    x0, step, top, bottom = 70, 80, 52, 196

    def chip(x, y, key):
        color = kind[key]
        fill = {"muted": p["card"], "green": p["green_soft"], "accent": p["accent_soft"]}[color]
        stroke = {"muted": p["line"], "green": p["green"], "accent": p["accent"]}[color]
        return box(x - 26, y, 52, 34, fill, stroke, rx=8, width=1.4) + text(x, y + 22, key, size=14, cls="mono", weight=600, anchor="middle")

    body = text(0, 74, "old", size=12, cls="muted", weight=600) + text(0, 218, "new", size=12, cls="muted", weight=600)
    for i, key in enumerate(old):
        j = new.index(key)
        x1, x2 = x0 + i * step, x0 + j * step
        color = {"muted": "muted", "green": "green", "accent": "accent"}[kind[key]]
        if i == j:
            body += arrow(p, x1, top + 36, x2, bottom - 4, color)
        else:
            body += curve(p, f"M{x1},{top + 36} C{x1},{top + 90} {x2},{bottom - 60} {x2},{bottom - 4}", color, flow=True, width=2)
    for i, key in enumerate(old):
        body += chip(x0 + i * step, top, key)
    for j, key in enumerate(new):
        body += chip(x0 + j * step, bottom, key)

    legend = [
        ("muted", "common prefix and suffix: patched in place"),
        ("green", "longest increasing run of old positions: stays"),
        ("accent", "everything else: one insertBefore each"),
    ]
    for i, (color, label) in enumerate(legend):
        y = 258 + i * 20
        body += f'<rect x="0" y="{y - 10}" width="14" height="10" rx="3" fill="{p[color]}"/>'
        body += text(22, y, label, size=12, cls="muted")

    body += box(540, 24, 340, 300, p["card"], p["line"], rx=14)
    body += text(560, 52, "Measured in test/view (jsdom), 1,000 rows", size=12.5, cls="muted", weight=600)
    numbers = [
        ("swap rows 1 and 998", "2 moves"),
        ("reverse all", "999 moves"),
        ("remove one row", "999 rows kept"),
        ("append 1,000", "1,000 kept"),
        ("update every 10th", "every node kept"),
        ("replace all keys", "1,000 new"),
    ]
    for i, (op, result) in enumerate(numbers):
        y = 92 + i * 38
        body += text(560, y, op, size=13)
        body += text(860, y, result, size=13, cls="accent", weight=700, anchor="end")
        if i < len(numbers) - 1:
            body += f'<line x1="560" y1="{y + 15}" x2="860" y2="{y + 15}" stroke="{p["line"]}"/>'
    return svg(p, 880, 326, "Keyed reconcile: the common prefix a and suffix f stay, c and d form the longest increasing run of old positions and stay, b and e are moved with one insertBefore each. Measured on 1,000 rows: swap 2 moves, reverse 999 moves, remove one keeps 999 rows", body)


def events(p):
    nodes = [("document", 60, "1 listener per event type"), ("div", 108, "$$mehole:click = outer"), ("ul", 156, None),
             ("li", 204, None), ("button", 252, "$$mehole:click = inner")]
    body = ""
    for name, y, note in nodes:
        handler = note and note.startswith("$$")
        body += box(150, y - 22, 120, 32, p["accent_soft"] if handler else p["card"], p["accent"] if handler else p["line"], rx=8, width=1.4)
        body += text(210, y - 1, name, size=13, cls="mono", weight=600, anchor="middle")
        if note:
            body += text(370, y - 1, note, size=11.5, cls="mono accent" if handler else "muted")
    body += curve(p, "M146,236 C96,200 96,80 146,48", "muted", flow=True)
    body += text(18, 146, "native", size=11.5, cls="muted")
    body += text(18, 162, "bubbling", size=11.5, cls="muted")
    body += curve(p, "M274,240 C336,200 336,130 274,96", "accent", flow=True, width=2)
    body += text(326, 172, "walk", size=11.5, cls="accent", weight=600)
    body += f'<circle cx="152" cy="246" r="6" fill="{p["orange"]}" class="pulse"/>'
    body += text(118, 276, "click", size=11.5, cls="orange", weight=600)
    body += text(150, 26, "Melact walks from the target up, calling each $$mehole:click; stopPropagation ends the walk", size=12, cls="muted")

    body += box(560, 40, 320, 236, p["card"], p["line"], rx=14)
    body += text(580, 68, "Replacing a handler", size=14, weight=600)
    body += text(580, 92, "el[\"$$mehole:click\"] = next", size=12, cls="mono accent")
    body += text(580, 114, "0 addEventListener, 0 setAttribute", size=12, cls="muted")
    body += text(580, 150, "Non-bubbling events", size=14, weight=600)
    body += text(580, 174, "scroll, focus, load …", size=12, cls="muted")
    body += text(580, 196, "one listener on the element,", size=12, cls="muted")
    body += text(580, 214, "removed on unmount", size=12, cls="muted")
    body += text(580, 250, "Delegated: click, input, keydown,", size=12, cls="muted")
    body += text(580, 268, "pointer*, mouse*, touch* … 22 types", size=12, cls="muted")
    return svg(p, 880, 296, "One listener per event type on the document; on a click melact walks from the target up through parent nodes and calls the handler stored on each element; replacing a handler is one property write", body)


def updates(p):
    body = ""
    nodes = {
        "App": (230, 64, "faint"), "Header": (110, 150, "faint"), "TodoList": (350, 150, "accent"),
        "Row a": (230, 240, "green"), "Row b": (350, 240, "accent"), "Row c": (470, 240, "green"),
    }
    edges = [("App", "Header"), ("App", "TodoList"), ("TodoList", "Row a"), ("TodoList", "Row b"), ("TodoList", "Row c")]
    for a, b in edges:
        (x1, y1, _), (x2, y2, _) = nodes[a], nodes[b]
        body += f'<line x1="{x1}" y1="{y1 + 18}" x2="{x2}" y2="{y2 - 18}" stroke="{p["line"]}" stroke-width="1.4"/>'
    for name, (x, y, tone) in nodes.items():
        fill = {"faint": p["card"], "accent": p["accent_soft"], "green": p["green_soft"]}[tone]
        stroke = {"faint": p["line"], "accent": p["accent"], "green": p["green"]}[tone]
        body += box(x - 50, y - 18, 100, 36, fill, stroke, rx=10, width=1.6 if tone != "faint" else 1, dash="4 3" if tone == "green" else None)
        body += text(x, y + 5, name, size=13, cls="faint" if tone == "faint" else "", weight=600, anchor="middle")
    body += f'<circle cx="400" cy="132" r="9" fill="{p["orange"]}" class="pulse"/>'
    body += text(414, 124, "setState", size=11.5, cls="orange", weight=600)
    body += text(230, 288, "every prop === → skipped", size=11, cls="green", anchor="middle")
    body += text(470, 288, "every prop === → skipped", size=11, cls="green", anchor="middle")
    body += text(350, 288, "props changed", size=11, cls="accent", anchor="middle")

    steps = [
        ("1", "The setter marks TodoList dirty", "nothing renders yet"),
        ("2", "One microtask flushes", "dirty instances, parents first"),
        ("3", "TodoList renders again", "App and Header are not visited"),
        ("4", "Each Row's props are compared", "one by one with === → equal ones are skipped"),
    ]
    for i, (n, head, note) in enumerate(steps):
        y = 54 + i * 60
        body += f'<circle cx="594" cy="{y - 5}" r="12" fill="{p["accent"]}"/>'
        body += text(594, y, n, size=12, weight=700, anchor="middle", fill="#ffffff")
        body += text(616, y, head, size=13.5, weight=600)
        body += text(616, y + 18, note, size=12, cls="muted")
    return svg(p, 880, 300, "A state update in TodoList re-renders TodoList only; App and Header are not visited; Rows whose props are physically equal are skipped", body)


def hooks(p):
    body = ""
    heads = [(0, "1", "Your component"), (300, "2", "melact-ppx: a key per call site"), (620, "3", "The instance's slots")]
    for x, n, title in heads:
        body += f'<circle cx="{x + 11}" cy="17" r="11" fill="{p["accent"]}"/>'
        body += text(x + 11, 22, n, size=12, weight=700, anchor="middle", fill="#ffffff")
        body += text(x + 30, 22, title, size=14.5, weight=600)

    body += box(0, 40, 270, 168, p["card"], p["line"], lift=True)
    code = [
        [("let[@react.component] make () =", "")],
        [("  let n, setN =", "")],
        [("    ", ""), ("React.useState", "accent"), (" (fun () -> 0) in", "")],
        [("  ", ""), ("React.useEffect1", "blue"), (" (fun () ->", "")],
        [("      Js.log n; None)", "")],
        [("    [| n |];", "")],
        [("  <b>(React.int n)</b>", "")],
    ]
    for i, parts in enumerate(code):
        line = "".join(span(t, c) if c else escape(t) for t, c in parts)
        body += text(14, 68 + i * 19, line, size=11.5, cls="mono", raw=True)

    keys = [
        (60, "accent", "accent_soft", "k1", "(int, int -> int) state key"),
        (138, "blue", "blue_soft", "k2", "int array effect_cell key"),
    ]
    for y, color, soft, name, typ in keys:
        body += box(300, y, 290, 58, p[soft], p[color], rx=10, width=1.4, lift=True)
        body += text(316, y + 23, f"let {name} = Hook.key ()", size=12, cls=f"mono {color}", weight=600)
        body += text(316, y + 43, typ, size=11, cls="mono muted")
    body += text(300, 222, "hoisted once per module; the call becomes", size=11.5, cls="muted")
    body += text(300, 240, "React.useState k1 (fun () -> 0)", size=11.5, cls="mono accent")

    body += box(620, 40, 260, 168, p["card"], p["line"], lift=True)
    slots = [(64, "accent", "accent_soft", "k1", "{ value = 3 }"), (136, "blue", "blue_soft", "k2", "{ deps = [|3|] }")]
    for y, color, soft, name, value in slots:
        body += box(636, y, 52, 52, p[soft], p[color], rx=8, width=1.4)
        body += text(662, y + 31, name, size=13, cls=f"mono {color}", weight=700, anchor="middle")
        body += box(694, y, 170, 52, p["card"], p["line"], rx=8)
        body += text(779, y + 31, value, size=12, cls="mono", anchor="middle")
    body += text(636, 58, "slot 0", size=10.5, cls="faint")
    body += text(636, 130, "slot 1", size=10.5, cls="faint")

    for y, color in ((89, "accent"), (167, "blue")):
        body += arrow(p, 594, y, 630, y, color, flow=True, width=1.8)
    body += text(612, 80, "✓", size=12, cls="green", weight=700, anchor="middle")
    body += text(612, 158, "✓", size=12, cls="green", weight=700, anchor="middle")

    body += box(0, 262, 432, 72, p["green_soft"], p["green"], rx=12)
    body += text(18, 288, "Reading a slot: Type.Id.provably_equal k_slot k_call", size=12.5, cls="green", weight=700)
    body += text(18, 308, "Some Equal → the value comes back typed. No Obj.magic,", size=12, cls="muted")
    body += text(18, 325, "and one key used at two types does not compile.", size=12, cls="muted")
    body += box(448, 262, 432, 72, p["orange_soft"], p["orange"], rx=12)
    body += text(466, 288, "A hook behind an if: slot 1 holds k2, the call brings k3", size=12.5, cls="orange", weight=700)
    body += text(466, 308, "None → \"hooks were called in a different order\"", size=12, cls="muted")
    body += text(466, 325, "instead of a value of the wrong type.", size=12, cls="muted")
    return svg(p, 880, 338, "melact-ppx gives every hook call site its own Type.Id key, hoisted to module level; the instance stores each slot with the key that made it; reading a slot checks provably_equal, so values come back typed, and a hook called out of order raises an error instead of returning a wrong value", body)


def compat(p):
    body = box(0, 30, 262, 230, p["card"], p["line"], lift=True)
    body += text(18, 58, "reason-react/demo/main.re", size=13, cls="mono", weight=700)
    body += text(18, 78, "the demo in reason-react's own repo", size=11.5, cls="muted")
    used = ["useState, useReducer", "useReducerWithMapState", "useEffect1, useLayoutEffect1",
            "useRef + useEffect0", "React.Fragment with keys, <>…</>", "?ref, ->React.int, unused props"]
    for i, item in enumerate(used):
        y = 104 + i * 18
        body += f'<circle cx="24" cy="{y - 4}" r="2.5" fill="{p["accent"]}"/>'
        body += text(34, y, item, size=11.5)
    body += f'<line x1="18" y1="{214}" x2="244" y2="{214}" stroke="{p["line"]}"/>'
    body += text(18, 234, "- (pps reason-react-ppx)", size=11, cls="mono orange")
    body += text(18, 250, "+ (pps melact-ppx)", size=11, cls="mono green")
    preview = "<main><section><h3>Stateful</h3>…"
    lanes = [(40, "blue", "blue_soft", "React 18.3"), (150, "accent", "accent_soft", "Melact")]
    for y, color, soft, name in lanes:
        body += curve(p, f"M264,145 C290,145 290,{y + 34} 312,{y + 34}", color, flow=True, width=1.8)
        body += box(316, y, 300, 68, p[soft], p[color], rx=12, width=1.4, lift=True)
        body += text(334, y + 26, name, size=14, weight=700, cls=color)
        body += text(334, y + 48, preview, size=10.5, cls="mono muted")
        body += arrow(p, 618, y + 34, 652, y + 34, color, width=1.6)
    body += text(466, 136, "every button clicked 4 times, DOM read after each click", size=11.5, cls="muted", anchor="middle")
    body += box(656, 40, 220, 178, p["green_soft"], p["green"], rx=14, width=1.8, lift=True)
    body += text(766, 102, "33 / 33", size=40, cls="green", weight=800, anchor="middle")
    body += text(766, 130, "steps with identical DOM", size=13.5, weight=600, anchor="middle")
    body += text(766, 156, "1,311 characters at mount,", size=11.5, cls="muted", anchor="middle")
    body += text(766, 174, "the same after every click", size=11.5, cls="muted", anchor="middle")
    body += text(766, 204, "compat/run.sh", size=11.5, cls="mono green", anchor="middle")
    return svg(p, 880, 264, "reason-react's own demo, switched to melact with two dune lines, rendered by React 18.3 and by melact in jsdom: after mounting and after each of 32 clicks, 33 of 33 steps have identical DOM", body)



def vdom(p):
    body = text(0, 20, "React", size=16, weight=800) + text(52, 20, "builds a virtual DOM every render", size=13.5, cls="muted")
    body += text(460, 20, "Melact", size=16, weight=800, cls="accent") + text(522, 20, "has no virtual DOM", size=13.5, cls="muted")
    body += f'<line x1="440" y1="0" x2="440" y2="392" stroke="{p["line"]}" stroke-dasharray="3 5"/>'

    nodes = [("div.counter", 0), ("button  onClick", 1), ("output  className", 1), ("button  onClick", 1), ("button  disabled", 1)]
    for column, (x, caption) in enumerate([(0, "tree of render 1"), (226, "tree of render 2: all new objects")]):
        body += text(x, 50, caption, size=11.5, cls="muted" if column == 0 else "orange", weight=600)
        for i, (label, indent) in enumerate(nodes):
            y = 62 + i * 34
            fill, stroke = (p["card"], p["line"]) if column == 0 else (p["orange_soft"], p["orange"])
            body += box(x + indent * 16, y, 188 - indent * 16, 26, fill, stroke, rx=7, width=1.2, lift=column == 1)
            body += text(x + indent * 16 + 10, y + 17, label, size=11, cls="mono")
            if column == 1:
                body += arrow(p, 192, y + 13, 222 + indent * 16, y + 13, "orange", width=1.2)
    body += text(207, 238, "diff", size=11, cls="orange", weight=700, anchor="middle")
    steps = [
        ("orange", "orange_soft", "5 elements + 5 props objects allocated"),
        ("orange", "orange_soft", "5 nodes walked, every prop compared"),
        ("green", "green_soft", "1 DOM write: the text \"2\""),
    ]
    for i, (color, soft, label) in enumerate(steps):
        y = 260 + i * 36
        body += box(0, y, 414, 28, p[soft], p[color], rx=14, width=1.2)
        body += text(16, y + 19, label, size=12.5, cls=color, weight=600)

    body += box(460, 36, 420, 150, p["card"], p["line"], rx=12, dash="4 4")
    body += text(476, 58, "template · parsed once, never rebuilt, never compared", size=11.5, cls="faint", weight=600)
    html = [
        [("<div class=\"counter\">", "")],
        [("  <button", ""), (" ●", "blue"), (">-</button>", "")],
        [("  <output", ""), (" ●", "green"), (">", ""), ("●", "orange"), ("</output>", "")],
        [("  <button", ""), (" ●", "blue"), (">+</button>", "")],
        [("  <button", ""), (" ●", "blue"), ("●", "green"), (">reset</button>", "")],
    ]
    for i, parts in enumerate(html):
        line = "".join(span(t, c) if c else escape(t) for t, c in parts)
        body += text(476, 82 + i * 20, line, size=12, cls="mono faint", raw=True)
    body += text(476, 178, "</div>", size=12, cls="mono faint")

    body += text(460, 212, "render 2 runs the compiled refresh: one === per local it reads", size=11.5, cls="accent", weight=600)
    cells = [("count", "1 → 2", "orange", "changed"), ("initial", "0 = 0", "green", "same"),
             ("tone", "\"\" = \"\"", "green", "same")]
    for i, (name, value, color, verdict) in enumerate(cells):
        x = 460 + i * 142
        soft = {"green": "green_soft", "orange": "orange_soft"}[color]
        body += box(x, 222, 134, 30, p[soft], p[color], rx=7, width=1.4, lift=color == "orange")
        body += text(x + 10, 242, name, size=12, cls="mono", weight=700)
        body += text(x + 124, 242, value, size=11.5, cls="mono muted", anchor="end")
        body += text(x + 67, 268, verdict, size=10.5, cls=color, anchor="middle", weight=600)
    steps = [
        ("accent", "accent_soft", "class reads tone: not even evaluated"),
        ("accent", "accent_soft", "text and disabled read count: evaluated; handlers swapped"),
        ("green", "green_soft", "1 DOM write: the text \"2\""),
    ]
    for i, (color, soft, label) in enumerate(steps):
        y = 260 + 24 + i * 36
        body += box(460, y, 420, 28, p[soft], p[color], rx=14, width=1.2)
        body += text(476, y + 19, label, size=12.5, cls=color, weight=600)
    return svg(p, 880, 396, "One click in the counter, from 1 to 2. React builds a new tree of 5 elements and 5 props objects, walks it against the previous tree and writes one text. Melact keeps the markup as a template parsed once and runs the refresh the compiler generated for it: one === on each of the three locals the view reads, only the holes that read the changed one are evaluated, and it writes the same one text", body)


def family(p):
    def source(x, title, subtitle, color, lines):
        out = box(x, 30, 410, 150, p["card"], p[color], rx=14, width=1.6, lift=True)
        out += text(x + 18, 56, title, size=15, weight=800, cls=color)
        out += text(x + 18 + len(title) * 9 + 8, 56, subtitle, size=12, cls="muted")
        for i, parts in enumerate(lines):
            line = "".join(span(t, c) if c else escape(t) for t, c in parts)
            out += text(x + 18, 84 + i * 20, line, size=11.5, cls="mono", raw=True)
        return out

    body = text(0, 18, "two front ends, one compiler, one runtime", size=12.5, cls="muted", weight=600)
    body += source(0, "Meltea", "the Elm architecture, pure functions", "accent", [
        [("let view count =", "")],
        [("  <button onClick=", ""), ("Increment", "accent"), (">", "")],
        [("    (Html.int count)", "")],
        [("  </button>", "")],
    ])
    body += source(470, "Melact", "pretends to be React", "blue", [
        [("let[@react.component] make () =", "")],
        [("  let n, set = ", ""), ("React.useState", "blue"), (" … in", "")],
        [("  <button onClick=(fun _ -> set …)>", "")],
        [("    (React.int n)</button>", "")],
    ])
    for x, color, label, note in [(0, "accent", "meltea-ppx", "messages, no hooks, no components"),
                                  (470, "blue", "melact-ppx", "[@react.component], hook keys")]:
        body += arrow(p, x + 205, 182, x + 205, 202, color, flow=True)
        body += box(x + 105, 206, 200, 30, p[color + "_soft"], p[color], rx=15, width=1.4)
        body += text(x + 205, 226, label, size=12.5, cls=f"mono {color}", weight=700, anchor="middle")
        body += text(x + 205, 254, note, size=11, cls="muted", anchor="middle")
    body += curve(p, "M205,262 C205,286 330,282 330,300", "accent", flow=True)
    body += curve(p, "M675,262 C675,286 550,282 550,300", "blue", flow=True)
    body += box(200, 304, 480, 62, p["card"], p["text"], rx=14, width=1.6, lift=True)
    body += f'<rect x="200" y="304" width="480" height="5" rx="2.5" fill="url(#glow)"/>'
    body += text(440, 330, "the shared compiler", size=14.5, weight=800, anchor="middle")
    body += text(440, 352, "static markup → template · dynamic parts → holes with paths · DOM props table",
                 size=11.5, cls="muted", anchor="middle")
    body += arrow(p, 440, 368, 440, 392, "muted", flow=True)
    body += box(110, 396, 520, 50, p["card"], p["line"], rx=14, lift=True)
    body += text(370, 418, "shared runtime", size=13.5, weight=700, anchor="middle")
    body += text(370, 436, "clone a template · write changed holes · keyed moves · delegated events",
                 size=11, cls="muted", anchor="middle")
    body += box(642, 396, 238, 50, p["blue_soft"], p["blue"], rx=14)
    body += text(761, 418, "Melact only", size=13, weight=700, cls="blue", anchor="middle")
    body += text(761, 436, "hook slots · update scheduler", size=11, cls="muted", anchor="middle")
    return svg(p, 880, 450, "Two front ends, one compiler, one runtime: Meltea views in mlx with messages go through meltea-ppx, Melact components in reason-react style go through melact-ppx; both reach the shared compiler that turns static markup into templates and dynamic parts into holes, and the shared runtime that clones templates, writes changed holes, moves keyed rows and delegates events; Melact alone adds hook slots and an update scheduler", body)


def loop(p):
    stops = [
        (0, "click", "a DOM event", "orange"),
        (150, "Increment", "the message", "accent"),
        (300, "update", "pure: model → model", "accent"),
        (450, "view", "pure: model → holes", "accent"),
        (600, "\"42\" != \"41\"", "=== per hole", "blue"),
        (750, "text \"42\"", "one DOM write", "green"),
    ]
    body = text(0, 18, "the Meltea loop: everything between the event and the write is a pure function", size=12.5, cls="muted", weight=600)
    for i, (x, title, note, color) in enumerate(stops):
        body += box(x, 40, 130, 64, p[color + "_soft"], p[color], rx=12, width=1.5, lift=True)
        body += text(x + 65, 68, title, size=13, weight=700, cls="mono" if i in (1, 4, 5) else "", anchor="middle")
        body += text(x + 65, 90, note, size=11, cls="muted", anchor="middle")
        if i < len(stops) - 1:
            body += arrow(p, x + 132, 72, x + 146, 72, "accent", flow=True)
    body += curve(p, "M815,106 C815,170 65,170 65,108", "muted", flow=True)
    body += text(440, 178, "the next event", size=11.5, cls="muted", anchor="middle")
    return svg(p, 880, 186, "The Meltea loop: a DOM event becomes a message, the pure update returns the next model, the pure view gives the hole values, each is compared with === and only the changed one is written to the DOM; the next event starts the loop again", body)

def roadmap(p):
    stages = [
        ("View", "templates, holes,", "reconcile, events"),
        ("Hooks", "instances, useState,", "effects, context"),
        ("melact-ppx", "JSX → templates", "Reason, OCaml, mlx"),
        ("Compat", "ReactDOM, ReactEvent,", "TodoMVC unmodified"),
        ("Speed", "js-framework-", "benchmark"),
        ("SSR", "to_string,", "hydration"),
        ("Publish", "opam, CI,", "README numbers"),
    ]
    step = 124
    body = f'<line x1="66" y1="44" x2="{66 + step * 6}" y2="44" stroke="{p["line"]}" stroke-width="3"/>'
    body += f'<line x1="66" y1="44" x2="{66 + step * 2}" y2="44" stroke="{p["accent"]}" stroke-width="3"/>'
    body += f'<line x1="{66 + step * 2}" y1="44" x2="{66 + step * 3}" y2="44" stroke="{p["accent"]}" stroke-width="3" class="flow"/>'
    for i, (name, a, b) in enumerate(stages):
        x = 66 + i * step
        if i < 3:
            body += f'<circle cx="{x}" cy="44" r="16" fill="{p["accent"]}"/>'
            body += f'<path d="M{x - 7},44 l5,5 l9,-10" fill="none" stroke="#ffffff" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/>'
            body += text(x, 16, "done", size=11, cls="accent", weight=700, anchor="middle")
        elif i == 3:
            body += f'<circle cx="{x}" cy="44" r="16" fill="{p["accent_soft"]}" stroke="{p["accent"]}" stroke-width="2.5" class="pulse"/>'
            body += text(x, 49, "4", size=12, cls="accent", weight=700, anchor="middle")
            body += text(x, 16, "now", size=11, cls="accent", weight=700, anchor="middle")
        else:
            body += f'<circle cx="{x}" cy="44" r="13" fill="{p["card"]}" stroke="{p["line"]}" stroke-width="2"/>'
            body += text(x, 49, str(i + 1), size=12, cls="muted", weight=700, anchor="middle")
        body += text(x, 84, name, size=13.5, weight=600, anchor="middle")
        body += text(x, 104, a, size=11.5, cls="muted", anchor="middle")
        body += text(x, 120, b, size=11.5, cls="muted", anchor="middle")
    return svg(p, 880, 132, "Roadmap: View, hooks and melact-ppx done; compatibility in progress; then speed, SSR, publish", body)


FIGURES = dict(logo=logo, overview=overview, family=family, loop=loop, vdom=vdom, hooks=hooks, compat=compat, pipeline=pipeline, patch=patch, reconcile=reconcile,
               events=events, updates=updates, roadmap=roadmap)

if __name__ == "__main__":
    out = Path(__file__).parent
    for name, draw in FIGURES.items():
        (out / f"{name}.svg").write_text(draw(LIGHT))
        (out / f"{name}-dark.svg").write_text(draw(DARK))
