"""Writes the README figures, each in a light and a dark palette.

Run from the repository root: python3 assets/make.py
"""

import math
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

PAD = 8
SANS = "-apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif"
MONO = "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"


HEADER = {"current": None}
HEADER_HEIGHT = 92


def header(p, width, kicker, title, subtitle):
    return (
        f'<rect x="0" y="0" width="4" height="56" rx="2" fill="url(#glow)"/>'
        + text(16, 13, kicker.upper(), size=11, cls="accent", weight=800)
        .replace("<text ", '<text letter-spacing="1.4" ', 1)
        + text(16, 39, title, size=21, weight=800)
        + text(16, 61, subtitle, size=13, cls="muted")
        + f'<line x1="0" y1="{HEADER_HEIGHT - 16}" x2="{width}" y2="{HEADER_HEIGHT - 16}" stroke="url(#glow)" stroke-width="1.2" opacity="0.35"/>'
    )


def svg(p, width, height, label, body, pad=PAD):
    if HEADER["current"] is not None:
        kicker, title, subtitle = HEADER["current"]
        body = header(p, width, kicker, title, subtitle) + f'<g transform="translate(0 {HEADER_HEIGHT})">{body}</g>'
        height += HEADER_HEIGHT
        label = f"{title}. {subtitle} {label}"
    markers = "".join(
        f'<marker id="arrow-{name}" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" '
        f'markerHeight="7" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="{p[name]}"/></marker>'
        for name in ("muted", "accent", "green", "orange", "blue")
    )
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="-{pad} -{pad} {width + 2 * pad} {height + 2 * pad}" '
        f'width="{width + 2 * pad}" height="{height + 2 * pad}" role="img" aria-label="{escape(label)}"><style>'
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
    ink, card = p["text"], p["card"]
    body = (
        '<defs><radialGradient id="ember" cx="0.4" cy="0.35" r="0.75"><stop offset="0" stop-color="#ffc27a"/>'
        '<stop offset="1" stop-color="#e2600c"/></radialGradient></defs>'
        f'<rect x="6" y="6" width="108" height="108" rx="28" fill="{card}" stroke="{ink}" stroke-width="3"/>'
    )
    for i, size in enumerate((82, 64, 46)):
        half, opacity, turn = size / 2, 0.32 + i * 0.26, 7 * (i + 1)
        body += (f'<g transform="rotate({turn} 60 60)"><rect x="{60 - half:.1f}" y="{60 - half:.1f}" width="{size}" height="{size}" rx="{size / 3.6:.1f}" '
                 f'fill="none" stroke="{ink}" stroke-width="2.8" stroke-opacity="{opacity:.2f}">'
                 f'<animateTransform attributeName="transform" type="rotate" values="0 60 60; {4 + i * 2} 60 60; 0 60 60" dur="{3 + i * 0.6:.1f}s" repeatCount="indefinite"/>'
                 f'<animate attributeName="stroke-opacity" values="{opacity:.2f};{min(1, opacity + 0.35):.2f};{opacity:.2f}" dur="2.4s" begin="{i * 0.3:.1f}s" repeatCount="indefinite"/>'
                 '</rect></g>')
    body += ('<g transform="rotate(28 60 60)"><rect x="48" y="48" width="24" height="24" rx="7.5" fill="url(#ember)" class="pulse"/>'
             '<path d="M54,55 q3,-3 7,-3" fill="none" stroke="#ffffff" stroke-opacity="0.75" stroke-width="2.2" stroke-linecap="round"/></g>')
    return svg(p, 120, 120, "Melact: frames turning into a funnel around one live hole", body, pad=0)


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

    def heading(x, n, title, note):
        return (f'<circle cx="{x + 12}" cy="14" r="12" fill="{p["accent"]}"/>'
                + text(x + 12, 19, n, size=12.5, weight=800, anchor="middle", fill="#ffffff")
                + text(x + 32, 19, title, size=15, weight=700)
                + text(x + 32, 38, note, size=11.5, cls="muted"))

    def mono(x, y, parts, size=11.5):
        line = "".join(span(t, c) if c else escape(t) for t, c in parts)
        return text(x, y, line, size=size, cls="mono", raw=True)

    body = heading(0, "1", "You keep your code", "a reason-react component, unchanged")
    body += heading(305, "2", "Melact compiles it, once", "at build time, per JSX tree")
    body += heading(610, "3", "A click runs this", "in the browser, every render")

    body += box(0, 54, 270, 166, p["card"], p["line"], lift=True)
    code = [
        [("let[@react.component] make () =", "")],
        [("  let n, set =", "")],
        [("    React.useState (fun () -> 0) in", "")],
        [("  <button onClick=", ""), ("(fun _ ->", "accent")],
        [("      set (fun n -> n + 1))", "accent"), (">", "")],
        [("    ", ""), ("(React.int n)", "orange")],
        [("  </button>", "")],
    ]
    for i, parts in enumerate(code):
        body += mono(14, 82 + i * 19, parts, size=11.2)
    body += box(0, 232, 270, 82, p["card"], p["line"], lift=True)
    body += text(14, 252, "the whole migration: two dune lines", size=11.5, cls="muted", weight=600)
    for i, (line, cls) in enumerate([("- (libraries reason-react)  + melact", "orange"), ("- (pps reason-react-ppx)  + melact-ppx", "green")]):
        body += text(14, 276 + i * 20, line, size=11, cls=f"mono {cls}")

    body += box(305, 54, 270, 260, p["card"], p["accent"], lift=True, width=1.4)
    body += text(321, 78, "the template, made once", size=12.5, cls="accent", weight=700)
    tpl = escape("<button") + span("●", "accent") + escape(">") + span("●", "orange") + escape("</button>")
    body += box(321, 90, 238, 40, p["accent_soft"], p["accent"], rx=8, dash="4 4")
    body += text(440, 116, tpl, size=14, cls="mono", raw=True, anchor="middle")
    body += text(321, 150, "●", size=12, cls="accent")
    body += text(335, 150, "the click handler", size=11.5, cls="muted")
    body += text(441, 150, "●", size=12, cls="orange")
    body += text(455, 150, "the text n", size=11.5, cls="muted")
    body += text(321, 168, "holes: the only places that can change", size=11.5, cls="muted")
    body += f'<line x1="321" y1="184" x2="559" y2="184" stroke="{p["line"]}"/>'
    body += text(321, 206, "the render, generated", size=12.5, cls="blue", weight=700)
    body += mono(321, 232, [("if ", "accent"), ("n", "orange"), (" !== last then", "")])
    body += mono(321, 252, [("  text.data = ", ""), ("n", "orange")])
    body += text(321, 280, "one compare per value, at most", size=11.5, cls="muted")
    body += text(321, 298, "one write per change: nothing else", size=11.5, cls="muted")

    body += box(610, 54, 270, 260, p["card"], p["line"], lift=True)
    flow = [
        ("click → set (fun n -> n + 1)", "your code, as before", "line"),
        ("only this component runs", "no parent, no tree", "line"),
        ("n: 0 → 1, so n !== last", "one ===", "accent"),
        ("text.data = \"1\"", "the only DOM write", "green"),
    ]
    for i, (label, note, tone) in enumerate(flow):
        y = 68 + i * 60
        fill = {"line": p["card"], "accent": p["accent_soft"], "green": p["green_soft"]}[tone]
        stroke = {"line": p["line"], "accent": p["accent"], "green": p["green"]}[tone]
        body += box(626, y, 238, 44, fill, stroke, rx=10, width=1.3)
        body += text(640, y + 19, label, size=12, cls=("mono green" if tone == "green" else "mono accent" if tone == "accent" else "mono"), weight=700)
        body += text(640, y + 36, note, size=11, cls="muted")
        if i < len(flow) - 1:
            body += arrow(p, 745, y + 45, 745, y + 58, "accent", width=1.4)

    body += arrow(p, 273, 184, 301, 184, "accent", flow=True)
    body += arrow(p, 578, 184, 606, 184, "accent", flow=True)

    body += box(0, 336, 430, 116, p["card"], p["line"], rx=14)
    body += text(18, 362, "Gone", size=14.5, weight=700)
    body += text(62, 362, "from the bundle and from every render", size=12.5, cls="muted")
    body += chips(18, 376, 400, ["React", "react-dom", "virtual DOM", "a tree per render", "tree diff", "fiber"], "gone")
    body += box(450, 336, 430, 116, p["accent_soft"], p["accent"], rx=14)
    body += text(468, 362, "Stays", size=14.5, weight=700)
    body += text(512, 362, "it compiles unchanged", size=12.5, cls="muted")
    body += chips(468, 376, 400, ["your components", "hooks", "mlx · Reason · OCaml", "ReactDOM", "React.Event"], "stays")
    body += box(0, 468, 880, 52, p["green_soft"], p["green"], rx=14, width=1.4)
    body += text(20, 499, "Starting fresh?", size=14, weight=700, cls="green")
    body += text(140, 499, "Write Meltea: messages and a pure update, compiled by the same compiler into the same templates.", size=12.5, cls="muted")
    return svg(p, 880, 520, "Melact in one picture. 1: you keep a reason-react component unchanged; the whole migration is two dune lines. 2: Melact compiles it once, at build time, into a template with two holes, the click handler and the text n, the only places that can change, and a generated render: if n !== last then text.data = n, one compare per value and at most one write per change. 3: a click runs your set as before, only this component runs, n goes from 0 to 1 so one === fails, and text.data = 1 is the only DOM write. Gone: React, react-dom, the virtual DOM, a tree per render, the tree diff, fiber. Stays: your components, hooks, mlx, Reason and OCaml, ReactDOM, React.Event. Starting fresh? Write Meltea", body)


def pipeline(p):
    body = ""
    heads = [(0, "1 · You write JSX in mlx"), (290, "2 · Melact compiles a template"), (650, "3 · The DOM")]
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
    body += text(486, 84, "the walk", size=11.5, cls="muted")
    for i, hole in enumerate(["b = first div", "o = next b", "text: end of o"]):
        body += text(486, 102 + i * 16, hole, size=10.5, cls="mono accent")

    body += box(290, 172, 300, 104, p["card"], p["line"])
    body += text(306, 194, "every render: the compiled refresh", size=11.5, cls="blue", weight=600)
    for i, line in enumerate(["check count; check tone", "if tone: set class", "if count: set text"]):
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
    body += text(664, 236, "3 holes reached by the walk,", size=11.5, cls="muted")
    body += text(664, 254, "the rest gets no DOM writes", size=11.5, cls="muted")

    body += arrow(p, 234, 140, 284, 140, "accent", flow=True)
    body += text(259, 124, "build", size=11, cls="muted", anchor="middle")
    body += arrow(p, 594, 98, 644, 98, "accent", flow=True)
    body += text(619, 84, "clone", size=11, cls="muted", anchor="middle")
    body += arrow(p, 594, 224, 644, 224, "blue", flow=True)
    body += text(619, 210, "patch", size=11, cls="muted", anchor="middle")
    return svg(p, 880, 280, "mlx JSX is compiled into a template hoisted to module level and a walk to its three holes: b is the first child of the div, o the next sibling of b, and the text goes at the end of o; the template is cloned once per mount; every render runs the compiled refresh, which checks count and tone and writes only the holes that read a changed one", body)


def patch(p):
    columns = [(16, "local the view reads"), (220, "render 41 → 42"), (400, "check"), (500, "holes that read it"), (690, "DOM work")]
    body = "".join(text(x, 22, c, size=12, cls="muted", weight=600) for x, c in columns)
    rows = [
        ("count", "41 → 42", "changed", "orange", "text, disabled", "node.data = \"42\"", "orange", True),
        ("tone", "\"\" → \"\"", "same", "green", "class", "class not even evaluated", "green", False),
        ("initial", "0 → 0", "same", "green", "disabled (with count)", "evaluated, still false: no write", "green", False),
        ("setCount", "stable", "same", "green", "3 × onClick", "handlers kept, none rebuilt", "green", False),
    ]
    for i, (name, change, verdict, vcls, holes, work, wcls, hot) in enumerate(rows):
        y = 36 + i * 54
        body += box(0, y, 880, 44, p["orange_soft"] if hot else p["card"], p["orange"] if hot else p["line"], rx=10, lift=hot)
        body += text(16, y + 27, name, size=13, cls="mono", weight=700)
        body += box(220, y + 10, 140, 24, "none", p["line"], rx=6)
        body += text(290, y + 27, change, size=12, cls="mono", anchor="middle")
        body += text(400, y + 27, verdict, size=13, cls=f"mono {vcls}", weight=700)
        body += text(500, y + 27, holes, size=12, cls="muted")
        body += text(690, y + 27, work, size=12, cls=wcls, weight=600 if hot else None)
    body += text(0, 268, "One click in counter-react: four === on locals, then only the holes that read the changed one run, handlers included.", size=12, cls="muted")
    return svg(p, 880, 276, "The compiled refresh of counter-react on a click from 41 to 42: count changed, so the text and disabled holes run and the text node gets 42; tone, initial and the setter are the same, so the class hole is not even evaluated and the three click handlers, which read only the setter and initial, are kept", body)


def reconcile(p):
    old = ["a", "b", "c", "d", "e", "f"]
    new = ["a", "e", "c", "d", "b", "f"]
    kind = {"a": "muted", "f": "muted", "c": "green", "d": "green", "b": "accent", "e": "accent"}
    x0, step, top, bottom = 72, 78, 40, 184

    def chip(x, y, key):
        color = kind[key]
        fill = {"muted": p["card"], "green": p["green_soft"], "accent": p["accent_soft"]}[color]
        stroke = {"muted": p["line"], "green": p["green"], "accent": p["accent"]}[color]
        return box(x - 26, y, 52, 34, fill, stroke, rx=8, width=1.4) + text(x, y + 22, key, size=14, cls="mono", weight=600, anchor="middle")

    body = text(0, 62, "old", size=12, cls="muted", weight=600) + text(0, 206, "new", size=12, cls="muted", weight=600)
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
        ("accent", "everything else: one moveBefore each, keeping focus,"),
    ]
    for i, (color, label) in enumerate(legend):
        y = 252 + i * 22
        body += f'<rect x="0" y="{y - 10}" width="14" height="10" rx="3" fill="{p[color]}"/>'
        body += text(22, y, label, size=12, cls="muted")
    body += text(22, 318, "media and animations (insertBefore without it)", size=12, cls="muted")

    body += box(520, 0, 360, 340, p["card"], p["line"], rx=14, lift=True)
    body += text(540, 30, "Reconcile.plan, cheapest case first", size=14, weight=700)
    steps = [
        ("Trim the ends", ["skip the common prefix and suffix; a swapped",
                           "first and last row costs two moves, no sort"]),
        ("One side empty", ["append every row, or clear the list with one",
                            "textContent = \"\" when it fills its parent"]),
        ("Same keys, same order", ["the loop patches rows in place: no plan,",
                                   "no moves, and kept rows are not even called"]),
        ("Anything else", ["old keys go into a small hash table, so each new",
                           "key finds its old position; the longest increasing",
                           "run of positions stays, the rest move"]),
    ]
    y = 64
    for n, (head, lines) in enumerate(steps, 1):
        body += f'<circle cx="551" cy="{y - 5}" r="11" fill="{p["accent"]}"/>'
        body += text(551, y, str(n), size=11.5, weight=700, anchor="middle", fill="#ffffff")
        body += text(572, y, head, size=13, weight=600)
        for k, line in enumerate(lines):
            body += text(572, y + 19 + k * 17, line, size=11.5, cls="muted")
        y += 24 + len(lines) * 17 + 10
    return svg(p, 880, 340, "Keyed reconcile: the common prefix a and suffix f stay, c and d form the longest increasing run of old positions and stay, b and e move with one moveBefore each, which keeps focus, media and animations inside them, or insertBefore where the browser lacks it. Reconcile.plan tries the cheapest case first: trim the common ends, where a swapped first and last row costs two moves; an empty side is one append or one clear; keys in the same order are patched in place without a plan; anything else looks old keys up in a hash table, keeps the longest increasing run and moves the rest", body)


def events(p):
    nodes = [("document", 60, "1 listener per event type"), ("div", 108, "$$melhole:click = outer"), ("ul", 156, None),
             ("li", 204, None), ("button", 252, "$$melhole:click = inner")]
    body = ""
    for name, y, note in nodes:
        handler = note and note.startswith("$$")
        body += box(150, y - 22, 120, 32, p["accent_soft"] if handler else p["card"], p["accent"] if handler else p["line"], rx=8, width=1.4)
        body += text(210, y - 1, name, size=13, cls="mono", weight=600, anchor="middle")
        if note:
            body += text(300, y - 1, note, size=11.5, cls="mono accent" if handler else "muted")
    body += curve(p, "M146,236 C96,200 96,80 146,48", "muted", flow=True)
    body += text(18, 146, "native", size=11.5, cls="muted")
    body += text(18, 162, "bubbling", size=11.5, cls="muted")
    body += curve(p, "M274,240 C336,200 336,130 274,96", "accent", flow=True, width=2)
    body += text(326, 172, "walk", size=11.5, cls="accent", weight=600)
    body += f'<circle cx="152" cy="246" r="6" fill="{p["orange"]}" class="pulse"/>'
    body += text(118, 276, "click", size=11.5, cls="orange", weight=600)
    body += text(0, 336, "From the target up, Melact calls each element's $$melhole:click; stopPropagation ends the walk.", size=12, cls="muted")
    body += text(0, 354, "22 bubbling types are delegated; scroll, focus, load … get one listener on their element.", size=12, cls="muted")

    body += box(540, 0, 340, 300, p["card"], p["line"], rx=14, lift=True)
    blocks = [
        ("While a handler runs", "e.currentTarget  ⟶  its element", "set for the call, as React does; removed after"),
        ("React.Event is the native event", "Mouse.clientX e  =  e.clientX", "ofNative is the identity: no synthetic copy"),
        ("Replacing a handler", "el[\"$$melhole:click\"] = next", "only when a value it reads changed; no listener"),
    ]
    for i, (head, code, note) in enumerate(blocks):
        y = 34 + i * 92
        body += text(560, y, head, size=14, weight=600)
        body += box(560, y + 12, 300, 28, p["accent_soft"], p["accent"], rx=7, width=1.2)
        body += text(572, y + 31, code, size=12, cls="mono accent", weight=600)
        body += text(560, y + 60, note, size=11.5, cls="muted")
    return svg(p, 880, 360, "One listener per event type on the document; on a click Melact walks from the target up through parent nodes and calls the handler stored on each element, with event.currentTarget set to that element as React does; React.Event reads the native event directly, since ofNative is the identity; a handler is replaced with one property write, and only when a value it reads changed", body)


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
    body += text(230, 288, "inputs === → kept", size=11, cls="green", anchor="middle")
    body += text(470, 288, "inputs === → kept", size=11, cls="green", anchor="middle")
    body += text(350, 288, "an input changed", size=11, cls="accent", anchor="middle")

    steps = [
        ("1", "The setter marks TodoList dirty", "nothing renders yet"),
        ("2", "One microtask flushes", "dirty instances, parents first"),
        ("3", "TodoList renders again", "App and Header are not visited"),
        ("4", "A Row without hooks is a pure view", "no instance; its inputs, one === each, keep it"),
    ]
    for i, (n, head, note) in enumerate(steps):
        y = 54 + i * 60
        body += f'<circle cx="594" cy="{y - 5}" r="12" fill="{p["accent"]}"/>'
        body += text(594, y, n, size=12, weight=700, anchor="middle", fill="#ffffff")
        body += text(616, y, head, size=13.5, weight=600)
        body += text(616, y + 18, note, size=12, cls="muted")
    return svg(p, 880, 300, "A state update in TodoList re-renders TodoList only; App and Header are not visited; Rows without hooks are pure views with no instance, kept while each of their inputs is physically equal", body)


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
    body += text(466, 288, "A hook behind an if is caught twice", size=12.5, cls="orange", weight=700)
    body += text(466, 308, "build: Alert hook, which melact-ppx turns on in branches,", size=12, cls="muted")
    body += text(466, 325, "loops and callbacks · run: slot k2 ≠ call k3 → an error", size=12, cls="muted")
    return svg(p, 880, 338, "melact-ppx gives every hook call site its own Type.Id key, hoisted to module level; the instance stores each slot with the key that made it; reading a slot checks provably_equal, so values come back typed; a hook behind an if, in a loop or in a callback raises the hook alert at build time, and a hook called out of order raises an error at run time instead of returning a wrong value", body)


def surface(p):
    rows = [
        ("<Counter label=\"a\" />", "Counter.make (Counter.makeProps ~label:\"a\" ())", "makeProps builds the element; make is the identity"),
        ("React.createElement C.make (C.makeProps ~label ())", "the same element, with an optional key", "C.make : C.props React.component, as in reason-react"),
        ("onClick=(fun e -> React.Event.Mouse.clientX e)", "e.clientX, on the native event", "ofNative is the identity; delegated to document"),
        ("React.useState (fun () -> 0)", "React.useState k1 (fun () -> 0)", "a typed slot key per call site; Alert hook in an if"),
        ("a component that calls no use…", "Melhole.View.pure", "no instance: kept while its inputs are ==="),
        ("ReactDOM.Client.render (createRoot el) <App />", "App's templates cloned into el", "no React, no react-dom, no fiber underneath"),
        ("ReactDOMServer.renderToString / hydrateRoot", "Served.render / Served.hydrate", "React's HTML format; the browser takes it over"),
        ("ReasonReactRouter.useUrl ()", "the same url record", "read from location on popstate"),
    ]
    body = text(0, 16, "your reason-react code, unchanged", size=12.5, cls="blue", weight=700)
    body += text(466, 16, "what melact-ppx and Melact make of it", size=12.5, cls="accent", weight=700)
    for i, (code, made, note) in enumerate(rows):
        y = 30 + i * 48
        body += box(0, y, 420, 40, p["card"], p["line"], rx=9)
        body += text(14, y + 25, code, size=11.5, cls="mono")
        body += arrow(p, 424, y + 20, 460, y + 20, "accent", flow=True)
        body += box(466, y, 414, 40, p["accent_soft"], p["accent"], rx=9, width=1.2)
        body += text(480, y + 17, made, size=11.5, cls="mono accent", weight=600)
        body += text(480, y + 33, note, size=11, cls="muted")
    return svg(p, 880, 414, "What melact-ppx and the Melact library make of unchanged reason-react code: a JSX component is makeProps building the element, with make the identity; React.createElement with makeProps is the same element with a key; React.Event accessors read the native event, delegated to document; each hook call gets a typed slot key; a component without hooks is a pure view with no instance; ReactDOM.Client clones templates into the element; renderToString and hydrateRoot are Served.render and Served.hydrate; ReasonReactRouter.useUrl reads the location on popstate", body)


def hydration(p):
    def card(x, w, title, subtitle, stroke):
        return (box(x, 0, w, 300, p["card"], p[stroke], rx=14, width=1.4, lift=True)
                + text(x + 18, 28, title, size=14, weight=700)
                + text(x + 18, 47, subtitle, size=11.5, cls="muted"))

    body = card(0, 290, "1 · on the server", "Program.render · renderToString", "line")
    html = [
        [("<div class=\"counter\">", "")],
        [("  <button>-</button>", "")],
        [("  <output class=\"\">", ""), ("41", "green"), ("</output>", "")],
        [("  <button>+</button>", "")],
        [("  <button>reset</button>", "")],
        [("</div>", "")],
        [("", "")],
        [("<p>count: ", ""), ("<!-- -->", "orange"), ("41", "green"), ("</p>", "")],
    ]
    for i, parts in enumerate(html):
        line = "".join(span(t, c) if c else escape(t) for t, c in parts)
        body += text(18, 80 + i * 20, line, size=11.5, cls="mono", raw=True)
    body += text(18, 258, "React's format: no markers at all,", size=11.5, cls="muted")
    body += text(18, 276, "<!-- --> only between two texts", size=11.5, cls="muted")
    body += arrow(p, 294, 150, 326, 150, "accent", flow=True, width=1.8)

    body += card(330, 290, "2 · in the browser: hydrate", "compiled adopt code, in document order", "accent")
    steps = [
        ("off-page clone", "", "the template's own refresh reads the values"),
        ("div.counter", "", "same tag: taken over, not cloned"),
        ("41", "green", "taken over; a list takes its own rows"),
        ("3 × button", "", "handlers set; nothing else is written"),
    ]
    for i, (label, tone, note) in enumerate(steps):
        y = 78 + i * 52
        body += f'<circle cx="352" cy="{y - 4}" r="4" fill="{p["accent"]}"/>'
        body += text(364, y, label, size=12, cls=f"mono {tone}".strip(), weight=700)
        body += text(364, y + 18, note, size=11.5, cls="muted")
    body += arrow(p, 624, 110, 656, 110, "green", flow=True, width=1.8)

    body += box(660, 0, 220, 196, p["green_soft"], p["green"], rx=14, width=1.5, lift=True)
    body += text(770, 30, "3 · the same page, live", size=13.5, cls="green", weight=700, anchor="middle")
    body += box(690, 48, 160, 44, p["card"], p["line"], rx=10)
    for bx, sign in ((698, "−"), (812, "+")):
        body += box(bx, 54, 30, 32, p["card"], p["line"], rx=7)
        body += text(bx + 15, 76, sign, size=15, anchor="middle", weight=600)
    body += text(770, 77, "41", size=18, cls="mono green", weight=700, anchor="middle")
    body += text(770, 122, "no element added to the page", size=12, weight=600, anchor="middle")
    body += text(770, 144, "every element is the server's;", size=11.5, cls="muted", anchor="middle")
    body += text(770, 162, "React's and server-reason-react's", size=11.5, cls="muted", anchor="middle")
    body += text(770, 180, "HTML hydrate the same way", size=11.5, cls="muted", anchor="middle")
    body += box(660, 212, 220, 88, p["orange_soft"], p["orange"], rx=14, width=1.3)
    body += text(678, 240, "HTML that does not match", size=13, cls="orange", weight=700)
    body += text(678, 262, "the view: the root is cleared", size=11.5, cls="muted")
    body += text(678, 280, "and mounted from scratch", size=11.5, cls="muted")

    body += box(0, 322, 880, 112, p["blue_soft"], p["blue"], rx=14, width=1.3)
    body += text(18, 348, "between 1 and 2 · before the code arrives", size=13.5, cls="blue", weight=700)
    body += text(326, 348, "Melhole_server.capture in <head> records them, with each value then", size=11.5, cls="muted")
    early = [("click", "−"), ("input", "\"mi\""), ("input", "\"milk\""), ("keydown", "Enter")]
    for i, (kind, detail) in enumerate(early):
        x = 18 + i * 124
        body += box(x, 364, 112, 30, p["card"], p["blue"], rx=8)
        body += text(x + 10, 384, kind, size=11.5, cls="mono blue", weight=700)
        body += text(x + 102, 384, detail, size=11.5, cls="mono", anchor="end")
        if i:
            body += arrow(p, x - 12, 379, x - 2, 379, "blue", width=1.3)
    body += text(18, 418, "the page looks alive but nothing runs: the events wait, in order", size=11.5, cls="muted")
    body += arrow(p, 512, 379, 552, 379, "blue", flow=True, width=1.8)
    body += text(532, 368, "hydrate", size=11, cls="mono muted", anchor="middle")
    body += box(560, 352, 302, 66, p["card"], p["line"], rx=10)
    body += text(576, 375, "delivered once the program runs", size=12.5, weight=700)
    body += text(576, 393, "through the live paths, each target", size=11.5, cls="muted")
    body += text(576, 409, "showing the value it had at that event", size=11.5, cls="muted")
    return svg(p, 880, 434, "Server rendering and hydration in React's format: on the server Program.render, renderToString or server-reason-react write plain HTML with no markers, and a comment only between two adjacent texts; in the browser, code the compiler generated for each template walks the server's nodes in document order, after an off-page clone has let the template's own refresh compute the values: the root with the same tag is taken over, texts and lists take exactly their nodes, and the buttons get their handlers; no element is added to the page, and HTML that does not match the view is cleared and mounted from scratch. Before the code arrives, Melhole_server.capture in the page's head records clicks, typing and key presses on document with each target's value at that moment, and hydration delivers them in order through the live paths once the program runs", body)


def selectors(p):
    body = box(0, 0, 404, 310, p["card"], p["line"], rx=14, lift=True)
    body += text(18, 28, "a row reads its item and one outer value", size=13.5, weight=700)
    lines = [
        [("Html.list (List.map (fun row ->", "")],
        [("  <tr className=", ""), ("(if Some row.id = selected", "green")],
        [("                 ", ""), ("then \"danger\" else \"\")", "green"), (">", "")],
        [("    <td>(Html.text row.label)</td>", "")],
        [("  </tr>) rows)", "")],
    ]
    body += box(18 + 16 * 7.23 - 1.5, 70, 26 * 7.23 + 6, 46, p["green_soft"], p["green"], rx=7, dash="4 3", width=1.3)
    for i, parts in enumerate(lines):
        line = "".join(span(t, c) if c else escape(t) for t, c in parts)
        body += text(18, 66 + i * 24, line, size=12, cls="mono", raw=True)
    body += text(18, 204, "The leaf has no JSX and reads the outer", size=11.5, cls="muted")
    body += text(18, 222, "selected. The compiler emits a projection:", size=11.5, cls="muted")
    body += text(18, 248, "fun row -> [| leaf row |]", size=12.5, cls="mono green", weight=700)
    body += text(18, 278, "A row renders only if its item is another", size=11.5, cls="muted")
    body += text(18, 296, "object or its projection changed.", size=11.5, cls="muted")

    body += text(430, 24, "selected: Some 2 → Some 5", size=13.5, weight=700)
    body += text(868, 24, "6 items, same objects", size=11.5, cls="muted", anchor="end")
    heads = [(446, "row"), (500, "item"), (580, "projection"), (866, "row is")]
    for x, head in heads:
        body += text(x, 50, head, size=11.5, cls="muted", weight=600, anchor="end" if head == "row is" else "start")
    rows = [
        (1, "\"\" → \"\"", "kept"), (2, "\"danger\" → \"\"", "rendered"), (3, "\"\" → \"\"", "kept"),
        (4, "\"\" → \"\"", "kept"), (5, "\"\" → \"danger\"", "rendered"), (6, "\"\" → \"\"", "kept"),
    ]
    for i, (n, change, verdict) in enumerate(rows):
        y = 62 + i * 36
        hot = verdict == "rendered"
        body += box(430, y, 450, 30, p["accent_soft"] if hot else p["card"], p["accent"] if hot else p["line"], rx=8, width=1.3 if hot else 1, lift=hot)
        body += text(446, y + 20, str(n), size=12.5, cls="mono", weight=700)
        body += text(500, y + 20, "===", size=12, cls="mono green")
        body += text(580, y + 20, change, size=12, cls="mono accent" if hot else "mono muted", weight=600 if hot else None)
        body += text(866, y + 20, verdict, size=12, cls="accent" if hot else "green", weight=700, anchor="end")
    body += text(430, 296, "keys in the same order: the two rows are patched in place", size=11.5, cls="muted")
    return svg(p, 880, 310, "Compiled selectors, after Vue Vapor: a row of Html.list (List.map …) reads its item and the outer value selected through one leaf without JSX; the compiler emits a projection that evaluates only that leaf for each row. When selected goes from Some 2 to Some 5 and the six items are the same objects, only rows 2 and 5 have a changed projection, so only they render, in place; the other four are kept without calling the row function", body)


def fields(p):
    def chip(x, y, label, color, soft, anchor_end=False):
        w = len(label) * 6.9 + 16
        left = x - w if anchor_end else x
        return box(left, y, w, 22, p[soft], p[color], rx=11, width=1.2) + text(left + w / 2, y + 15, label, size=11, cls=f"mono {color}", weight=700, anchor="middle"), w

    body = box(0, 0, 490, 300, p["card"], p["line"], rx=14, lift=True)
    body += text(18, 28, "meltea-ppx reads update: what each message changes", size=13.5, weight=700)
    branches = [
        ("| Type field -> { model with field }", ["field"], "accent"),
        ("| Route filter -> { model with filter }", ["filter"], "accent"),
        ("| Add -> { model with todos; field; next }", ["todos", "field", "next"], "accent"),
        ("| Ignore -> model", ["nothing"], "green"),
        ("| Edit id -> Option.fold …", ["all"], "orange"),
    ]
    for i, (code, changed, color) in enumerate(branches):
        y = 62 + i * 44
        body += text(18, y + 15, code, size=11.5, cls="mono")
        x = 474
        for label in reversed(changed):
            piece, w = chip(x, y, label, color, color + "_soft", anchor_end=True)
            body += piece
            x -= w + 6
    body += text(18, 288, "a branch it does not recognise changes all fields: slower, never wrong", size=11.5, cls="muted")

    body += box(520, 0, 360, 96, p["card"], p["line"], rx=14, lift=True)
    body += text(538, 28, "and view: the fields it reads", size=13.5, weight=700)
    x = 538
    for label in ["todos", "field", "editing", "filter"]:
        piece, w = chip(x, 44, label, "blue", "blue_soft")
        body += piece
        x += w + 8
    body += text(538, 84, "next is never read", size=11.5, cls="muted")

    decisions = [
        (112, "green", "Ignore", "{ }", "the view is not called at all"),
        (210, "accent", "Type \"milk\"", "{ field }", "the view runs; one === per local picks the holes"),
    ]
    for y, color, message, changed, outcome in decisions:
        body += box(520, y, 360, 88, p[color + "_soft"], p[color], rx=14, width=1.4)
        body += text(538, y + 28, message, size=13, cls=f"mono {color}", weight=700)
        body += text(538, y + 52, f"changes {changed} ∩ reads = {'∅' if changed == '{ }' else changed}", size=12, cls="mono")
        body += text(538, y + 74, outcome, size=11.5, cls="muted")
    body += text(440, 330, "The masks are generated next to update and view; Program keeps the fields changed since the last draw.", size=12, cls="muted", anchor="middle", weight=600)
    body += text(440, 352, "Subscriptions are read the same way: TodoMVC's reads no field, so it is asked once, at the start.", size=12, cls="muted", anchor="middle")
    return svg(p, 880, 360, "Fields an update changes, in Meltea's TodoMVC: meltea-ppx reads update and finds what each message can change: Type changes field, Route changes filter, Add changes todos, field and next, Ignore changes nothing, and Edit, which it does not recognise, changes all fields. It reads view the same way: todos, field, editing and filter, never next. After Ignore nothing the view reads changed, so the view is not called; after Type the view runs and one === per local picks the holes to write. subscriptions are read the same way, and are asked again only after a draw that changed a field they read", body)


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
             ("tone", "\"\" = \"\"", "green", "same"), ("setCount", "stable", "green", "same")]
    for i, (name, value, color, verdict) in enumerate(cells):
        x = 460 + i * 106
        soft = {"green": "green_soft", "orange": "orange_soft"}[color]
        body += box(x, 222, 100, 42, p[soft], p[color], rx=7, width=1.4, lift=color == "orange")
        body += text(x + 50, 239, name, size=12, cls="mono", weight=700, anchor="middle")
        body += text(x + 50, 256, value, size=11, cls="mono muted", anchor="middle")
        body += text(x + 50, 280, verdict, size=10.5, cls=color, anchor="middle", weight=600)
    steps = [
        ("accent", "accent_soft", "class reads tone: not even evaluated"),
        ("accent", "accent_soft", "text, disabled read count: evaluated · handlers: kept"),
        ("green", "green_soft", "1 DOM write: the text \"2\""),
    ]
    for i, (color, soft, label) in enumerate(steps):
        y = 292 + i * 34
        body += box(460, y, 420, 28, p[soft], p[color], rx=14, width=1.2)
        body += text(476, y + 19, label, size=12.5, cls=color, weight=600)
    return svg(p, 880, 396, "One click in the counter, from 1 to 2. React builds a new tree of 5 elements and 5 props objects, walks it against the previous tree and writes one text. Melact keeps the markup as a template parsed once and runs the refresh the compiler generated for it: one === on each of the four locals the view reads (count, initial, tone and the setter), only the holes that read the changed one are evaluated, the click handlers, which read only unchanged locals, are kept, and it writes the same one text", body)


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
    for x, color, label, note in [(0, "accent", "meltea-ppx", "messages · fields each update changes"),
                                  (470, "blue", "melact-ppx", "hook keys and alerts · makeProps")]:
        body += arrow(p, x + 205, 182, x + 205, 202, color, flow=True)
        body += box(x + 105, 206, 200, 30, p[color + "_soft"], p[color], rx=15, width=1.4)
        body += text(x + 205, 226, label, size=12.5, cls=f"mono {color}", weight=700, anchor="middle")
        body += text(x + 205, 254, note, size=11, cls="muted", anchor="middle")
    body += curve(p, "M205,262 C205,286 330,282 330,300", "accent", flow=True)
    body += curve(p, "M675,262 C675,286 550,282 550,300", "blue", flow=True)
    body += box(200, 304, 480, 62, p["card"], p["text"], rx=14, width=1.6, lift=True)
    body += f'<rect x="200" y="304" width="480" height="5" rx="2.5" fill="url(#glow)"/>'
    body += text(440, 330, "the shared compiler", size=14.5, weight=800, anchor="middle")
    body += text(440, 352, "static markup → template · a walk to every hole · keyed loops with selectors",
                 size=11.5, cls="muted", anchor="middle")
    body += arrow(p, 440, 368, 440, 392, "muted", flow=True)
    body += box(110, 396, 520, 50, p["card"], p["line"], rx=14, lift=True)
    body += text(370, 418, "melhole · no components, views are functions", size=13.5, weight=700, anchor="middle")
    body += text(370, 436, "clone · write changed holes · keyed moves · delegated events · hydration",
                 size=11, cls="muted", anchor="middle")
    body += box(642, 396, 238, 50, p["blue_soft"], p["blue"], rx=14)
    body += text(761, 418, "melact.runtime", size=13, weight=700, cls="blue mono", anchor="middle")
    body += text(761, 436, "components · hooks · scheduler", size=11, cls="muted", anchor="middle")
    return svg(p, 880, 450, "Two front ends, one compiler, one runtime: Meltea views in mlx with messages go through meltea-ppx, Melact components in reason-react style go through melact-ppx; both reach the shared compiler that turns static markup into templates, walks to every hole and compiles lists into keyed loops with selectors, and the shared runtime melhole, which knows no components: it clones templates, writes changed holes, moves keyed rows, delegates events and hydrates server HTML; meltea-ppx also finds the fields each update changes, melact-ppx gives hooks keys and alerts and writes makeProps; Melact adds its own runtime library with components, hooks and the scheduler", body)


def compiled(p):
    char = 7.83
    cx = 655

    def code(x, y, parts, size=13):
        line = "".join(span(t, c) if c else escape(t) for t, c in parts)
        return text(x, y, line, size=size, cls="mono", raw=True)

    def hole(x, y, w, h=26):
        return box(x, y, w, h, p["green_soft"], p["green"], rx=6, dash="4 3", width=1.3)

    def counter(y, value, changed):
        out = box(cx - 120, y, 240, 60, p["card"], p["line"], rx=12, lift=True)
        for bx, sign in ((cx - 108, "−"), (cx + 64, "+")):
            out += box(bx, y + 12, 44, 36, p["card"], p["line"], rx=8)
            out += text(bx + 22, y + 37, sign, size=18, anchor="middle", weight=600)
        if changed:
            out += hole(cx - 30, y + 15, 60)
        out += text(cx, y + 39, value, size=22, cls="mono green" if changed else "mono", weight=700, anchor="middle")
        return out

    def node(x, y, label, w):
        return (box(x - w / 2, y - 13, w, 26, p["card"], p["line"], rx=13)
                + text(x, y + 4.5, label, size=12, cls="mono muted", anchor="middle"))

    def edge(x1, y1, x2, y2):
        return f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{p["line"]}" stroke-width="1.5"/>'

    body = box(0, 0, 380, 410, p["card"], p["accent"], rx=14, width=1.6, lift=True)
    body += text(20, 32, "you write the counter", size=13.5, weight=700, cls="accent")
    lines = [
        [("let view count =", "")],
        [("  <div>", "")],
        [("    <button onClick=", ""), ("Decrement", "accent"), (">", "")],
        [("      (Html.text \"-\")</button>", "")],
        [("    <output>", "")],
        [("      (Html.int ", ""), ("count", "green"), (")", "")],
        [("    </output>", "")],
        [("    <button onClick=", ""), ("Increment", "accent"), (">", "")],
        [("      (Html.text \"+\")</button>", "")],
        [("  </div>", "")],
    ]
    for i, parts in enumerate(lines):
        if i == 5:
            body += hole(20 + 6 * char - 5, 76 + i * 32 - 18, 16 * char + 10)
        body += code(20, 76 + i * 32, parts)

    body += text(cx, 14, "in the page: click +", size=12.5, weight=700, anchor="middle")
    body += counter(24, "41", False)
    body += f'<path d="M{cx + 96},52 l0,17 l4.5,-4 l3,7 l3,-1.4 l-3,-7 l6,0 z" fill="{p["text"]}" stroke="{p["card"]}" stroke-width="1"/>'
    body += arrow(p, cx, 90, cx, 118, "accent", flow=True)
    body += text(cx + 10, 108, "".join([span("Increment", "accent"), escape(" → update: count = 42")]),
                 size=11.5, cls="muted", raw=True)

    body += box(440, 124, 430, 196, p["card"], p["line"], rx=14)
    body += text(458, 146, "the template Meltea compiled: no DOM writes to the grey nodes", size=11.5, cls="faint")
    top, middle, bottom = 172, 220, 268
    body += edge(cx, top + 13, cx - 140, middle - 13) + edge(cx, top + 13, cx, middle - 13)
    body += edge(cx, top + 13, cx + 140, middle - 13)
    body += edge(cx - 140, middle + 13, cx - 140, bottom - 13) + edge(cx, middle + 13, cx, bottom - 13)
    body += edge(cx + 140, middle + 13, cx + 140, bottom - 13)
    body += node(cx, top, "div", 56)
    body += node(cx - 140, middle, "button", 76) + node(cx, middle, "output", 76) + node(cx + 140, middle, "button", 76)
    body += node(cx - 140, bottom, "\"−\"", 46) + node(cx + 140, bottom, "\"+\"", 46)
    body += hole(cx - 52, bottom - 13, 104)
    body += text(cx, bottom + 4.5, "text 41→42", size=12, cls="mono green", weight=700, anchor="middle")
    body += code(cx - 132, 306, [("if (", ""), ("count", "green"), (" !== last) ", ""), ("text.data = \"42\"", "green")], size=12.5)

    body += arrow(p, cx, 326, cx, 344, "green", flow=True)
    body += counter(350, "42", True)

    body += text(440, 446, "no virtual DOM: Meltea compiles the view at build time into code like Svelte's",
                 size=13, cls="muted", anchor="middle", weight=600)
    return svg(p, 880, 456, "The counter in Meltea: you write the view in mlx; Meltea compiles it into a template tree of div, two buttons and an output whose text is the only hole; when + is clicked the update makes count 42, the compiled code compares count with its last value and writes 42 into that one text node; the grey static nodes get no DOM writes; there is no virtual DOM", body)


def controlled(p):
    def field(x, y, w, content, stroke, caret=False, placeholder=False, dash=None):
        out = box(x, y, w, 34, p["card"], stroke, rx=7, dash=dash, width=1.6)
        out += text(x + 12, y + 23, content, size=15 if not placeholder else 13.5,
                    cls="faint" if placeholder else "mono", weight=None if placeholder else 600)
        if caret:
            cx = x + 12 + len(content) * 9.1 + 2
            out += f'<line x1="{cx}" y1="{y + 8}" x2="{cx}" y2="{y + 26}" stroke="{p["accent"]}" stroke-width="2" class="pulse"/>'
        return out

    def badge(x, y, color, mark):
        out = f'<circle cx="{x}" cy="{y}" r="12" fill="{p[color]}"/>'
        path = f"M{x - 5},{y} l3.5,3.8 l6.5,-7.6" if mark == "yes" else f"M{x - 4.5},{y - 4.5} l9,9 M{x + 4.5},{y - 4.5} l-9,9"
        return out + f'<path d="{path}" fill="none" stroke="#ffffff" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>'

    def chip(cx, y, label, color, soft):
        w = len(label) * 7.4 + 30
        return (box(cx - w / 2, y, w, 24, p[soft], p[color], rx=12, width=1.3)
                + f'<circle cx="{cx - w / 2 + 12}" cy="{y + 12}" r="4" fill="{p[color]}" class="pulse"/>'
                + text(cx + 6, y + 16.5, label, size=12, cls=f"mono {color}", weight=700, anchor="middle"))

    def mono(x, y, parts, size=12.5, anchor="start"):
        return text(x, y, "".join(span(t, c) if c else escape(t) for t, c in parts), size=size, cls="mono", raw=True, anchor=anchor)

    body = text(20, 20, "One tick: the user types and presses Enter before the next draw", size=14, weight=700)
    body += f'<line x1="20" y1="66" x2="860" y2="66" stroke="{p["line"]}" stroke-width="2" stroke-dasharray="2 6" stroke-linecap="round"/>'
    centers = (145, 440, 735)
    body += chip(centers[0], 54, "input", "orange", "orange_soft")
    body += chip(centers[1], 54, "keydown Enter", "orange", "orange_soft")
    body += chip(centers[2], 54, "redraw", "blue", "blue_soft")

    for i, cx in enumerate(centers):
        body += box(cx - 125, 94, 250, 132, p["card"], p["line"], rx=14, lift=True)
        if i < 2:
            body += arrow(p, cx + 131, 160, cx + 164, 160, "accent", flow=True)
    x0, x1, x2 = (cx - 109 for cx in centers)
    body += text(x0, 116, "the DOM", size=11.5, cls="faint", weight=600)
    body += field(x0, 124, 218, "milk", p["accent"], caret=True)
    body += mono(x0, 186, [("Type ", "accent"), ("\"milk\"", "accent")])
    body += mono(x0, 210, [("field = \"milk\"", "muted")])

    body += text(x1, 116, "the DOM, untouched", size=11.5, cls="faint", weight=600)
    body += field(x1, 124, 218, "milk", p["line"])
    body += mono(x1, 186, [("Add", "accent"), ("  → a new todo", "muted")])
    body += mono(x1, 210, [("field = \"\"", "muted")])

    body += text(x2, 116, "the guard on field", size=11.5, cls="faint", weight=600)
    body += box(x2, 124, 218, 34, p["blue_soft"], p["blue"], rx=17, width=1.4)
    body += mono(x2 + 109, 148, [("\"\"", ""), (" === ", "blue"), ("\"\"", "")], size=14, anchor="middle")
    body += mono(x2, 186, [("new \"\" is last \"\"", "muted")])
    body += mono(x2, 210, [("unchanged → ", "muted"), ("no write", "blue")])

    body += box(20, 250, 410, 168, p["orange_soft"], p["orange"], rx=14, width=1.5)
    body += text(40, 278, "a guard alone", size=14, weight=700, cls="orange")
    body += field(40, 294, 320, "milk", p["orange"])
    body += badge(396, 311, "orange", "no")
    body += mono(40, 352, [("nothing writes the field again:", "muted")], size=11.5)
    body += mono(40, 376, [("DOM ", "muted"), ("\"milk\"", ""), ("  ≠  ", "orange"), ("model ", "muted"), ("\"\"", "")], size=15)

    body += box(450, 250, 410, 168, p["green_soft"], p["green"], rx=14, width=1.5)
    body += text(470, 278, "value and checked: controlled holes", size=14, weight=700, cls="green")
    body += field(470, 294, 320, "What needs to be done?", p["green"], placeholder=True, dash="4 3")
    body += badge(826, 311, "green", "yes")
    body += mono(470, 350, [("after input/change and the redraw:", "muted")], size=11.5)
    body += mono(470, 373, [("if (el.value !== last) ", ""), ("el.value = last", "green")], size=13)
    body += mono(470, 400, [("a write to value also sets ", "muted"), ("el.defaultValue", "green")], size=11.5)

    body += text(440, 448, "the guard still skips unchanged values, and the field always shows the model, as React's controlled inputs",
                 size=12.5, cls="muted", anchor="middle", weight=600)
    return svg(p, 880, 456, "Controlled inputs: in one tick the user types milk and presses Enter; the model's field goes from empty to milk and back to empty while the DOM still shows milk, so the redraw's guard sees an unchanged value and writes nothing. A guard alone leaves milk in the field, out of step with the model. In Meltea and Melact value and checked are controlled holes: after an input or change event and the redraw it causes, the hole writes its last value back if the DOM differs, as React does; a write to value also sets defaultValue, so the value attribute stays in step, as in React", body)


def roadmap(p):
    stages = [
        ("View", "templates, holes,", "reconcile, events", "done"),
        ("Hooks", "instances, useState,", "effects, context", "done"),
        ("melact-ppx", "JSX → templates", "Reason, OCaml, mlx", "done"),
        ("Compat", "React.Event, makeProps,", "TodoMVC unmodified", "done"),
        ("Speed", "keyed loops,", "×1.15 vanilla", "done"),
        ("SSR", "React's HTML, native,", "early events", "done"),
        ("Publish", "CI done,", "opam release", "now"),
    ]
    step = 124
    body = f'<line x1="66" y1="44" x2="{66 + step * 6}" y2="44" stroke="{p["line"]}" stroke-width="3"/>'
    for i, (name, a, b, status) in enumerate(stages):
        x = 66 + i * step
        if status == "done":
            body += f'<circle cx="{x}" cy="44" r="16" fill="{p["accent"]}"/>'
            body += f'<path d="M{x - 7},44 l5,5 l9,-10" fill="none" stroke="#ffffff" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/>'
            body += text(x, 16, "done", size=11, cls="accent", weight=700, anchor="middle")
        elif status == "now":
            body += f'<circle cx="{x}" cy="44" r="16" fill="{p["accent_soft"]}" stroke="{p["accent"]}" stroke-width="2.5" class="pulse"/>'
            body += text(x, 49, str(i + 1), size=12, cls="accent", weight=700, anchor="middle")
            body += text(x, 16, "now", size=11, cls="accent", weight=700, anchor="middle")
        else:
            body += f'<circle cx="{x}" cy="44" r="13" fill="{p["card"]}" stroke="{p["line"]}" stroke-width="2"/>'
            body += text(x, 49, str(i + 1), size=12, cls="muted", weight=700, anchor="middle")
        body += text(x, 84, name, size=13.5, weight=600, anchor="middle")
        body += text(x, 104, a, size=11.5, cls="muted", anchor="middle")
        body += text(x, 120, b, size=11.5, cls="muted", anchor="middle")
    return svg(p, 880, 132, "Roadmap: View, hooks, melact-ppx, compatibility, speed and server rendering with hydration done; publishing in progress: CI runs every law, the opam release is next", body)


def transition(p):
    columns = [(150, "the patch"), (400, "two frames later: CSS animates"), (650, "when the duration is up")]
    body = "".join(text(x + 115, 18, head, size=12.5, weight=700, anchor="middle") for x, head in columns)
    body += "".join(arrow(p, x + 228, 14, x + 256, 14, "muted", flow=True) for x, _ in columns[:2])

    def chip(x, y, key, tone="plain", opacity=1.0, dash=None):
        fill, stroke, cls = {"plain": (p["card"], p["line"], ""), "accent": (p["accent_soft"], p["accent"], "accent"),
                             "orange": (p["orange_soft"], p["orange"], "orange"), "green": (p["green_soft"], p["green"], "green")}[tone]
        return (f'<g opacity="{opacity}">' + box(x, y, 50, 30, fill, stroke, rx=8, width=1.4, dash=dash)
                + text(x + 25, y + 20, key, size=13, cls=f"mono {cls}".strip(), weight=700, anchor="middle") + "</g>")

    def cell(x, y, chips, note, note_cls="mono muted"):
        out = box(x, y, 230, 96, p["card"], p["line"], rx=12)
        for i, (key, tone, opacity, dash) in enumerate(chips):
            out += chip(x + 20 + i * 66, y + 14, key, tone, opacity, dash)
        for k, line in enumerate(note):
            out += text(x + 14, y + 66 + k * 16, line, size=11, cls=note_cls)
        return out

    rows = [
        (40, "enter", ["b is new"], "accent",
         [([("a", "plain", 1, None), ("b", "accent", 0.3, "4 3"), ("c", "plain", 1, None)], ["fade-enter-from", "fade-enter-active"]),
          ([("a", "plain", 1, None), ("b", "accent", 0.75, None), ("c", "plain", 1, None)], ["fade-enter-active", "fade-enter-to"]),
          ([("a", "plain", 1, None), ("b", "plain", 1, None), ("c", "plain", 1, None)], ["no classes left"])]),
        (152, "leave", ["b was removed", "and is put back"], "orange",
         [([("a", "plain", 1, None), ("b", "orange", 1, None), ("c", "plain", 1, None)], ["fade-leave-from", "fade-leave-active"]),
          ([("a", "plain", 1, None), ("b", "orange", 0.35, None), ("c", "plain", 1, None)], ["fade-leave-active", "fade-leave-to"]),
          ([("a", "plain", 1, None), ("c", "plain", 1, None)], ["b leaves the DOM"])]),
        (264, "move", ["group only:", "c went first"], "green",
         [([("a", "green", 1, None), ("b", "green", 1, None), ("c", "green", 1, None)], ["DOM is c a b; a transform", "shows each row where it was"]),
          ([("c", "green", 1, None), ("a", "green", 1, None), ("b", "green", 1, None)], ["fade-move, transforms", "cleared: the rows slide"]),
          ([("c", "plain", 1, None), ("a", "plain", 1, None), ("b", "plain", 1, None)], ["no classes left"])]),
    ]
    for y, head, notes, color, cells in rows:
        body += text(0, y + 38, head, size=14, weight=700, cls=color)
        for k, line in enumerate(notes):
            body += text(0, y + 58 + k * 16, line, size=11.5, cls="muted")
        for (x, _), (chips, note) in zip(columns, cells):
            body += cell(x, y, chips, note)
        if head == "move":
            body += curve(p, f"M{400 + 20 + 25 + 132},{y + 12} C{400 + 170},{y - 10} {400 + 60},{y - 10} {400 + 45},{y + 12}", "green", flow=True)
    body += text(440, 384, "The wrapper stays mounted; only what it shows changes. The first render does not animate.",
                 size=12, cls="muted", anchor="middle", weight=600)
    body += box(0, 404, 880, 64, p["accent_soft"], p["accent"], rx=12, width=1.2)
    body += text(18, 430, "Cmd.view_transition", size=13, cls="mono accent", weight=700)
    body += text(190, 430, "the update asks; the next draw runs inside document.startViewTransition,", size=12, cls="muted")
    body += text(190, 450, "so the browser animates the whole page from old to new, with no classes and no FLIP code", size=12, cls="muted")
    return svg(p, 880, 468, "Transitions, as Vue's Transition and TransitionGroup, with name fade. Enter: in the patch the new row b gets fade-enter-from and fade-enter-active, two frames later fade-enter-to replaces fade-enter-from while CSS animates, and when the duration is up no classes are left. Leave: the removed row b is put back where it was with fade-leave-from and fade-leave-active, two frames later fade-leave-to, and when the duration is up it leaves the DOM. Move, in a group: row c went first, so after the patch the DOM is c a b but a transform shows every moved row where it was; two frames later the rows get fade-move and the transforms are cleared, so they slide to their new places; at the end no classes are left. Cmd.view_transition makes the next draw run inside document.startViewTransition, so the browser animates the whole page", body)


def row(p):
    def column(x, title, subtitle, items, color):
        out = text(x, 18, title, size=14, weight=700, cls=color) + text(x, 37, subtitle, size=11.5, cls="muted")
        y = 52
        for label, note, tone in items:
            fill = {"plain": p["card"], "accent": p["accent_soft"], "orange": p["orange_soft"], "green": p["green_soft"]}[tone]
            stroke = {"plain": p["line"], "accent": p["accent"], "orange": p["orange"], "green": p["green"]}[tone]
            out += box(x, y, 400, 26, fill, stroke, rx=7, width=1.2)
            out += text(x + 12, y + 17.5, label, size=11.5, cls="mono", weight=600)
            out += text(x + 388, y + 17.5, note, size=11, cls="muted", anchor="end")
            y += 31
        return out

    before = [
        ("child { build; patch; shape }", "+2 closures", "orange"),
        ("with_key + Entry", "2 blocks", "orange"),
        ("refresh closure", "per row", "orange"),
        ("live { each; front; release }", "+3 closures", "orange"),
        ("Compiled_state + lend", "+1 closure", "orange"),
        ("scope + deps", "", "plain"),
        ("holes array + 5 hole records", "6 blocks", "orange"),
        ("2 handler closures", "per row", "orange"),
        ("projection array", "", "plain"),
    ]
    after = [
        ("Mounted_row { root; scope; holes }", "1 block", "green"),
        ("scope + deps", "+ the last written values", "green"),
        ("holes: the bare nodes", "no hole records", "green"),
        ("element.$$melhole:data1 = id", "no closure", "green"),
        ("projection array", "", "plain"),
    ]
    body = column(0, "a row before", "View.each over generic children", before, "orange")
    body += column(480, "a row now", "View.rows, flat holes, linked handlers", after, "green")
    body += box(480, 248, 400, 76, p["accent_soft"], p["accent"], rx=12, width=1.3)
    body += text(498, 272, "shared, not per row", size=12.5, cls="accent", weight=700)
    body += text(498, 292, "the template and one refresh per list, the key function,", size=11.5, cls="muted")
    body += text(498, 309, "one handler per site (View.link) per dispatch", size=11.5, cls="muted")
    body += arrow(p, 420, 160, 466, 160, "green", flow=True, width=1.8)
    body += text(440, 350, "Creating 1,000 rows of the benchmark allocates about 430 kB instead of 939; 1,000 rows take 1.22 MB instead of 1.68.",
                 size=12, cls="muted", anchor="middle", weight=600)
    return svg(p, 880, 358, "What one row of a compiled list holds. Before: a child description with build and patch closures, a with_key wrapper, a refresh closure, a mounted child with three closures, a compiled state with a lend closure, a scope with its deps, a holes array with five hole records, two handler closures and a projection array. Now: one Mounted_row record with the root, the scope and the holes, the scope's deps also holding the last written values, the holes as bare nodes, the handler data as a property of the element, and the projection array; the template, one refresh per list, the key function and one handler per site are shared. Creating 1,000 rows allocates about 430 kB instead of 939, and 1,000 rows take 1.22 MB instead of 1.68", body)


def served(p):
    def mono(x, y, parts, size=11.5):
        line = "".join(span(t, c) if c else escape(t) for t, c in parts)
        return text(x, y, line, size=size, cls="mono", raw=True)

    body = box(0, 0, 250, 300, p["card"], p["line"], rx=14, width=1.4, lift=True)
    body += text(18, 28, "page.mlx", size=14, weight=700)
    body += text(18, 47, "one module, built twice", size=11.5, cls="muted")
    source = [
        [("let view count =", "")],
        [("  <div className=\"counter\">", "")],
        [("    <button onClick=Decrement>", "")],
        [("      (Html.text \"-\")", "")],
        [("    </button>", "")],
        [("    <output className=", ""), ("tone", "orange"), (">", "")],
        [("      (Html.int ", ""), ("count", "orange"), (")", "")],
        [("    </output>", "")],
        [("    …", "faint")],
        [("  </div>", "")],
    ]
    for i, parts in enumerate(source):
        body += mono(18, 80 + i * 19, parts)
    body += text(18, 284, "model, update, view: plain OCaml", size=11.5, cls="muted")

    body += curve(p, "M254,110 C280,110 280,70 306,70", "accent", flow=True, width=1.8)
    body += curve(p, "M254,190 C280,190 280,236 306,236", "green", flow=True, width=1.8)

    body += box(310, 0, 570, 140, p["accent_soft"], p["accent"], rx=14, width=1.4, lift=True)
    body += text(328, 28, "meltea-ppx · in the browser", size=13.5, cls="accent", weight=700)
    body += text(862, 28, "meltea", size=11.5, cls="mono muted", anchor="end")
    browser = [
        [("Template.html \"<div class=\\\"counter\\\"><button>-</button><output></output>…\"", "")],
        [("walk: div.firstChild.nextSibling → output", "")],
        [("refresh: if ", ""), ("count", "orange"), (" !== last then output.data = String(count)", "")],
    ]
    for i, parts in enumerate(browser):
        body += mono(328, 60 + i * 22, parts)
    body += text(328, 128, "cloned once, then only the holes whose locals changed are written", size=11.5, cls="muted")

    body += box(310, 160, 570, 140, p["green_soft"], p["green"], rx=14, width=1.4, lift=True)
    body += text(328, 188, "meltea-ppx -server · natively or in Node, no DOM", size=13.5, cls="green", weight=700)
    body += text(862, 188, "meltea.server", size=11.5, cls="mono muted", anchor="end")
    server = [
        [("markup w \"<div class=\\\"counter\\\"><button>-</button><output\"", "")],
        [("attribute w \"class\" (Some ", ""), ("tone", "orange"), (")", "")],
        [("markup w \">\"; dynamic_text w (string_of_int ", ""), ("count", "orange"), (")", "")],
        [("markup w \"</output><button>+</button>…\"", "")],
    ]
    for i, parts in enumerate(server):
        body += mono(328, 216 + i * 19, parts)
    body += text(328, 291, "static markup joined at compile time, one call per dynamic part", size=11.5, cls="muted")

    body += box(0, 330, 880, 84, p["card"], p["line"], rx=14, width=1.2)
    body += text(18, 356, "the HTML, in React's format", size=13, weight=700)
    body += mono(18, 380, [("<div class=\"counter\"><button>-</button><output class=\"\">", ""), ("41", "green"), ("</output><button>+</button>…</div>", "")], size=12)
    body += text(18, 402, "the same bytes natively and under Melange; floats as JavaScript writes them", size=11.5, cls="muted")
    body += arrow(p, 595, 304, 595, 326, "green", width=1.6)
    body += curve(p, "M884,372 C912,372 912,70 884,70", "accent", flow=True, width=1.6)
    body += text(862, 356, "hydrate: the browser build takes these nodes over", size=11.5, cls="accent", anchor="end", weight=600)
    return svg(p, 920, 414, "One Meltea module, page.mlx, built twice. meltea-ppx for the browser compiles the view into a template parsed once and cloned, a walk to the output and a refresh that writes the text only when count changed. meltea-ppx -server compiles the same view into code that writes strings with no DOM, natively or in Node: the static markup joined into a few strings at compile time and one call per dynamic part, the class and the count. The server writes HTML in React's format, the same bytes natively and under Melange, and the browser build hydrates it", body)


def fanout(p):
    def chip(x, y, label, color, soft):
        w = len(label) * 6.9 + 16
        return box(x, y, w, 22, p[soft], p[color], rx=11, width=1.2) + text(x + w / 2, y + 15, label, size=11, cls=f"mono {color}", weight=700, anchor="middle"), w

    def station(x, w, y, title, code, color):
        return (box(x, y, w, 96, p["card"], p[color], rx=12, width=1.3, lift=True)
                + text(x + 14, y + 22, title, size=11.5, cls="muted", weight=600)
                + text(x + 14, y + 46, code, size=11.5, cls="mono"))

    titles = ["the handler, frequent", "sends", "update writes", "view: a list reads"]
    xs = [(0, 250), (276, 130), (432, 200), (658, 222)]

    def path(y, color, handler, message, branch, written, loop, reads, shared):
        body = ""
        for (x, w), title, code in zip(xs, titles, [handler, message, branch, loop]):
            body += station(x, w, y, title, code, color if title != "sends" else "line")
        for index, ((x, w), (nx, _)) in enumerate(zip(xs, xs[1:])):
            reached = index < 2 or shared
            body += arrow(p, x + w + 2, y + 48, nx - 4, y + 48, color if reached else "muted", flow=bool(reached), width=1.6)
        piece, _ = chip(446, y + 62, written, color, color + "_soft")
        body += piece
        cx = 672
        for label in reads:
            tone, soft = ("orange", "orange_soft") if label in shared else ("blue", "blue_soft")
            piece, w = chip(cx, y + 62, label, tone, soft)
            body += piece
            cx += w + 6
        return body

    body = path(0, "orange", "onInput=(fun t -> Retype t)", "Retype", "{ model with editing }", "editing",
                "List.map (row editing) …", ["todos", "filter", "editing"], ["editing"])
    body += path(124, "green", "onInput=(fun t -> Type t)", "Type", "{ model with field }", "field",
                 "List.map (row editing) …", ["todos", "filter", "editing"], [])
    body += text(0, 244, "the edit field: every keystroke reaches the list", size=12, cls="orange", weight=700)
    body += text(880, 244, "the new-todo field: no list reads field, one hole is written", size=12, cls="green", weight=700, anchor="end")

    body += box(0, 262, 880, 92, p["orange_soft"], p["orange"], rx=14, width=1.3)
    body += text(18, 288, "Alert fanout", size=13, cls="orange", weight=700)
    body += text(118, 288, "at the handler, from meltea-ppx, with no annotations", size=11.5, cls="muted")
    body += text(18, 312, "each input event here sends Retype, which changes editing; the list at line 187 reads editing,", size=11.5, cls="mono")
    body += text(18, 330, "so every input event checks all of its rows", size=11.5, cls="mono")
    body += text(862, 346, "\"Enter\" -> Add is one action, not every key: it does not count", size=11, cls="muted", anchor="end")
    return svg(p, 880, 354, "Fanout in Meltea's TodoMVC: meltea-ppx follows a frequent event to the lists it reaches. The edit field's onInput sends Retype, whose branch of update writes editing, and the list in view reads todos, filter and editing, so every keystroke makes the list check all its rows; the compiler raises the alert fanout at the handler. The new-todo field's onInput sends Type, which writes field, which no list reads, so typing writes one hole and there is no alert. A key handler's literal branch such as Enter sends Add once and does not count", body)


def remember(p):
    def column(x, title, subtitle, color, lines, verdict):
        body = box(x, 52, 420, 236, p["card"], p[color], rx=14, width=1.4, lift=True)
        body += text(x + 18, 80, title, size=13.5, cls=color, weight=700)
        body += text(x + 18, 99, subtitle, size=11.5, cls="muted")
        for i, parts in enumerate(lines):
            line = "".join(span(t, c) if c else escape(t) for t, c in parts)
            body += text(x + 18, 132 + i * 22, line, size=11.5, cls="mono", raw=True)
        body += box(x + 18, 232, 384, 40, p[color + "_soft"], p[color], rx=10, width=1.1)
        body += text(x + 32, 257, verdict, size=12, cls=color, weight=700)
        return body

    body = text(0, 20, "Type \"m\"", size=14, cls="mono accent", weight=700)
    body += text(80, 20, "changes only draft; the view runs because it reads draft", size=12.5, cls="muted")
    before = [
        [("let shown = List.filter … model.items", "")],
        [("  → a new list, every call", "orange")],
        [("<ul>(Html.list (List.map row shown))</ul>", "")],
        [("  shown !== last shown → the list runs", "orange")],
    ]
    after = [
        [("let shown = View.remember m", "")],
        [("  [| model.filter; model.items |] (fun () -> …)", "")],
        [("  filter === · items === → the old list", "green")],
        [("  shown === last shown → hole skipped", "green")],
    ]
    body += column(0, "without", "every let computed again", "orange", before, "1,000 rows checked for one keystroke")
    body += column(460, "remembered by what it reads", "meltea-ppx knows the fields of each let", "green", after, "no row checked, one hole written: draft")
    body += arrow(p, 424, 170, 456, 170, "green", flow=True, width=1.8)
    return svg(p, 880, 290, "Remembered values in a Meltea view: Type m changes only the draft field. Without remembering, let shown = List.filter over model.items builds a new list on every call, so the list hole sees a different value and checks all 1,000 rows. meltea-ppx compiles the let to View.remember keyed by model.filter and model.items; both are the same objects, so the old list comes back, the hole is skipped, and only the draft hole is written", body)


def hot(p):
    body = box(0, 0, 250, 150, p["card"], p["line"], rx=14, width=1.3, lift=True)
    body += text(18, 28, "running on #root", size=13.5, weight=700)
    body += text(18, 56, "model", size=11.5, cls="muted")
    body += text(18, 76, "{ todos = [milk];", size=11.5, cls="mono")
    body += text(18, 94, "  field = \"half typed\" }", size=11.5, cls="mono")
    body += text(18, 124, "shape", size=11.5, cls="muted")
    body += text(64, 124, "a3f1…", size=11.5, cls="mono accent", weight=700)
    body += arrow(p, 254, 75, 300, 75, "muted", flow=True, width=1.6)
    body += text(277, 64, "edit", size=11, cls="muted", anchor="middle")
    body += box(304, 0, 250, 150, p["accent_soft"], p["accent"], rx=14, width=1.3, lift=True)
    body += text(322, 28, "new code arrives", size=13.5, cls="accent", weight=700)
    body += text(322, 54, "Vite re-runs main.mlx:", size=11.5, cls="muted")
    body += text(322, 76, "Program.element", size=11.5, cls="mono")
    body += text(322, 94, "  ~start:Program.hot …", size=11.5, cls="mono")
    body += text(322, 124, "shape of its types", size=11.5, cls="muted")
    body += text(452, 124, "a3f1…", size=11.5, cls="mono accent", weight=700)
    body += curve(p, "M558,50 C590,50 590,24 622,24", "green", flow=True, width=1.8)
    body += curve(p, "M558,100 C590,100 590,124 622,124", "orange", flow=True, width=1.6)
    body += box(626, 0, 254, 66, p["green_soft"], p["green"], rx=12, width=1.3)
    body += text(642, 26, "same shape: the model carries over", size=12, cls="green", weight=700)
    body += text(642, 48, "new view and update, old state", size=11.5, cls="muted")
    body += box(626, 90, 254, 60, p["orange_soft"], p["orange"], rx=12, width=1.3)
    body += text(642, 114, "types changed: start from init", size=12, cls="orange", weight=700)
    body += text(642, 136, "the old model may not fit them", size=11.5, cls="muted")
    body += text(0, 180, "meltea-ppx writes the shape, a digest of the module's type declarations, next to update; the old program stops and leaves the root.", size=11.5, cls="muted")
    return svg(p, 880, 186, "Hot reload in Meltea: a program runs on the root with its model and the shape of its module's types. After an edit, Vite runs main.mlx again, and Program.element with ~start:Program.hot finds the running program; when the new code's shape is the same, the model carries over and the new view and update show the old state; when the types changed, the program starts from init. meltea-ppx writes the shape, a digest of the type declarations, next to update", body)


def speed(p):
    frameworks = [("vanilla JS", "faint", 1.00), ("Meltea", "accent", 1.15), ("Melact", "blue", 1.17), ("React 18", "orange", 1.70)]
    body = box(0, 0, 880, 232, p["card"], p["line"], rx=14, width=1.2, lift=True)
    body += text(20, 30, "time, geometric mean of nine keyed operations", size=13.5, weight=700)
    body += text(860, 30, "pale: the work itself · solid: the overhead · lower is better", size=11.5, cls="muted", anchor="end")
    left, right = 150, 820
    scale = (right - left) / 1.8
    for tick in (1.0, 1.2, 1.4, 1.6, 1.8):
        x = left + tick * scale
        body += f'<line x1="{x:.1f}" y1="48" x2="{x:.1f}" y2="208" stroke="{p["line"]}" stroke-dasharray="3 4"/>'
        body += text(x, 222, f"×{tick:.1f}", size=10.5, cls="muted", anchor="middle")
    for i, (name, color, value) in enumerate(frameworks):
        y = 58 + i * 38
        w = value * scale
        fill = p["line"] if color == "faint" else p[color]
        body += text(20, y + 18, name, size=13, weight=700 if color in ("accent", "blue") else 500)
        base = scale
        soft = p["line"] if color == "faint" else p[color + "_soft"]
        body += f'<rect x="{left}" y="{y}" width="{base:.1f}" height="26" rx="6" fill="{soft}" stroke="{fill}" stroke-opacity="0.35"/>'
        if value > 1.0:
            body += f'<rect x="{left + base - 6:.1f}" y="{y}" width="{w - base + 6:.1f}" height="26" rx="6" fill="{fill}"/>'
            body += text(left + base + (w - base) / 2, y + 18, f"+{round((value - 1) * 100)}%", size=11.5, weight=800, anchor="middle", fill="#ffffff" if p is LIGHT else "#0d1117")
        body += text(left + w + 8, y + 18, f"×{value:.2f}", size=13, cls="mono", weight=800)

    def panel(x, title, unit, rows, maximum):
        out = box(x, 252, 430, 196, p["card"], p["line"], rx=14, width=1.2, lift=True)
        out += text(x + 20, 282, title, size=13.5, weight=700)
        out += text(x + 410, 282, unit, size=11.5, cls="muted", anchor="end")
        inner_left, inner_right = x + 130, x + 360
        for i, (name, color, value, shown) in enumerate(rows):
            y = 302 + i * 34
            w = max(3, value / maximum * (inner_right - inner_left))
            fill = p["line"] if color == "faint" else p[color]
            out += text(x + 20, y + 16, name, size=12.5)
            out += f'<rect x="{inner_left}" y="{y}" width="{w:.1f}" height="22" rx="5" fill="{fill}"/>'
            out += text(inner_left + w + 8, y + 16, shown, size=12, cls="mono", weight=700)
        return out

    body += panel(0, "JS bundle of the benchmark app", "kB gzip", [
        ("vanilla JS", "faint", 1.4, "1.4"), ("Meltea", "accent", 9.0, "9.0"), ("Melact", "blue", 9.9, "9.9"), ("React 18", "orange", 45.6, "45.6")], 45.6)
    body += panel(450, "heap with 1,000 rows", "MB", [
        ("vanilla JS", "faint", 0.77, "0.77"), ("Meltea", "accent", 1.22, "1.22"), ("Melact", "blue", 1.64, "1.64"), ("React 18", "orange", 3.17, "3.17")], 3.17)
    body += box(0, 468, 880, 52, p["green_soft"], p["green"], rx=12, width=1.2)
    body += text(20, 499, "swap two rows of 1,000:", size=13, weight=700)
    body += text(200, 499, "Meltea ×1.12 · Melact ×1.17 · React 18 ×5.86", size=13, cls="mono green", weight=800)
    body += text(860, 499, "two moves, not 998", size=12, cls="muted", anchor="end")
    return svg(p, 880, 520, "js-framework-benchmark's keyed operations in headless Chrome, slowdown against hand-written vanilla JS, lower is better: vanilla 1.00, Meltea 1.15, Melact 1.17, React 18 1.70. JS bundle of the benchmark app, gzip: vanilla 1.4 kB, Meltea 9.0, Melact 9.9, React 18 45.6. Heap with 1,000 rows: vanilla 0.77 MB, Meltea 1.22, Melact 1.64, React 18 3.17. Swapping two rows of 1,000: Meltea 1.12, Melact 1.17, React 18 5.86", body)


FIGURES = dict(logo=logo, overview=overview, family=family, compiled=compiled, controlled=controlled, vdom=vdom, hooks=hooks,
               surface=surface, hydration=hydration, selectors=selectors, fields=fields, pipeline=pipeline, patch=patch,
               reconcile=reconcile, events=events, updates=updates, transition=transition, row=row, roadmap=roadmap, served=served, fanout=fanout, remember=remember, hot=hot, speed=speed)

HEADERS = dict(
    overview=("Melact in one picture", "Your reason-react code, compiled: no React underneath",
              "Two dune lines change. Components, hooks and JSX stay; the build turns each JSX tree into a template and a refresh."),
    speed=("Benchmark", "Within ×1.2 of hand-written JavaScript",
           "js-framework-benchmark's keyed operations in headless Chrome, against vanilla JS and React 18."),
    surface=("Compatibility", "The reason-react API, kept call for call",
             "Every line on the left compiles unchanged; on the right is what it becomes."),
    vdom=("No virtual DOM", "React compares trees. Melact compares variables.",
          "One render of the counter: React allocates and diffs five elements, Melact checks four locals."),
    pipeline=("How it compiles", "JSX becomes a template, a walk and a refresh",
              "The markup is parsed once and cloned per mount; a render runs only the guarded writes."),
    patch=("Fine-grained updates", "One === per local, then only the holes that read it",
           "A click from 41 to 42 in the counter: one text node is written, nothing else is touched."),
    reconcile=("Keyed lists", "The fewest moves, the cheapest case first",
               "Common ends, one-sided changes and stable order never reach the longest-increasing-run search."),
    selectors=("Compiled selectors", "Only the rows whose inputs changed render",
               "Selecting a row of 1,000 renders two rows, as in Vue Vapor."),
    row=("Memory per row", "One record per row instead of a dozen objects",
         "What one row of a compiled list keeps alive, before and now."),
    events=("Events", "One listener per event type, on document",
            "Handlers live on their elements; React's event objects and semantics are kept."),
    controlled=("Controlled inputs", "Fields always show the state, as in React",
                "After input, a field the update did not take gets the state's value back."),
    hydration=("Server rendering", "Hydration in React's own HTML format",
               "No markers. The server's elements are kept, and clicks made before the code arrives are replayed."),
    served=("A server without a DOM", "One module, two outputs: templates and strings",
            "The same view writes HTML natively or in Node, byte for byte what the browser build expects."),
    updates=("Re-rendering", "Only the component whose state changed renders",
             "Parents are not visited; children with equal props are skipped."),
    hooks=("Hooks", "Every hook call gets a key at compile time",
           "Hooks are slots found by key, and the Rules of Hooks are checked by the type checker."),
    family=("Two front ends, one compiler", "Meltea and Melact share the compiler and the runtime",
            "Pick the Elm architecture for new code, or keep your React code; both compile to the same templates."),
    compiled=("Meltea", "The Elm architecture, compiled like Svelte",
              "Messages, a pure update and a view in mlx; one click writes one text node."),
    fields=("A compiler that sees writers", "It knows what each message changes",
            "So a message that changes nothing the view reads does not even call the view."),
    fanout=("Fanout alerts", "The compiler warns when typing would check a whole list",
            "From the event to the message, the fields it writes and the lists that read them, with no annotations."),
    remember=("Remembered values", "Derived data is computed again only when its fields change",
              "A filtered list stays the same object while its inputs do, so its hole is skipped."),
    hot=("Hot reload", "Edit the code, keep the state",
         "New code takes over the running model when the module's types are the same."),
    transition=("Transitions", "Enter, leave and move: CSS classes or View Transitions",
                "As Vue's Transition and TransitionGroup, plus the browser's own View Transitions on request."),
    roadmap=("Roadmap", "From templates to a release",
             "Every step is checked by property-based laws in CI."),
)

if __name__ == "__main__":
    out = Path(__file__).parent
    for name, draw in FIGURES.items():
        HEADER["current"] = HEADERS.get(name)
        (out / f"{name}.svg").write_text(draw(LIGHT))
        (out / f"{name}-dark.svg").write_text(draw(DARK))
    HEADER["current"] = None
