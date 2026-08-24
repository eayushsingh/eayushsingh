import html

def generate_svg(profile, ascii_lines, stats, theme="dark"):
    """
    Generates a responsive, restrained Neofetch terminal SVG card.
    Theme: 'dark' or 'light'.
    """
    is_dark = (theme == "dark")
    
    c_bg = "#0d1117" if is_dark else "#ffffff"
    c_header_bg = "#161b22" if is_dark else "#f6f8fa"
    c_border = "#30363d" if is_dark else "#d0d7de"
    c_subtle_divider = "#21262d" if is_dark else "#eaeef2"
    c_title = "#8b949e" if is_dark else "#57606a"
    
    c_text = "#c9d1d9" if is_dark else "#24292f"
    c_text_bright = "#f0f6fc" if is_dark else "#1f2328"
    c_dim = "#7d8590" if is_dark else "#656d76"
    c_leader = "#21262d" if is_dark else "#d0d7de"
    
    c_green = "#3fb950" if is_dark else "#1a7f37"
    c_blue = "#58a6ff" if is_dark else "#0969da"
    c_section = "#79c0ff" if is_dark else "#0969da"
    c_ascii = "#c9d1d9" if is_dark else "#24292f"
    
    w = 800
    h = 860
    split_x = 310
    right_x = 330
    
    svg_parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="100%" height="auto">',
        '  <defs>',
        '    <style>',
        "      .term-text {",
        "        font-family: 'JetBrains Mono', 'Fira Code', 'Cascadia Mono', 'SF Mono', Menlo, Monaco, Consolas, monospace;",
        "        font-size: 11.5px;",
        f"        fill: {c_text};",
        "      }",
        "      .title {",
        "        font-family: 'JetBrains Mono', 'Fira Code', 'SF Mono', Menlo, monospace;",
        "        font-size: 11.5px;",
        "        font-weight: 500;",
        f"        fill: {c_title};",
        "      }",
        f"      .accent-blue {{ fill: {c_blue}; font-weight: 500; }}",
        f"      .accent-green {{ fill: {c_green}; font-weight: 600; }}",
        f"      .accent-section {{ fill: {c_section}; font-weight: 600; }}",
        f"      .text-dim {{ fill: {c_dim}; }}",
        f"      .text-leader {{ fill: {c_leader}; }}",
        f"      .text-bright {{ fill: {c_text_bright}; }}",
        "      .ascii-art {",
        "        font-family: 'JetBrains Mono', 'Fira Code', 'SF Mono', Menlo, monospace;",
        "        font-size: 5.2px;",
        "        line-height: 9.8px;",
        f"        fill: {c_ascii};",
        "        white-space: pre;",
        "      }",
        f"      .divider {{ stroke: {c_border}; stroke-width: 1; }}",
        f"      .subtle-divider {{ stroke: {c_subtle_divider}; stroke-width: 1; }}",
        f"      .cursor {{ fill: {c_green}; animation: blink 1s step-end infinite; }}",
        "      @keyframes blink { 0%, 100% { opacity: 1; } 50% { opacity: 0; } }",
        '    </style>',
        '  </defs>',
        '',
        '  <!-- Terminal Window Frame -->',
        f'  <rect x="1" y="1" width="{w-2}" height="{h-2}" rx="6" fill="{c_bg}" stroke="{c_border}" stroke-width="1" />',
        '',
        '  <!-- Minimal Header Bar -->',
        f'  <rect x="1" y="1" width="{w-2}" height="30" rx="6" fill="{c_header_bg}" />',
        f'  <rect x="1" y="19" width="{w-2}" height="12" fill="{c_header_bg}" />',
        f'  <line x1="1" y1="31" x2="{w-1}" y2="31" class="divider" />',
        '',
        '  <!-- Subtle Traffic Lights -->',
        '  <circle cx="16" cy="16" r="3.5" fill="#ff5f56" />',
        '  <circle cx="28" cy="16" r="3.5" fill="#ffbd2e" />',
        '  <circle cx="40" cy="16" r="3.5" fill="#27c93f" />',
        '',
        '  <!-- Terminal Title -->',
        f'  <text x="{w//2}" y="20" text-anchor="middle" class="title">{profile["username"]} ~</text>',
        '',
        '  <!-- Vertical Splitter -->',
        f'  <line x1="{split_x}" y1="31" x2="{split_x}" y2="{h-1}" class="divider" />',
        '',
        '  <!-- ================= LEFT: FULL ASCII PORTRAIT & CONTACT ================= -->',
        '  <g transform="translate(10, 40)">',
        '    <text class="ascii-art" xml:space="preserve">'
    ]

    # Render ASCII lines
    for i, line in enumerate(ascii_lines):
        escaped_line = html.escape(line)
        y_pos = 12 + (i * 9.8)
        svg_parts.append(f'      <tspan x="2" y="{y_pos}">{escaped_line}</tspan>')

    svg_parts.extend([
        '    </text>',
        '  </g>',
        '',
        '  <!-- Left Separator -->',
        f'  <line x1="16" y1="690" x2="{split_x-16}" y2="690" class="subtle-divider" />',
        '',
        '  <!-- Contact Block -->',
        '  <g transform="translate(20, 706)" class="term-text">',
        f'    <text x="0" y="14" class="accent-section">Contact</text>',
        f'    <text x="0" y="26" class="text-dim">──────────────────────</text>'
    ])

    contact_y = 46
    for label, val in profile["contact"]:
        svg_parts.append(f'    <text x="0" y="{contact_y}" class="text-dim">{label}</text>')
        svg_parts.append(f'    <text x="70" y="{contact_y}" class="text-bright">{html.escape(val)}</text>')
        contact_y += 20

    svg_parts.extend([
        '  </g>',
        '',
        '  <!-- ================= RIGHT: NEOFETCH SPECS & STATS ================= -->',
        f'  <g transform="translate({right_x}, 40)" class="term-text">',
        f'    <!-- Identity Header -->',
        f'    <text x="0" y="16" class="accent-green" font-size="13.5" font-weight="600">{profile["username"]}</text>',
        f'    <text x="95" y="16" class="text-dim" font-size="11">@ github</text>',
        f'    <circle cx="158" cy="12" r="3" fill="{c_green}" />',
        f'    <text x="166" y="16" fill="{c_green}" font-size="10">online</text>',
        f'    <text x="0" y="28" class="text-dim">─────────────────────────────────────────────────</text>'
    ])

    cur_y = 46
    # System Info
    for k, v in profile["system"]:
        svg_parts.append(f'    <text x="0" y="{cur_y}" class="accent-blue">{k}</text>')
        svg_parts.append(f'    <text x="85" y="{cur_y}" class="text-bright">{html.escape(v)}</text>')
        cur_y += 18

    # Core Strategy & Architecture
    cur_y += 8
    svg_parts.append(f'    <text x="0" y="{cur_y}" class="accent-section">Core Strategy &amp; Architecture</text>')
    cur_y += 12
    svg_parts.append(f'    <text x="0" y="{cur_y}" class="text-dim">─────────────────────────────────────────────────</text>')
    cur_y += 18
    for item in profile["architecture"]:
        svg_parts.append(f'    <text x="0" y="{cur_y}" class="text-bright">• {html.escape(item)}</text>')
        cur_y += 18

    # AI Systems & Infrastructure
    cur_y += 8
    svg_parts.append(f'    <text x="0" y="{cur_y}" class="accent-section">AI Systems &amp; Infrastructure</text>')
    cur_y += 12
    svg_parts.append(f'    <text x="0" y="{cur_y}" class="text-dim">─────────────────────────────────────────────────</text>')
    cur_y += 18
    for item in profile["ai_systems"]:
        svg_parts.append(f'    <text x="0" y="{cur_y}" class="text-bright">• {html.escape(item)}</text>')
        cur_y += 18

    # GitHub Stats
    cur_y += 8
    svg_parts.append(f'    <text x="0" y="{cur_y}" class="accent-section">GitHub Stats</text>')
    cur_y += 12
    svg_parts.append(f'    <text x="0" y="{cur_y}" class="text-dim">─────────────────────────────────────────────────</text>')
    cur_y += 18

    stat_rows = [
        ("Repos:", stats.get("repos", "46")),
        ("Stars:", stats.get("stars", "1")),
        ("Followers:", stats.get("followers", "13")),
        ("Commits/yr:", stats.get("commits_yr", "LIVE")),
        ("Contribs/yr:", stats.get("contribs_yr", "LIVE"))
    ]

    for label, val in stat_rows:
        svg_parts.append(f'    <text x="0" y="{cur_y}" class="text-dim">{label}</text>')
        svg_parts.append(f'    <text x="100" y="{cur_y}" class="text-leader">································</text>')
        svg_parts.append(f'    <text x="400" y="{cur_y}" class="accent-green">{val}</text>')
        cur_y += 18

    # Terminal cursor on last line
    svg_parts.append(f'    <rect x="440" y="{cur_y-28}" width="6.5" height="12" class="cursor" />')
    svg_parts.extend([
        '  </g>',
        '</svg>'
    ])

    return "\n".join(svg_parts)
