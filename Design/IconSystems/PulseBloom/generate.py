#!/usr/bin/env python3
"""Generate the Pulse Bloom SVG icon family preview and editable source files."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent
ICONS = ROOT / "icons"
ICONS.mkdir(parents=True, exist_ok=True)


STYLE = """
  .ink { fill:#1B1730; }
  .soft { fill:#3A315D; }
  .mint { fill:#66E8B4; }
  .coral { fill:#FF728E; }
  .violet { fill:#8D7CFF; }
  .paper { fill:#F7F5FF; }
  .line { fill:none; stroke:#1B1730; stroke-width:2.15; stroke-linecap:round; stroke-linejoin:round; }
  .line-soft { fill:none; stroke:#3A315D; stroke-width:1.55; stroke-linecap:round; stroke-linejoin:round; }
"""


# The family intentionally avoids SF-like uniform outlines. Every mark combines a
# weighted organic silhouette, one open counter-shape and a small "signal seed".
ICON_BODIES: dict[str, str] = {
    "home": '''<path class="ink" d="M3.2 10.7 11 3.9c.6-.5 1.4-.5 2 0l7.8 6.8c.6.5.3 1.5-.5 1.6l-1.3.2v6c0 1.1-.9 2-2 2h-3.2v-5.3c0-1-.8-1.8-1.8-1.8s-1.8.8-1.8 1.8v5.3H7c-1.1 0-2-.9-2-2v-6l-1.3-.2c-.8-.1-1.1-1.1-.5-1.6Z"/><circle class="mint" cx="17.8" cy="7.4" r="1.7"/>''',
    "podcast": '''<path class="ink" d="M12 3.2a7.7 7.7 0 0 0-4.8 13.7l1.6-2.1a5 5 0 1 1 6.4 0l1.6 2.1A7.7 7.7 0 0 0 12 3.2Z"/><path class="soft" d="M12 7.1a3.7 3.7 0 0 0-2 6.8l1.2-1.7a1.7 1.7 0 1 1 1.6 0l1.2 1.7a3.7 3.7 0 0 0-2-6.8Z"/><path class="violet" d="m9.7 20.7 1.1-7.2h2.4l1.1 7.2a1.5 1.5 0 0 1-1.5 1.8h-1.6a1.5 1.5 0 0 1-1.5-1.8Z"/>''',
    "library": '''<path class="ink" d="M3.4 5.2c0-1 .8-1.8 1.8-1.8h3.1c1 0 1.8.8 1.8 1.8v13.6c0 1-.8 1.8-1.8 1.8H5.2c-1 0-1.8-.8-1.8-1.8V5.2Z"/><path class="soft" d="M11.2 4.7c0-.9.7-1.6 1.6-1.6h1.8c.9 0 1.6.7 1.6 1.6v14.6c0 .9-.7 1.6-1.6 1.6h-1.8c-.9 0-1.6-.7-1.6-1.6V4.7Z"/><path class="violet" d="m17 5 2.6-.8c.8-.2 1.6.3 1.8 1.1l2.7 12.2c.2.8-.3 1.6-1.1 1.8l-2.6.6L17 5Z"/><circle class="coral" cx="6.8" cy="16.9" r="1.35"/>''',
    "search": '''<path class="ink" fill-rule="evenodd" d="M10.4 3.1a7.3 7.3 0 1 0 3.9 13.5l4.1 4.1a1.7 1.7 0 0 0 2.4-2.4l-4.1-4.1a7.3 7.3 0 0 0-6.3-11.1Zm0 3.1a4.2 4.2 0 1 1 0 8.4 4.2 4.2 0 0 1 0-8.4Z"/><circle class="mint" cx="15.8" cy="7.4" r="1.55"/>''',
    "profile": '''<path class="ink" d="M12 3.1c-2.7 0-4.7 2.1-4.5 4.8.2 2.8 2.1 4.8 4.5 4.8s4.3-2 4.5-4.8c.2-2.7-1.8-4.8-4.5-4.8Z"/><path class="soft" d="M4 20.8c.3-4.4 3.3-7 8-7s7.7 2.6 8 7c.1.7-.5 1.2-1.1 1.2H5.1c-.6 0-1.2-.5-1.1-1.2Z"/><path class="coral" d="M16.4 14.7c1.7.9 2.9 2.4 3.4 4.5l-3.2.7c-.3-1.7-1.1-3-2.4-3.9l2.2-1.3Z"/>''',
    "settings": '''<circle class="ink" cx="12" cy="12" r="3.8"/><path class="line" d="M12 2.8c2.6 0 3.1 2.7 4.6 3.5 1.6.9 4.1-.1 4.5 2.4.4 2.4-2.1 3.2-2.1 4.9 0 1.7 2.4 3 1.2 5.1-1.2 2-3.5.5-5 .9-1.4.4-2 2.9-4.5 2.3-2.4-.6-1.7-3.2-2.9-4.2-1.3-1-3.9-.1-4.5-2.5-.6-2.3 1.9-3.4 2.1-5 .2-1.6-2-3.1-.5-5 1.6-1.9 3.7-.1 5.2-.5C11.5 4.3 10 2.8 12 2.8Z"/><circle class="mint" cx="18.1" cy="5.5" r="1.55"/>''',
    "back": '''<path class="ink" d="M4.1 11.1 12.7 3c.8-.7 2-.6 2.6.2.6.8.5 1.9-.2 2.6l-4.2 3.9h7.4a2.3 2.3 0 1 1 0 4.6h-7.4l4.2 3.9c.7.7.8 1.8.2 2.6-.6.8-1.8.9-2.6.2l-8.6-8.1a1.2 1.2 0 0 1 0-1.8Z"/><circle class="coral" cx="5.5" cy="12" r="1.15"/>''',
    "more": '''<path class="soft" d="M3.2 13.2c-.8-1-.6-2.5.4-3.3 1-.8 2.5-.6 3.3.4.8 1 .6 2.5-.4 3.3-1 .8-2.5.6-3.3-.4Z"/><path class="ink" d="M9.7 13.7a2.8 2.8 0 1 1 4.6-3.4 2.8 2.8 0 0 1-4.6 3.4Z"/><path class="violet" d="M17 14.1a3.2 3.2 0 1 1 5-4 3.2 3.2 0 0 1-5 4Z"/>''',
    "play": '''<path class="ink" d="M6.2 5.4c0-1.7 1.8-2.7 3.3-1.8l10 6.6c1.3.9 1.3 2.8 0 3.6l-10 6.6c-1.4.9-3.3-.1-3.3-1.8V5.4Z"/><path class="mint" d="M9.5 8.3v7.4l5.7-3.7-5.7-3.7Z"/>''',
    "pause": '''<path class="ink" d="M5.2 5.3c0-1.3 1-2.3 2.3-2.3h1.2C10 3 11 4 11 5.3v13.4C11 20 10 21 8.7 21H7.5a2.3 2.3 0 0 1-2.3-2.3V5.3Z"/><path class="soft" d="M13 5.3C13 4 14 3 15.3 3h1.2c1.3 0 2.3 1 2.3 2.3v13.4c0 1.3-1 2.3-2.3 2.3h-1.2a2.3 2.3 0 0 1-2.3-2.3V5.3Z"/><circle class="coral" cx="17.3" cy="5.1" r="1.25"/>''',
    "next": '''<path class="ink" d="M3.8 6.2c0-1.5 1.7-2.4 3-1.6l7.2 5c1.1.8 1.1 2.5 0 3.2l-7.2 4.9c-1.3.8-3-.1-3-1.6V6.2Z"/><path class="soft" d="M12 6.3c0-1.5 1.7-2.4 2.9-1.6l4.9 3.4v8l-4.9 3.4c-1.2.8-2.9-.1-2.9-1.6V6.3Z"/><rect class="violet" x="19" y="4" width="2.3" height="16" rx="1.15"/>''',
    "previous": '''<g transform="translate(24 0) scale(-1 1)"><path class="ink" d="M3.8 6.2c0-1.5 1.7-2.4 3-1.6l7.2 5c1.1.8 1.1 2.5 0 3.2l-7.2 4.9c-1.3.8-3-.1-3-1.6V6.2Z"/><path class="soft" d="M12 6.3c0-1.5 1.7-2.4 2.9-1.6l4.9 3.4v8l-4.9 3.4c-1.2.8-2.9-.1-2.9-1.6V6.3Z"/><rect class="violet" x="19" y="4" width="2.3" height="16" rx="1.15"/></g>''',
    "shuffle": '''<path class="line" d="M3.4 6.4h2.2c5.7 0 6.8 11.2 12.7 11.2h2.3M17.3 14.6l3.3 3-3.3 3M3.4 17.6h2.2c2.3 0 3.7-1.8 5-4M14.6 7.7c1-.8 2.2-1.3 3.7-1.3h2.3M17.3 3.4l3.3 3-3.3 3"/><circle class="coral" cx="11.7" cy="11.5" r="1.4"/>''',
    "repeat": '''<path class="line" d="M5.1 7.1A7.8 7.8 0 0 1 18 5.8l2.1 2M20.1 4.1v3.7h-3.7M18.9 16.9A7.8 7.8 0 0 1 6 18.2l-2.1-2M3.9 19.9v-3.7h3.7"/><path class="violet" d="M9.5 9.1h3.4v6.2h2v2H9.5v-2h1.3v-4.1H9.5V9.1Z"/>''',
    "queue": '''<path class="ink" d="M3.3 5.1c0-1 .8-1.8 1.8-1.8h11c1 0 1.8.8 1.8 1.8v.5c0 1-.8 1.8-1.8 1.8h-11c-1 0-1.8-.8-1.8-1.8v-.5ZM3.3 11.8c0-1 .8-1.8 1.8-1.8h8.2c1 0 1.8.8 1.8 1.8v.5c0 1-.8 1.8-1.8 1.8H5.1c-1 0-1.8-.8-1.8-1.8v-.5ZM3.3 18.5c0-1 .8-1.8 1.8-1.8h5c1 0 1.8.8 1.8 1.8v.5c0 1-.8 1.8-1.8 1.8h-5c-1 0-1.8-.8-1.8-1.8v-.5Z"/><path class="mint" d="m16.4 14.5 4.4 2.8a1.1 1.1 0 0 1 0 1.9L16.4 22c-.8.5-1.8-.1-1.8-1v-5.6c0-.9 1-1.4 1.8-.9Z"/>''',
    "waveform": '''<path class="ink" d="M2.8 10.2c0-1.1.9-2 2-2s2 .9 2 2v3.6a2 2 0 1 1-4 0v-3.6ZM8.2 6.7a2 2 0 0 1 4 0v10.6a2 2 0 1 1-4 0V6.7Z"/><path class="violet" d="M13.7 9a2 2 0 0 1 4 0v6a2 2 0 1 1-4 0V9Z"/><path class="coral" d="M19.1 11.2a2 2 0 0 1 4 0v1.6a2 2 0 1 1-4 0v-1.6Z"/>''',
    "like": '''<path class="ink" d="M12 21.2C9.3 18.8 3.1 14.7 3.1 9.1c0-3.4 2.1-5.6 5.1-5.6 1.9 0 3.2 1 3.8 2.2.6-1.2 1.9-2.2 3.8-2.2 3 0 5.1 2.2 5.1 5.6 0 5.6-6.2 9.7-8.9 12.1Z"/><path class="coral" d="M15.4 5.9c2.1-.1 3.4 1.2 3.2 3.4-.2 1.6-1.1 2.8-2.6 4.2.8-3.4-.2-5.4-2.5-6.2.5-.8 1.1-1.3 1.9-1.4Z"/>''',
    "download": '''<path class="ink" d="M9.6 3.3c0-1 .8-1.8 1.8-1.8h1.2c1 0 1.8.8 1.8 1.8v8l2-2c.7-.7 1.8-.7 2.5 0 .7.7.7 1.8 0 2.5l-5.6 5.6c-.7.7-1.9.7-2.6 0l-5.6-5.6a1.8 1.8 0 0 1 2.5-2.5l2 2v-8Z"/><path class="violet" d="M3.1 18.1c0-1 .8-1.8 1.8-1.8h1.3c.6 1.7 2.1 2.9 4 3.2 1.2.2 2.4.2 3.6 0 1.9-.3 3.4-1.5 4-3.2h1.3c1 0 1.8.8 1.8 1.8v2.1c0 1.3-1 2.3-2.3 2.3H5.4c-1.3 0-2.3-1-2.3-2.3v-2.1Z"/>''',
    "share": '''<path class="line" d="m8.5 12.7 7-4.1M8.5 13.8l7 4"/><circle class="ink" cx="6.1" cy="13.2" r="3.2"/><circle class="violet" cx="17.9" cy="6.8" r="3.2"/><circle class="soft" cx="17.9" cy="19.2" r="3.2"/><circle class="mint" cx="18.7" cy="5.9" r="1"/>''',
    "add": '''<path class="ink" d="M9.6 3.8a2.4 2.4 0 0 1 4.8 0v5.8h5.8a2.4 2.4 0 1 1 0 4.8h-5.8v5.8a2.4 2.4 0 1 1-4.8 0v-5.8H3.8a2.4 2.4 0 1 1 0-4.8h5.8V3.8Z"/><circle class="mint" cx="17.9" cy="6.1" r="1.5"/>''',
    "comment": '''<path class="ink" d="M3 5.5C3 3.6 4.6 2 6.5 2h11C19.4 2 21 3.6 21 5.5v8.1c0 1.9-1.6 3.5-3.5 3.5h-5.4l-4.8 4.1c-.8.7-2.1.1-2.1-1v-3.4A3.5 3.5 0 0 1 3 13.6V5.5Z"/><path class="mint" d="M7 7h10v2.2H7V7Zm0 4.1h6.4v2.2H7v-2.2Z"/>''',
    "bell": '''<path class="ink" d="M5.2 16.3h13.6c1.1 0 1.7-1.3 1-2.1l-1.5-1.7V9.4c0-3.3-2.1-5.8-5-6.3V2a1.3 1.3 0 0 0-2.6 0v1.1c-2.9.5-5 3-5 6.3v3.1l-1.5 1.7c-.7.8-.1 2.1 1 2.1Z"/><path class="soft" d="M8.8 18h6.4c-.2 2-1.4 3.4-3.2 3.4S9 20 8.8 18Z"/><circle class="coral" cx="18.8" cy="5.1" r="2"/>''',
    "filter": '''<path class="ink" d="M3 4.2c0-1 .8-1.8 1.8-1.8h14.4c1.6 0 2.4 1.9 1.3 3l-5.4 5.7v6.5c0 .6-.3 1.2-.8 1.5l-3.6 2.3c-1.2.8-2.7-.1-2.7-1.5v-8.8L3.5 5.4A1.8 1.8 0 0 1 3 4.2Z"/><path class="mint" d="m14 4.9 3.3-.1-4.8 5.1v7.4l-1.8 1.1V9.8L6.8 4.9H14Z"/>''',
    "headphones": '''<path class="line" d="M4.2 13.1V10a7.8 7.8 0 0 1 15.6 0v3.1"/><path class="ink" d="M3 12.1c0-1 .8-1.8 1.8-1.8h1.1c1.1 0 2 .9 2 2v6.1c0 1.8-1.4 3.2-3.2 3.2A1.7 1.7 0 0 1 3 19.9v-7.8Z"/><path class="violet" d="M16.1 12.3c0-1.1.9-2 2-2h1.1c1 0 1.8.8 1.8 1.8v7.8c0 .9-.8 1.7-1.7 1.7-1.8 0-3.2-1.4-3.2-3.2v-6.1Z"/><circle class="coral" cx="18.7" cy="17.9" r="1.1"/>''',
    "equalizer": '''<rect class="ink" x="3" y="3" width="3.8" height="18" rx="1.9"/><rect class="soft" x="10.1" y="3" width="3.8" height="18" rx="1.9"/><rect class="violet" x="17.2" y="3" width="3.8" height="18" rx="1.9"/><circle class="mint" cx="4.9" cy="8" r="3"/><circle class="coral" cx="12" cy="15.8" r="3"/><circle class="paper" cx="19.1" cy="10.8" r="2.2"/>''',
    "immersive": '''<path class="line" d="M3.1 12c0-5 3.9-9 8.9-9 4.3 0 7.9 3 8.7 7.1M20.9 12c0 5-3.9 9-8.9 9-4.3 0-7.9-3-8.7-7.1"/><path class="line-soft" d="M6.5 12A5.5 5.5 0 0 1 12 6.5c2.3 0 4.3 1.4 5.1 3.4M17.5 12A5.5 5.5 0 0 1 12 17.5a5.5 5.5 0 0 1-5.1-3.4"/><circle class="violet" cx="12" cy="12" r="2.35"/><circle class="mint" cx="20.5" cy="10" r="1.35"/>''',
    "microphone": '''<path class="ink" d="M8 5a4 4 0 1 1 8 0v6.2a4 4 0 1 1-8 0V5Z"/><path class="line" d="M4.8 10.2v1.1a7.2 7.2 0 0 0 14.4 0v-1.1M12 18.5v3M8.5 21.5h7"/><path class="coral" d="M10.1 5.2h3.8v2h-3.8z"/>''',
    "karaoke": '''<path class="ink" d="M14.4 3.1a4.9 4.9 0 0 1 6.5 6.5l-2.2 3-7.3-7.3 3-2.2Z"/><path class="soft" d="m10.1 6.6 7.3 7.3-2.1 2.1-2.1-.5-6 6c-.7.7-1.9.7-2.6 0l-2.1-2.1c-.7-.7-.7-1.9 0-2.6l6-6-.5-2.1 2.1-2.1Z"/><path class="mint" d="m18.4 2 .8 1.9 1.9.8-1.9.8-.8 1.9-.8-1.9-1.9-.8 1.9-.8.8-1.9Z"/>''',
    "radio": '''<rect class="ink" x="2.5" y="6.4" width="19" height="14.2" rx="3"/><path class="line" d="m7.2 6.4 8.7-4"/><circle class="paper" cx="8.1" cy="13.8" r="3.4"/><circle class="violet" cx="8.1" cy="13.8" r="1.35"/><rect class="mint" x="13" y="10.2" width="5.8" height="2.2" rx="1.1"/><rect class="coral" x="13" y="14.1" width="3.8" height="2.2" rx="1.1"/>''',
    "quality": '''<path class="ink" d="m12 2.1 8.6 5v9.8l-8.6 5-8.6-5V7.1l8.6-5Z"/><path class="mint" d="M7.2 14.8c1.4-3.2 2.7-4.5 4-3.9 1.5.7 2.2 1 3.2-2.4l2.4 1c-1.6 3.8-3.7 5.2-6 4.1-.2-.1-.5.2-1.2 2l-2.4-.8Z"/><circle class="coral" cx="17.4" cy="6.5" r="1.4"/>''',
    "storage": '''<ellipse class="ink" cx="12" cy="5.5" rx="8.6" ry="3.4"/><path class="soft" d="M3.4 6.2v5.3c0 1.9 3.9 3.4 8.6 3.4s8.6-1.5 8.6-3.4V6.2C19.3 8 16 9 12 9S4.7 8 3.4 6.2Z"/><path class="violet" d="M3.4 12.1v5.4c0 1.9 3.9 3.4 8.6 3.4s8.6-1.5 8.6-3.4v-5.4c-1.3 1.8-4.6 2.8-8.6 2.8s-7.3-1-8.6-2.8Z"/><circle class="mint" cx="17.4" cy="17.3" r="1.2"/>''',
    "cloud": '''<path class="ink" d="M7.4 19.6h10.2a5.2 5.2 0 0 0 .5-10.4A6.7 6.7 0 0 0 5.4 8a5.9 5.9 0 0 0 2 11.6Z"/><path class="mint" d="m9.5 13 2.5-2.5 2.5 2.5h-1.3v3.6h-2.4V13H9.5Z"/>''',
    "clock": '''<circle class="ink" cx="12" cy="12" r="9.6"/><path class="paper" d="M10.9 6.2h2.2v5.2l4 2.3-1.1 1.9-5.1-3V6.2Z"/><circle class="coral" cx="18.4" cy="6.1" r="1.4"/>''',
    "history": '''<path class="line" d="M5.1 7.1a8.8 8.8 0 1 1-1.8 7.7M3.2 5.1v4.7h4.7"/><path class="ink" d="M10.9 7h2.2v5.3l3.7 2.1-1.1 1.9-4.8-2.8V7Z"/><circle class="mint" cx="3.3" cy="14.8" r="1.3"/>''',
    "lock": '''<path class="line" d="M7.2 10V7.2a4.8 4.8 0 0 1 9.6 0V10"/><rect class="ink" x="4" y="9" width="16" height="13" rx="3"/><path class="mint" d="M10.6 14.1a2 2 0 1 1 2.8 1.8v2.8h-2.8v-2.8a2 2 0 0 1 0-1.8Z"/>''',
    "translate": '''<path class="ink" d="M3.1 3.2h8.8v3H9.4c-.4 2.2-1.2 4.2-2.4 5.9l2.4 2.1-1.9 2.2-2.4-2.1c-.7.7-1.6 1.4-2.5 2L1 13.8c.8-.5 1.5-1 2.1-1.6l-1.5-1.4 1.9-2.1 1.4 1.2c.7-1 1.2-2.3 1.5-3.7H3.1v-3Z"/><path class="violet" d="M14.8 7.4h3.1l5.1 13.4h-3.4l-1-2.9h-4.8l-1 2.9H9.5l5.3-13.4Zm0 7.8h2.9l-1.4-4.2-1.5 4.2Z"/><circle class="coral" cx="20.4" cy="5.4" r="1.3"/>''',
    "sparkle": '''<path class="ink" d="m11.4 1.8 1.7 6 5.4 2.8-5.4 2.8-1.7 6-1.8-6-5.4-2.8 5.4-2.8 1.8-6Z"/><path class="violet" d="m18.5 13.5.8 2.7 2.5 1.3-2.5 1.3-.8 2.8-.8-2.8-2.5-1.3 2.5-1.3.8-2.7Z"/><circle class="mint" cx="4.1" cy="18.9" r="1.55"/>''',
    "music": '''<path class="ink" d="M9.3 4.6 20 2.2v13.4a4.2 4.2 0 1 1-3-4V6.4L9.3 8.1v9.1a4.2 4.2 0 1 1-3-4V6.8c0-1.1.7-2 1.8-2.2h1.2Z"/><path class="mint" d="M9.3 5.8 17 4.1v2.3L9.3 8.1V5.8Z"/>''',
    "emotion": '''<path class="ink" d="M12 21c5 0 9-4 9-9s-4-9-9-9-9 4-9 9 4 9 9 9Z"/><circle class="mint" cx="8.5" cy="9.4" r="1.6"/><circle class="coral" cx="15.5" cy="9.4" r="1.6"/><path class="paper" d="M7.6 14.1c1.1 1.8 2.5 2.7 4.4 2.7s3.3-.9 4.4-2.7l-1.9-1.2c-.7 1-1.5 1.5-2.5 1.5s-1.8-.5-2.5-1.5l-1.9 1.2Z"/>''',
    "electronic": '''<path class="ink" d="M10.1 2.2 4.7 12h5l-1.1 9.8L19.3 10h-5.1l1.1-7.8h-5.2Z"/><path class="violet" d="m12.5 7.2-2 4.8h2.7l-.5 4.3 4-4.5h-2.9l.7-4.6h-2Z"/><circle class="mint" cx="5.1" cy="17.8" r="1.5"/>''',
    "book": '''<path class="ink" d="M3 4.8C3 3.8 3.8 3 4.8 3H10c1.1 0 2 .4 2.7 1.2V20c-.7-.8-1.6-1.2-2.7-1.2H4.8C3.8 18.8 3 18 3 17V4.8Z"/><path class="soft" d="M21 4.8C21 3.8 20.2 3 19.2 3H14c-1.1 0-2 .4-2.7 1.2V20c.7-.8 1.6-1.2 2.7-1.2h5.2c1 0 1.8-.8 1.8-1.8V4.8Z"/><path class="mint" d="M15 6h3.5v2.2H15V6Z"/>''',
    "tech": '''<rect class="ink" x="4" y="4" width="16" height="16" rx="4"/><path class="line" d="M8 1.5v3M12 1.5v3M16 1.5v3M8 19.5v3M12 19.5v3M16 19.5v3M1.5 8h3M1.5 12h3M1.5 16h3M19.5 8h3M19.5 12h3M19.5 16h3"/><path class="violet" d="M8 8h8v8H8z"/><circle class="mint" cx="12" cy="12" r="2.1"/>''',
    "travel": '''<path class="ink" d="m11.2 2.2 3.3.9-1.2 6.1 7 2.8c.8.3 1.2 1.1 1 1.9l-.4 1.4-8.7-1.4-2.5 6.6c-.3.7-1 1.1-1.7.9L6.3 21l.7-7.9-4.4-2.3.5-2 5.3.8 2.8-7.4Z"/><circle class="coral" cx="18.6" cy="6" r="1.45"/>''',
    "food": '''<path class="ink" d="M4 2.5h2v7h1.3v-7h2v7h1.3v-7h2v6.4c0 2.2-1.3 3.8-3.3 4.4v8.2H6.6v-8.2c-2-.6-3.3-2.2-3.3-4.4V2.5H4Z"/><path class="violet" d="M16.4 2.5c2.5 1 4.3 3.8 4.3 7.3 0 2.7-1.1 4.3-2.5 5v6.7h-2.8v-19h1Z"/><circle class="mint" cx="19.2" cy="17.7" r="1.2"/>''',
    "news": '''<path class="ink" d="M3 4.3C3 3 4 2 5.3 2h11.4C18 2 19 3 19 4.3V7h1.3c1 0 1.7.8 1.7 1.7v9.1c0 2.3-1.9 4.2-4.2 4.2H6.2A3.2 3.2 0 0 1 3 18.8V4.3Z"/><path class="mint" d="M6.2 5.2h9.6v3H6.2v-3Z"/><path class="paper" d="M6.2 11h4v6.8h-4V11Zm5.8 0h3.8v2.2H12V11Zm0 4.1h3.8v2.2H12v-2.2Z"/>''',
    "warning": '''<path class="ink" d="M10.1 3.1c.8-1.4 2.9-1.4 3.8 0l8.3 14.4c.8 1.4-.2 3.2-1.9 3.2H3.7c-1.7 0-2.7-1.8-1.9-3.2l8.3-14.4Z"/><rect class="paper" x="10.6" y="7" width="2.8" height="7.8" rx="1.4"/><circle class="coral" cx="12" cy="17.7" r="1.5"/>''',
    "check": '''<path class="ink" d="M12 2.2a9.8 9.8 0 1 0 0 19.6 9.8 9.8 0 0 0 0-19.6Z"/><path class="mint" d="m6.6 12.3 2.5-2 2.1 2.6 5.9-6 2.1 2.1-8.3 8.3-4.3-5Z"/>''',
    "close": '''<path class="ink" d="M5.1 3.4 12 10.3l6.9-6.9 1.7 1.7-6.9 6.9 6.9 6.9-1.7 1.7-6.9-6.9-6.9 6.9-1.7-1.7 6.9-6.9-6.9-6.9 1.7-1.7Z"/><circle class="coral" cx="18.8" cy="5.2" r="1.55"/>''',
    "grid": '''<path class="ink" d="M3 3h7.8v7.8H3V3Zm10.2 0H21v7.8h-7.8V3ZM3 13.2h7.8V21H3v-7.8Z"/><path class="violet" d="M13.2 13.2H21V21h-7.8v-7.8Z"/><circle class="mint" cx="17.1" cy="17.1" r="1.6"/>''',
    "listening": '''<path class="line" d="M4 13a8 8 0 0 1 16 0"/><path class="ink" d="M3 12h4.2v7.5c-2.3 0-4.2-1.9-4.2-4.2V12Zm14 0h4v3.3c0 2.3-1.9 4.2-4.2 4.2V12h.2Z"/><path class="violet" d="M9.1 9.2a3.9 3.9 0 0 1 5.8 0l-1.8 1.7a1.5 1.5 0 0 0-2.2 0L9.1 9.2Z"/><circle class="coral" cx="12" cy="13" r="1.5"/>''',
    "lyrics": '''<path class="ink" d="M3.2 4.5c0-1.2 1-2.2 2.2-2.2h13.2c1.2 0 2.2 1 2.2 2.2v10.2c0 1.2-1 2.2-2.2 2.2h-6.2l-4.5 4.2c-.7.7-2 .2-2- .9v-3.5a2.2 2.2 0 0 1-2.7-2.1V4.5Z"/><path class="mint" d="M7 6h10v2.3H7V6Zm0 4.4h7.2v2.3H7v-2.3Z"/><circle class="coral" cx="17.5" cy="13.2" r="1.4"/>''',
    "palette": '''<path class="ink" d="M12 2.2a9.8 9.8 0 0 0 0 19.6h1.6c1.4 0 2.2-1.5 1.4-2.7-.8-1.2.1-2.8 1.5-2.8h1.1c2.5 0 4.4-2.2 4.2-4.7A9.8 9.8 0 0 0 12 2.2Z"/><circle class="mint" cx="7.2" cy="9" r="1.6"/><circle class="coral" cx="10.2" cy="5.9" r="1.6"/><circle class="violet" cx="15" cy="6.2" r="1.6"/><circle class="paper" cx="17.8" cy="10.2" r="1.6"/>''',
    "playerTheme": '''<path class="ink" d="M4.2 2.8h15.6c1.1 0 2 .9 2 2v11.6c0 1.1-.9 2-2 2h-5.1l-1.5 2.5c-.5.8-1.7.8-2.2 0l-1.5-2.5H4.2c-1.1 0-2-.9-2-2V4.8c0-1.1.9-2 2-2Z"/><path class="mint" d="M9.4 7.1c0-1.1 1.2-1.8 2.2-1.2l4.7 3c.9.6.9 1.9 0 2.5l-4.7 3c-1 .6-2.2-.1-2.2-1.2V7.1Z"/><circle class="coral" cx="18.6" cy="5.8" r="1.3"/>''',
    "haptic": '''<path class="ink" d="M8.2 4.3c0-1.1.9-2 2-2h3.6c1.1 0 2 .9 2 2v15.4c0 1.1-.9 2-2 2h-3.6c-1.1 0-2-.9-2-2V4.3Z"/><path class="line" d="M4.7 7.2 2.8 5.3M4.1 11.9H1.4M4.7 16.7l-1.9 1.9M19.3 7.2l1.9-1.9M19.9 11.9h2.7M19.3 16.7l1.9 1.9"/><circle class="violet" cx="12" cy="12" r="2.2"/>''',
    "fullscreen": '''<path class="ink" d="M3 3h7v3.2H6.2V10H3V3Zm11 0h7v7h-3.2V6.2H14V3ZM3 14h3.2v3.8H10V21H3v-7Zm14.8 0H21v7h-7v-3.2h3.8V14Z"/><circle class="mint" cx="12" cy="12" r="1.7"/>''',
    "refresh": '''<path class="line" d="M19.7 8.2A8.4 8.4 0 1 0 20 15"/><path class="ink" d="m15.3 3.5 5 .9-.9 5-4.1-5.9Z"/><circle class="coral" cx="19.8" cy="15.2" r="1.6"/>''',
}


# Long-tail application semantics. These are drawn with the same weighted
# silhouette / open-counter / signal-seed grammar rather than falling back to
# generic system symbols.
ICON_BODIES.update({
    "stop": '''<path class="ink" d="M5.2 3h13.6C20 3 21 4 21 5.2v13.6C21 20 20 21 18.8 21H5.2C4 21 3 20 3 18.8V5.2C3 4 4 3 5.2 3Z"/><path class="violet" d="M8 8h8v8H8z"/><circle class="mint" cx="17.8" cy="6.2" r="1.4"/>''',
    "liked": '''<path class="coral" d="M12 21.2C9.3 18.8 3.1 14.7 3.1 9.1c0-3.4 2.1-5.6 5.1-5.6 1.9 0 3.2 1 3.8 2.2.6-1.2 1.9-2.2 3.8-2.2 3 0 5.1 2.2 5.1 5.6 0 5.6-6.2 9.7-8.9 12.1Z"/><path class="ink" d="m7.2 11.5 2.3-1.8 2 2.5 5.1-5.1 1.9 1.9-7.3 7.2-4-4.7Z"/>''',
    "trash": '''<path class="ink" d="M5.1 7h13.8l-1 12.7c-.1 1.3-1.2 2.3-2.5 2.3H8.6c-1.3 0-2.4-1-2.5-2.3L5.1 7Z"/><path class="soft" d="M8.1 3.7C8.1 2.8 8.9 2 9.8 2h4.4c.9 0 1.7.8 1.7 1.7v.8h3.4v2.6H4.7V4.5h3.4v-.8Zm2.6.8h2.6v-.4h-2.6v.4Z"/><path class="coral" d="M9 10h2v7.8H9V10Zm4 0h2v7.8h-2V10Z"/>''',
    "fm": '''<path class="ink" d="M3.2 6.8c0-1.2 1-2.2 2.2-2.2h13.2c1.2 0 2.2 1 2.2 2.2v11.4c0 1.2-1 2.2-2.2 2.2H5.4c-1.2 0-2.2-1-2.2-2.2V6.8Z"/><path class="line" d="m7 4.6 8.8-2.8"/><circle class="paper" cx="8" cy="12.6" r="3.4"/><path class="violet" d="M13.2 9h4.5v2.1h-2.4v1.5h2v2h-2V17h-2.1V9Z"/><circle class="mint" cx="8" cy="12.6" r="1.3"/>''',
    "chevronRight": '''<path class="ink" d="m7.3 4.6 2.6-2.1 8.2 8.4c.6.6.6 1.6 0 2.2l-8.2 8.4-2.6-2.1 7.2-7.4-7.2-7.4Z"/><circle class="mint" cx="17.7" cy="12" r="1.3"/>''',
    "chevronLeft": '''<g transform="translate(24 0) scale(-1 1)"><path class="ink" d="m7.3 4.6 2.6-2.1 8.2 8.4c.6.6.6 1.6 0 2.2l-8.2 8.4-2.6-2.1 7.2-7.4-7.2-7.4Z"/><circle class="mint" cx="17.7" cy="12" r="1.3"/></g>''',
    "chevronDown": '''<g transform="rotate(90 12 12)"><path class="ink" d="m7.3 4.6 2.6-2.1 8.2 8.4c.6.6.6 1.6 0 2.2l-8.2 8.4-2.6-2.1 7.2-7.4-7.2-7.4Z"/><circle class="mint" cx="17.7" cy="12" r="1.3"/></g>''',
    "chevronUp": '''<g transform="rotate(-90 12 12)"><path class="ink" d="m7.3 4.6 2.6-2.1 8.2 8.4c.6.6.6 1.6 0 2.2l-8.2 8.4-2.6-2.1 7.2-7.4-7.2-7.4Z"/><circle class="mint" cx="17.7" cy="12" r="1.3"/></g>''',
    "info": '''<path class="ink" d="M10.1 9h3.8v10h2v2H8.1v-2h2V11h-2V9h2Zm1.9-7a2.5 2.5 0 1 1 0 5 2.5 2.5 0 0 1 0-5Z"/><circle class="mint" cx="12.8" cy="3.9" r=".8"/>''',
    "chart": '''<path class="line" d="M3 20.5h18"/><path class="ink" d="M4 12.6h3.8v7.9H4v-7.9Z"/><path class="soft" d="M10.1 7.8h3.8v12.7h-3.8V7.8Z"/><path class="violet" d="M16.2 3h3.8v17.5h-3.8V3Z"/><circle class="coral" cx="18.1" cy="5.1" r="1.2"/>''',
    "unlock": '''<path class="line" d="M8 10V7.3a4.8 4.8 0 0 1 9-2.3"/><rect class="ink" x="4" y="9" width="16" height="13" rx="3"/><path class="mint" d="M10.6 14.1a2 2 0 1 1 2.8 1.8v2.8h-2.8v-2.8a2 2 0 0 1 0-1.8Z"/><circle class="coral" cx="18" cy="4.6" r="1.4"/>''',
    "qr": '''<path class="ink" fill-rule="evenodd" d="M2.5 2.5h8v8h-8v-8Zm2.5 2.5v3h3V5H5Zm8.5-2.5h8v8h-8v-8ZM16 5v3h3V5h-3ZM2.5 13.5h8v8h-8v-8ZM5 16v3h3v-3H5Z"/><path class="violet" d="M13.5 13.5h3V16h2.5v-2.5h2.5v5H19v3h-5.5v-3H16V16h-2.5v-2.5Z"/><circle class="mint" cx="20.1" cy="20.1" r="1.4"/>''',
    "phone": '''<path class="ink" d="M6.1 2.8c.8-.5 1.9-.2 2.4.6l2.1 3.7c.4.7.3 1.5-.2 2.1L8.8 11c1.1 2.1 2.8 3.8 4.9 4.9l1.8-1.6c.6-.5 1.4-.6 2.1-.2l3.7 2.1c.8.5 1.1 1.6.6 2.4l-1.5 2.5c-.4.7-1.2 1.1-2 1C9.7 21.1 2.9 14.3 2 5.6c-.1-.8.3-1.6 1-2l3.1-1.8v1Z"/><circle class="mint" cx="18.7" cy="18.3" r="1.3"/>''',
    "send": '''<path class="ink" d="M2.7 5.5c-.8-.4-.7-1.6.2-1.9l18-2.1c.8-.1 1.5.6 1.4 1.4l-2.1 18c-.1.9-1.3 1.1-1.8.3l-5.1-7.4-4.1 3.6-2.1-2.1 3.7-4-8.1-5.8Z"/><path class="mint" d="m12.1 10.2 6.1-5-4.8 6.4-1.3-1.4Z"/>''',
    "musicNote": '''<path class="ink" d="M10 4.4 20.5 2v13.4a4.1 4.1 0 1 1-3-3.9V6.1L10 7.8v9.3a4.1 4.1 0 1 1-3-3.9V6.6c0-1 .7-2 1.8-2.2H10Z"/><circle class="coral" cx="18.7" cy="4.8" r="1.2"/>''',
    "save": '''<path class="ink" d="M3 4.2C3 3 4 2 5.2 2h11.5L21 6.3v13.5c0 1.2-1 2.2-2.2 2.2H5.2C4 22 3 21 3 19.8V4.2Z"/><path class="violet" d="M7 2h8v6H7V2Z"/><path class="paper" d="M7 13h10v7H7v-7Z"/><circle class="mint" cx="15.2" cy="5" r="1.2"/>''',
    "personEmpty": '''<path class="line" d="M12 3.1c-2.7 0-4.7 2.1-4.5 4.8.2 2.8 2.1 4.8 4.5 4.8s4.3-2 4.5-4.8c.2-2.7-1.8-4.8-4.5-4.8ZM4 20.8c.3-4.4 3.3-7 8-7s7.7 2.6 8 7c.1.7-.5 1.2-1.1 1.2H5.1c-.6 0-1.2-.5-1.1-1.2Z"/><circle class="mint" cx="17.8" cy="6" r="1.3"/>''',
    "micSlash": '''<path class="ink" d="M8 5a4 4 0 0 1 7.9-.9l-8 11.5A4 4 0 0 1 8 11.2V5Z"/><path class="line" d="M4.8 10.2v1.1a7.2 7.2 0 0 0 11.4 5.8M12 18.5v3M8.5 21.5h7M3 21 21 3"/><circle class="coral" cx="18.6" cy="5.3" r="1.3"/>''',
    "skipBack": '''<path class="ink" d="M20 5.4c0-1.4-1.6-2.2-2.8-1.4L8.1 10V5.2c0-1.5-1.7-2.3-2.9-1.4L2.6 5.7v12.6l2.6 1.9c1.2.9 2.9 0 2.9-1.4V14l9.1 6c1.2.8 2.8 0 2.8-1.4V5.4Z"/><circle class="mint" cx="6.1" cy="12" r="1.3"/>''',
    "skipForward": '''<g transform="translate(24 0) scale(-1 1)"><path class="ink" d="M20 5.4c0-1.4-1.6-2.2-2.8-1.4L8.1 10V5.2c0-1.5-1.7-2.3-2.9-1.4L2.6 5.7v12.6l2.6 1.9c1.2.9 2.9 0 2.9-1.4V14l9.1 6c1.2.8 2.8 0 2.8-1.4V5.4Z"/><circle class="mint" cx="6.1" cy="12" r="1.3"/></g>''',
    "rewind15": '''<path class="line" d="M6.2 6.3A8 8 0 1 1 4 12M2.4 4.1v4.8h4.8"/><path class="ink" d="M8.2 10h2.3v6H8.7v-4.2H7.6V10h.6Zm3.3 0h4.8v1.7h-3v.7h1.2c1.4 0 2.3.7 2.3 1.9 0 1.3-1 2-2.8 2-1 0-1.9-.2-2.7-.6l.6-1.5c.6.3 1.2.4 1.8.4.7 0 1-.2 1-.5s-.3-.5-.9-.5h-2.3V10Z"/><circle class="coral" cx="4" cy="12" r="1.2"/>''',
    "forward15": '''<g transform="translate(24 0) scale(-1 1)"><path class="line" d="M6.2 6.3A8 8 0 1 1 4 12M2.4 4.1v4.8h4.8"/><path class="ink" transform="translate(24 0) scale(-1 1)" d="M8.2 10h2.3v6H8.7v-4.2H7.6V10h.6Zm3.3 0h4.8v1.7h-3v.7h1.2c1.4 0 2.3.7 2.3 1.9 0 1.3-1 2-2.8 2-1 0-1.9-.2-2.7-.6l.6-1.5c.6.3 1.2.4 1.8.4.7 0 1-.2 1-.5s-.3-.5-.9-.5h-2.3V10Z"/><circle class="coral" cx="4" cy="12" r="1.2"/></g>''',
    "xmarkCircle": '''<circle class="ink" cx="12" cy="12" r="9.8"/><path class="paper" d="m7.6 6.2 4.4 4.4 4.4-4.4 1.4 1.4-4.4 4.4 4.4 4.4-1.4 1.4-4.4-4.4-4.4 4.4-1.4-1.4 4.4-4.4-4.4-4.4 1.4-1.4Z"/><circle class="coral" cx="18.3" cy="5.8" r="1.2"/>''',
    "shrinkScreen": '''<path class="ink" d="M9.4 3v6.4H3V6.5h3.5V3h2.9Zm5.2 0h2.9v3.5H21v2.9h-6.4V3ZM3 14.6h6.4V21H6.5v-3.5H3v-2.9Zm11.6 0H21v2.9h-3.5V21h-2.9v-6.4Z"/><circle class="mint" cx="12" cy="12" r="1.5"/>''',
    "expandScreen": '''<path class="ink" d="M3 3h6.4v2.9H5.9v3.5H3V3Zm11.6 0H21v6.4h-2.9V5.9h-3.5V3ZM3 14.6h2.9v3.5h3.5V21H3v-6.4Zm15.1 0H21V21h-6.4v-2.9h3.5v-3.5Z"/><circle class="coral" cx="12" cy="12" r="1.5"/>''',
    "heartSlash": '''<path class="ink" d="M12 21.2C9.3 18.8 3.1 14.7 3.1 9.1c0-1.1.2-2 .6-2.8l14.1 12.1c-2.1 1.5-4.3 2.6-5.8 2.8ZM6.1 4.1c.6-.4 1.3-.6 2.1-.6 1.9 0 3.2 1 3.8 2.2.6-1.2 1.9-2.2 3.8-2.2 3 0 5.1 2.2 5.1 5.6 0 2.3-1 4.3-2.4 6L6.1 4.1Z"/><path class="coral" d="M2.2 3.7 3.7 2.2l18.1 16.1-1.5 1.7L2.2 3.7Z"/>''',
    "personCircle": '''<circle class="ink" cx="12" cy="12" r="10"/><circle class="paper" cx="12" cy="9" r="3.1"/><path class="violet" d="M6.3 18.1c.4-3.2 2.4-5 5.7-5s5.3 1.8 5.7 5c-1.6 1.2-3.5 1.9-5.7 1.9s-4.1-.7-5.7-1.9Z"/><circle class="mint" cx="18.2" cy="6" r="1.2"/>''',
    "album": '''<rect class="ink" x="2.5" y="2.5" width="19" height="19" rx="4"/><circle class="paper" cx="12" cy="12" r="5.2"/><circle class="violet" cx="12" cy="12" r="2.1"/><path class="mint" d="M5.3 5.2h5v2h-5v-2Z"/>''',
    "infoCircle": '''<circle class="ink" cx="12" cy="12" r="10"/><path class="paper" d="M10.2 9.5h3.6v7h1.6v2H8.6v-2h1.6v-5H8.8v-2h1.4ZM12 5.2a1.7 1.7 0 1 1 0 3.4 1.7 1.7 0 0 1 0-3.4Z"/><circle class="mint" cx="18.3" cy="5.8" r="1.2"/>''',
    "arrowDownCircle": '''<circle class="ink" cx="12" cy="12" r="10"/><path class="paper" d="M10.4 6.3h3.2v7l2.4-2.4 2.1 2.1-6.1 6.1L5.9 13l2.1-2.1 2.4 2.4v-7Z"/><circle class="mint" cx="18.2" cy="6" r="1.2"/>''',
    "sun": '''<circle class="coral" cx="12" cy="12" r="5"/><path class="ink" d="M10.7 1h2.6v4h-2.6V1Zm0 18h2.6v4h-2.6v-4ZM1 10.7h4v2.6H1v-2.6Zm18 0h4v2.6h-4v-2.6ZM4.2 2.4 7 5.2 5.2 7 2.4 4.2l1.8-1.8Zm12.8 12.8 2.8 2.8-1.8 1.8-2.8-2.8 1.8-1.8Zm1-12.8 1.8 1.8L17 7l-1.8-1.8L18 2.4ZM5.2 15.2 7 17l-2.8 2.8L2.4 18l2.8-2.8Z"/><circle class="mint" cx="14" cy="10" r="1.2"/>''',
    "moon": '''<path class="ink" d="M18.6 18.2A9.4 9.4 0 0 1 7 3.7a8.6 8.6 0 1 0 11.6 14.5Z"/><path class="violet" d="m17.6 4 .7 1.8 1.8.7-1.8.7-.7 1.8-.7-1.8-1.8-.7 1.8-.7.7-1.8Z"/><circle class="mint" cx="19.6" cy="12.4" r="1.2"/>''',
    "halfCircle": '''<circle class="ink" cx="12" cy="12" r="9.8"/><path class="violet" d="M12 2.2a9.8 9.8 0 0 1 0 19.6V2.2Z"/><circle class="mint" cx="12" cy="12" r="1.4"/>''',
    "catLife": '''<path class="ink" d="M4 18.5V8.8l8-5.8 8 5.8v9.7c0 1.4-1.1 2.5-2.5 2.5h-11C5.1 21 4 19.9 4 18.5Z"/><path class="mint" d="M7.3 14.1c1.2-2.5 2.8-3.7 4.7-3.7s3.5 1.2 4.7 3.7c-1.5 1.9-3.1 2.9-4.7 2.9s-3.2-1-4.7-2.9Z"/>''',
    "catCreate": '''<path class="ink" d="M4.2 17.8 14.9 3.2c.6-.9 1.9-1 2.7-.2l3.4 3.4c.8.8.7 2.1-.2 2.7L6.2 19.8 3 21l1.2-3.2Z"/><path class="coral" d="m14.1 4.3 5.6 5.6-2.3 1.7L12.4 6l1.7-1.7Z"/><circle class="mint" cx="5.1" cy="18.9" r="1.2"/>''',
    "catAcg": '''<path class="ink" d="M4 4.5 9.3 2l2.7 3 2.7-3L20 4.5v11c0 3.6-3.6 6.5-8 6.5s-8-2.9-8-6.5v-11Z"/><circle class="mint" cx="8.5" cy="11" r="1.5"/><circle class="coral" cx="15.5" cy="11" r="1.5"/><path class="paper" d="M9.4 16c.8.8 1.7 1.2 2.6 1.2s1.8-.4 2.6-1.2l-1.2-1.4c-.5.4-.9.6-1.4.6s-.9-.2-1.4-.6L9.4 16Z"/>''',
    "catEntertain": '''<path class="ink" d="M3 5h18v13.5c0 1.4-1.1 2.5-2.5 2.5h-13C4.1 21 3 19.9 3 18.5V5Z"/><path class="violet" d="m5 2 3 3H5L2 2h3Zm6 0 3 3h-3L8 2h3Zm6 0 3 3h-3l-3-3h3Z"/><path class="mint" d="m9.5 9 6 3.5-6 3.5V9Z"/>''',
    "catTalkshow": '''<path class="ink" d="M3 4.5C3 3.1 4.1 2 5.5 2h13C19.9 2 21 3.1 21 4.5v10c0 1.4-1.1 2.5-2.5 2.5h-5.3l-5.3 4.4c-.8.7-2 .1-2-1V17h-.4C4.1 17 3 15.9 3 14.5v-10Z"/><circle class="mint" cx="8" cy="9.5" r="1.4"/><circle class="coral" cx="12" cy="9.5" r="1.4"/><circle class="violet" cx="16" cy="9.5" r="1.4"/>''',
    "catKnowledge": '''<path class="ink" d="M2.5 8.1 12 3l9.5 5.1L12 13.2 2.5 8.1Z"/><path class="soft" d="M6 11v5.8c3.2 2.7 8.8 2.7 12 0V11l-6 3.2L6 11Z"/><path class="violet" d="M20 9v7.2h2V8.1L20 9Z"/><circle class="mint" cx="21" cy="18.3" r="1.4"/>''',
    "catBusiness": '''<path class="ink" d="M3 7.2C3 6 4 5 5.2 5h13.6C20 5 21 6 21 7.2v11.6C21 20 20 21 18.8 21H5.2C4 21 3 20 3 18.8V7.2Z"/><path class="soft" d="M8 3.8C8 2.8 8.8 2 9.8 2h4.4c1 0 1.8.8 1.8 1.8V5h-2.6v-.6h-2.8V5H8V3.8Z"/><path class="mint" d="M3 10h18v4H3v-4Z"/><rect class="coral" x="10.5" y="11" width="3" height="2" rx="1"/>''',
    "catHistory": '''<path class="ink" d="M12 2.2a9.8 9.8 0 1 1-8.5 14.7l3-1.7A6.4 6.4 0 1 0 6.2 9H10L5.3 13.7.6 9H3a9.8 9.8 0 0 1 9-6.8Z"/><path class="violet" d="M10.7 6h2.6v5.2l3.8 2.1-1.3 2.2-5.1-3V6Z"/>''',
    "catParenting": '''<circle class="ink" cx="9" cy="8" r="4.5"/><circle class="violet" cx="16.7" cy="10.2" r="3.3"/><path class="ink" d="M2.5 21c.4-5.2 2.8-8 6.5-8s6.1 2.8 6.5 8h-13Z"/><path class="soft" d="M12.8 21c.3-3.8 1.7-5.9 4-5.9 2.4 0 3.9 2.1 4.2 5.9h-8.2Z"/><circle class="mint" cx="18.6" cy="7" r="1.2"/>''',
    "catCrosstalk": '''<path class="ink" d="M3 5c0-1.1.9-2 2-2h7c1.1 0 2 .9 2 2v8c0 1.1-.9 2-2 2H8l-3.8 3.1c-.5.4-1.2 0-1.2-.6V5Z"/><path class="violet" d="M11 9c0-1.1.9-2 2-2h6c1.1 0 2 .9 2 2v10.5c0 .7-.8 1.1-1.3.6L16 17h-3c-1.1 0-2-.9-2-2V9Z"/><circle class="mint" cx="7" cy="8" r="1.2"/><circle class="coral" cx="16" cy="12" r="1.2"/>''',
    "catDefault": '''<path class="ink" d="m12 2.1 8.6 5v9.8l-8.6 5-8.6-5V7.1l8.6-5Z"/><circle class="paper" cx="12" cy="12" r="4"/><circle class="violet" cx="12" cy="12" r="1.7"/><circle class="mint" cx="18" cy="7" r="1.2"/>''',
    "catPodcast": '''<path class="ink" d="M12 2.5A8.5 8.5 0 0 0 6.4 17l1.8-2.2a5.5 5.5 0 1 1 7.6 0l1.8 2.2A8.5 8.5 0 0 0 12 2.5Z"/><circle class="violet" cx="12" cy="10.7" r="2.5"/><path class="mint" d="m10.2 14.2 1-2.2h1.6l1 2.2.9 7.3H9.3l.9-7.3Z"/>''',
    "catStar": '''<path class="ink" d="m12 1.8 3 6.3 6.8 1-4.9 4.8 1.2 6.8-6.1-3.2-6.1 3.2 1.2-6.8-4.9-4.8 6.8-1 3-6.3Z"/><path class="coral" d="m12 6.3 1.2 2.6 2.8.4-2 2 .5 2.8-2.5-1.3-2.5 1.3.5-2.8-2-2 2.8-.4L12 6.3Z"/>''',
    "catDrama": '''<path class="ink" d="M3 3.5h8v8.7c0 4.1-2.7 7.5-6 7.5S-1 16.3-1 12.2V3.5h4Z" transform="translate(2)"/><path class="violet" d="M13 4.5h8v8.7c0 4.1-2.7 7.5-6 7.5-1.6 0-3-.8-4.1-2.1 1.7-1.7 2.7-4.2 2.7-6.9V4.5H13Z"/><circle class="mint" cx="7" cy="9" r="1"/><circle class="coral" cx="17" cy="10" r="1"/><path class="paper" d="M4.5 13c1.4 1 3.6 1 5 0-.4 2-1.2 3-2.5 3s-2.1-1-2.5-3ZM14.5 15.7c1.4-1 3.6-1 5 0-.4-2-1.2-3-2.5-3s-2.1 1-2.5 3Z"/>''',
    "catStory": '''<path class="ink" d="M3 4.5C3 3.1 4.1 2 5.5 2h13C19.9 2 21 3.1 21 4.5v11C21 16.9 19.9 18 18.5 18h-6.1L7 22v-4H5.5C4.1 18 3 16.9 3 15.5v-11Z"/><path class="mint" d="M7 6h10v2.2H7V6Zm0 4h7.2v2.2H7V10Z"/><circle class="coral" cx="17.3" cy="13" r="1.3"/>''',
    "catOther": '''<path class="ink" d="M3 3h7.8v7.8H3V3Zm10.2 0H21v7.8h-7.8V3ZM3 13.2h7.8V21H3v-7.8Z"/><path class="violet" d="m17.1 12.8 4.1 4.2-4.1 4.2-4.1-4.2 4.1-4.2Z"/><circle class="mint" cx="17.1" cy="17" r="1.2"/>''',
    "catPublish": '''<path class="ink" d="M4 2h11l5 5v13c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2Z"/><path class="soft" d="M15 2v5h5l-5-5Z"/><path class="mint" d="m11 9 4 4h-2.4v5H9.4v-5H7l4-4Z"/>''',
    "emoji": '''<circle class="ink" cx="12" cy="12" r="10"/><circle class="mint" cx="8" cy="9" r="1.5"/><circle class="coral" cx="16" cy="9" r="1.5"/><path class="paper" d="M6.8 14c1.3 2.2 3 3.3 5.2 3.3s3.9-1.1 5.2-3.3l-2-1.1c-.8 1.3-1.8 2-3.2 2s-2.4-.7-3.2-2l-2 1.1Z"/>''',
    "logInfo": '''<path class="ink" d="M4 2h11l5 5v15H4c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2Z"/><path class="violet" d="M15 2v5h5l-5-5Z"/><circle class="mint" cx="10" cy="12" r="1.7"/><rect class="paper" x="8.8" y="14" width="2.4" height="4.2" rx="1.2"/>''',
    "logDebug": '''<path class="ink" d="M7.2 7.2A5 5 0 0 1 12 3c2.4 0 4.4 1.8 4.8 4.2l2.4 2.4v7.2L16.8 19A5 5 0 0 1 12 23a5 5 0 0 1-4.8-4L4.8 16.8V9.6l2.4-2.4Z"/><path class="line" d="M3 6h4M17 6h4M2 12h5M17 12h5M3 18h4M17 18h4"/><circle class="coral" cx="9.5" cy="11" r="1.2"/><circle class="mint" cx="14.5" cy="11" r="1.2"/>''',
    "logError": '''<path class="ink" d="M10.1 2.7c.8-1.4 2.9-1.4 3.8 0l8.3 14.4c.8 1.4-.2 3.2-1.9 3.2H3.7c-1.7 0-2.7-1.8-1.9-3.2l8.3-14.4Z"/><rect class="coral" x="10.6" y="7" width="2.8" height="7.8" rx="1.4"/><circle class="paper" cx="12" cy="17.4" r="1.4"/>''',
    "logNetwork": '''<circle class="ink" cx="12" cy="12" r="10"/><path class="line-soft" stroke="#F7F5FF" d="M2.6 12h18.8M12 2.4c3 3 4.2 6.2 4.2 9.6S15 18.6 12 21.6M12 2.4C9 5.4 7.8 8.6 7.8 12S9 18.6 12 21.6"/><circle class="mint" cx="17.8" cy="6.2" r="1.3"/>''',
    "logSuccess": '''<path class="ink" d="m12 2 2.9 2.2 3.6.3.8 3.5 2.5 2.6-1.4 3.3.8 3.5-3.2 1.8-1.8 3.2-3.5-.8L12 22l-2.6-2.4-3.5.8-1.8-3.2-3.2-1.8.8-3.5-1.4-3.3L4 8l.8-3.5 3.6-.3L12 2Z"/><path class="mint" d="m6.8 12.2 2.2-1.8 2.2 2.7 5.8-5.8 2 2-8.1 8.1-4.1-5.2Z"/>''',
    "arrowDownToLine": '''<path class="ink" d="M10.4 2h3.2v11.2l2.8-2.8 2.2 2.2-6.6 6.6-6.6-6.6 2.2-2.2 2.8 2.8V2Z"/><rect class="violet" x="3" y="20" width="18" height="2.5" rx="1.25"/><circle class="mint" cx="18.5" cy="20.9" r="1.1"/>''',
    "fmMode": '''<path class="ink" d="M4 5h16v14H4V5Z"/><path class="paper" d="M7 8h5v2.3H9.4V12h2.2v2.2H9.4V17H7V8Zm6 0h2.3l1.5 3.2L18.3 8H21v9h-2.3v-5l-1.2 2.5h-1.4L15 12v5h-2V8Z"/><circle class="coral" cx="20.2" cy="4.4" r="1.4"/>''',
    "mv": '''<rect class="ink" x="2" y="4" width="20" height="16" rx="4"/><path class="mint" d="M9.1 8.2c0-1 1.1-1.6 2-1.1l6 3.8c.8.5.8 1.7 0 2.2l-6 3.8c-.9.5-2-.1-2-1.1V8.2Z"/><circle class="coral" cx="18.3" cy="7" r="1.2"/>''',
    "layers": '''<path class="ink" d="m12 2 10 5.4-10 5.4L2 7.4 12 2Z"/><path class="soft" d="m4 11.1 8 4.3 8-4.3 2 1.1-10 5.4-10-5.4 2-1.1Z"/><path class="violet" d="m4 15.7 8 4.3 8-4.3 2 1.1-10 5.4-10-5.4 2-1.1Z"/><circle class="mint" cx="18" cy="7.4" r="1.2"/>''',
    "hitokoto": '''<path class="ink" d="M3 4.5C3 3.1 4.1 2 5.5 2h13C19.9 2 21 3.1 21 4.5v10C21 15.9 19.9 17 18.5 17h-5.2L7 22v-5H5.5C4.1 17 3 15.9 3 14.5v-10Z"/><path class="mint" d="M6.5 6.2h4.2v4.2H8.5v2.4h-2V6.2Zm6.8 0h4.2v4.2h-2.2v2.4h-2V6.2Z"/>''',
    "tabBar": '''<path class="ink" d="M3 4h18v16H3V4Z"/><path class="paper" d="M5 6h14v8H5V6Z"/><path class="violet" d="M4.8 15.8h14.4v2.8H4.8v-2.8Z"/><circle class="mint" cx="12" cy="17.2" r="1.2"/>''',
    "minimalBar": '''<path class="ink" d="M2.5 8h19v8h-19V8Z"/><circle class="mint" cx="7" cy="12" r="2.4"/><path class="paper" d="M11 10.5h6v3h-6v-3Z"/><circle class="coral" cx="19.4" cy="9" r="1.2"/>''',
    "floatingBall": '''<circle class="ink" cx="12" cy="12" r="10"/><circle class="violet" cx="12" cy="12" r="5.7"/><path class="mint" d="m10 8.3 5.7 3.7-5.7 3.7V8.3Z"/><circle class="coral" cx="18.2" cy="5.8" r="1.2"/>''',
})

# Semantic-specific replacements found during duplicate-artwork audit. These
# deliberately separate concepts that legacy icon packages mapped to one glyph.
ICON_BODIES.update({
    "podcast": '''<path class="ink" d="M3 5.2C3 3.4 4.4 2 6.2 2h7.6C15.6 2 17 3.4 17 5.2v5.6c0 1.8-1.4 3.2-3.2 3.2H9.4l-4.7 3.7c-.7.6-1.7.1-1.7-.8V5.2Z"/><path class="violet" d="M9 10.2C9 8.4 10.4 7 12.2 7h5.6C19.6 7 21 8.4 21 10.2v5.6c0 1.8-1.4 3.2-3.2 3.2h-2.5l-3.7 2.8c-.7.5-1.6 0-1.6-.8v-2.2c-.6-.6-1-1.4-1-2.3v-6.3Z"/><path class="paper" d="m13.2 11.1 4.2 2.5-4.2 2.5v-5Z"/><circle class="mint" cx="6.8" cy="7" r="1.25"/><circle class="coral" cx="18.9" cy="9.2" r="1.15"/>''',
    "repeatMode": '''<path class="line" d="M5.1 7.1A7.8 7.8 0 0 1 18 5.8l2.1 2M20.1 4.1v3.7h-3.7M18.9 16.9A7.8 7.8 0 0 1 6 18.2l-2.1-2M3.9 19.9v-3.7h3.7"/><circle class="mint" cx="19.9" cy="8" r="1.2"/>''',
    "repeatOne": '''<path class="line" d="M5.1 7.1A7.8 7.8 0 0 1 18 5.8l2.1 2M20.1 4.1v3.7h-3.7M18.9 16.9A7.8 7.8 0 0 1 6 18.2l-2.1-2M3.9 19.9v-3.7h3.7"/><path class="violet" d="M9.5 8.8h3.7v6.4h1.8v2H9.2v-2H11v-4.3H9.5V8.8Z"/><circle class="coral" cx="19.9" cy="8" r="1.2"/>''',
    "musicNoteList": '''<path class="ink" d="M4 4h9v3H4V4Zm0 6h7v3H4v-3Zm0 6h5v3H4v-3Z"/><path class="violet" d="M15 4.1 21 3v11.5a3.5 3.5 0 1 1-2.5-3.3V7L15 7.7V4.1Z"/><circle class="mint" cx="19.8" cy="5" r="1.1"/>''',
    "playerDownload": '''<circle class="ink" cx="12" cy="12" r="10"/><path class="paper" d="M10.5 5.8h3v6.3l2.2-2.2 2 2-5.7 5.7-5.7-5.7 2-2 2.2 2.2V5.8Z"/><path class="violet" d="M7.2 18.3h9.6v2H7.2v-2Z"/><circle class="mint" cx="18.3" cy="5.8" r="1.2"/>''',
    "playCircle": '''<circle class="line" cx="12" cy="12" r="9.5"/><path class="ink" d="M9.3 7.8c0-1 1.1-1.6 2-1.1l6 3.8c.8.5.8 1.7 0 2.2l-6 3.8c-.9.5-2-.1-2-1.1V7.8Z"/><circle class="mint" cx="18.3" cy="6" r="1.2"/>''',
    "playCircleFill": '''<circle class="ink" cx="12" cy="12" r="10"/><path class="mint" d="M9.2 7.7c0-1 1.1-1.7 2-1.1l6.1 3.9c.8.5.8 1.7 0 2.2l-6.1 3.9c-.9.6-2-.1-2-1.1V7.7Z"/><circle class="coral" cx="18.2" cy="5.8" r="1.2"/>''',
    "playNext": '''<path class="ink" d="M3.2 5h10v3H3.2V5Zm0 5.5h7.3v3H3.2v-3Zm0 5.5h5v3h-5v-3Z"/><path class="violet" d="M13.2 10.1c0-1.1 1.2-1.7 2.1-1.1l5.2 3.3c.9.6.9 1.8 0 2.4L15.3 18c-.9.6-2.1-.1-2.1-1.1v-6.8Z"/><path class="mint" d="M18.6 5h2.2v4.4h-2.2V5Z"/>''',
    "addToQueue": '''<path class="ink" d="M3 4.5h10v3H3v-3Zm0 6h8v3H3v-3Zm0 6h6v3H3v-3Z"/><path class="violet" d="M16.2 9.2h2.8v3.6h3.6v2.8H19v3.6h-2.8v-3.6h-3.6v-2.8h3.6V9.2Z"/><circle class="mint" cx="20.5" cy="10.2" r="1.1"/>''',
    "catMusic": '''<path class="ink" d="M9.5 4.2 20 2v12.8a4 4 0 1 1-3-3.8V6.1L9.5 7.7v8.9a4 4 0 1 1-3-3.8V6.4c0-1 .7-1.9 1.7-2.1l1.3-.1Z"/><path class="violet" d="m3.5 4.7 1-2 1 2 2 .9-2 .9-1 2-1-2-2-.9 2-.9Z"/><circle class="mint" cx="18.6" cy="4.7" r="1.2"/>''',
    "audioWave": '''<path class="line" d="M2.5 12h2.2l1.6-5.2 3.1 10.4L12 3.8l3.1 16.4 2.5-8.2h3.9"/><circle class="coral" cx="12" cy="3.8" r="1.3"/><circle class="mint" cx="21" cy="12" r="1.3"/>''',
})


# Appearance settings use distinct metaphors instead of repeatedly borrowing
# sparkle/layers/playerTheme. Each glyph describes the controlled surface.
ICON_BODIES.update({
    "themeStyle": '''<path class="ink" d="M3 4.8C3 3.3 4.3 2 5.8 2h7.4C14.7 2 16 3.3 16 4.8v7.4c0 1.5-1.3 2.8-2.8 2.8H5.8C4.3 15 3 13.7 3 12.2V4.8Z"/><path class="violet" d="M8 11.8C8 10.3 9.3 9 10.8 9h7.4c1.5 0 2.8 1.3 2.8 2.8v7.4c0 1.5-1.3 2.8-2.8 2.8h-7.4C9.3 22 8 20.7 8 19.2v-7.4Z"/><path class="paper" d="M11 12h7v7h-7v-7Z"/><circle class="mint" cx="18.7" cy="10.5" r="1.35"/>''',
    "appBrand": '''<rect class="ink" x="3" y="3" width="18" height="18" rx="5"/><path class="violet" d="M7 7.2c0-.8.8-1.4 1.5-1l3.5 2 3.5-2c.7-.4 1.5.2 1.5 1v9.6c0 .8-.8 1.4-1.5 1l-3.5-2-3.5 2c-.7.4-1.5-.2-1.5-1V7.2Z"/><path class="mint" d="m12 8.2 2.8 1.6v4.4L12 15.8l-2.8-1.6V9.8L12 8.2Z"/><circle class="coral" cx="18.3" cy="5.7" r="1.25"/>''',
    "interfaceIconSet": '''<rect class="ink" x="2.5" y="2.5" width="8.4" height="8.4" rx="2.5"/><circle class="violet" cx="17.3" cy="6.7" r="4.2"/><path class="soft" d="M2.5 15.1c0-1.4 1.1-2.5 2.5-2.5h3.4c1.4 0 2.5 1.1 2.5 2.5v3.4c0 1.4-1.1 2.5-2.5 2.5H5c-1.4 0-2.5-1.1-2.5-2.5v-3.4Z"/><path class="mint" d="m17.3 12.5 4.6 8h-9.2l4.6-8Z"/><circle class="coral" cx="8.9" cy="14.3" r="1.1"/>''',
    "systemTabBar": '''<path class="ink" d="M3 3h18v18H3V3Z"/><path class="paper" d="M5.2 5.2h13.6v8.3H5.2V5.2Z"/><path class="violet" d="M5.2 15h13.6v3.8H5.2V15Z"/><circle class="paper" cx="7.5" cy="16.9" r=".9"/><circle class="paper" cx="12" cy="16.9" r="1.25"/><circle class="paper" cx="16.5" cy="16.9" r=".9"/><circle class="mint" cx="12" cy="16.9" r=".55"/>''',
    "floatingBarStyle": '''<path class="ink" d="M2.5 8.2c0-1.7 1.3-3 3-3h13c1.7 0 3 1.3 3 3v7.6c0 1.7-1.3 3-3 3h-13c-1.7 0-3-1.3-3-3V8.2Z"/><path class="paper" d="M7.2 9h6.1v2.3H7.2V9Zm0 4h4.2v2.3H7.2V13Z"/><circle class="violet" cx="17.3" cy="12" r="3.2"/><path class="mint" d="m16.3 10.2 2.8 1.8-2.8 1.8v-3.6Z"/><circle class="coral" cx="19.9" cy="6.4" r="1.15"/>''',
    "liquidGlass": '''<path class="ink" d="M12 2.2c3.8 4.8 7.5 8.9 7.5 13A7.5 7.5 0 0 1 4.5 15.2c0-4.1 3.7-8.2 7.5-13Z"/><path class="violet" d="M8.1 14.7c0-3 2.1-6.1 4.6-9.4-1 4.3.1 7.2 3.5 9.6-.4 2.5-2 4.2-4.1 4.2-2.2 0-4-1.9-4-4.4Z"/><path class="paper" d="M8.2 11.5c.9-2.1 2-3.8 3.1-5.2-.4 2.6-1.3 4.5-3.1 5.2Z"/><circle class="mint" cx="16.8" cy="16.1" r="1.25"/><circle class="coral" cx="17.7" cy="8.2" r="1.05"/>''',
    "fluidBackground": '''<path class="ink" d="M2.2 6.1c3.1-2.4 6.3-2.4 9.4 0s6.3 2.4 10.2 0v4.2c-3.9 2.4-7.1 2.4-10.2 0s-6.3-2.4-9.4 0V6.1Z"/><path class="violet" d="M2.2 12.6c3.1-2.4 6.3-2.4 9.4 0s6.3 2.4 10.2 0v4.2c-3.9 2.4-7.1 2.4-10.2 0s-6.3-2.4-9.4 0v-4.2Z"/><path class="soft" d="M2.2 19c3.1-2.3 6.3-2.3 9.4 0 3.1 2.4 6.3 2.4 10.2 0v2.5H2.2V19Z"/><circle class="mint" cx="18.9" cy="12.4" r="1.25"/><circle class="coral" cx="5.2" cy="6.1" r="1.05"/>''',
    "backgroundGlobal": '''<rect class="ink" x="2.5" y="3" width="19" height="18" rx="3.5"/><path class="violet" d="M5.3 15.2c2.3-2.9 4.7-3.4 7.2-1.4 2.2 1.8 4.2 1.4 6.2-.7v5.2H5.3v-3.1Z"/><circle class="paper" cx="8.2" cy="8.2" r="2.2"/><path class="mint" d="M5.4 18.2h13.2v1.2H5.4z"/><circle class="coral" cx="18.5" cy="6" r="1.15"/>''',
    "backgroundPlaylist": '''<rect class="ink" x="2.5" y="3" width="19" height="18" rx="3.5"/><path class="paper" d="M6 7h8v2.1H6V7Zm0 4h6.2v2.1H6V11Zm0 4h4.4v2.1H6V15Z"/><path class="violet" d="M16 9.2 20 8v7.3a2.6 2.6 0 1 1-1.8-2.5v-2.1l-2.2.7V9.2Z"/><circle class="mint" cx="18.8" cy="5.7" r="1.15"/>''',
    "backgroundPlayer": '''<rect class="ink" x="2.5" y="3" width="19" height="18" rx="3.5"/><circle class="violet" cx="12" cy="12" r="5.7"/><path class="mint" d="M10.2 8.8c0-.8.9-1.3 1.6-.8l5 3.2c.6.4.6 1.3 0 1.7l-5 3.2c-.7.4-1.6-.1-1.6-.8V8.8Z"/><path class="paper" d="M5.4 18h5v1.3h-5z"/><circle class="coral" cx="18.6" cy="5.7" r="1.15"/>''',
    "colorEngine": '''<path class="ink" d="M3 5.5C3 4.1 4.1 3 5.5 3h5C11.9 3 13 4.1 13 5.5v13c0 1.4-1.1 2.5-2.5 2.5h-5C4.1 21 3 19.9 3 18.5v-13Z"/><path class="violet" d="M8.5 4.4c0-1.3 1.4-2.2 2.6-1.6l4.6 2.3c1.2.6 1.5 2.2.7 3.2l-6.5 10c-.5.8-1.4 1.1-2.2.8.5-.5.8-1.3.8-2.1V4.4Z"/><path class="soft" d="m14.5 8.5 5.3 3.2c1.1.7 1.4 2.2.6 3.2l-4 5c-.8 1-2.3 1.2-3.3.4l-3-2.3 4.4-9.5Z"/><circle class="mint" cx="7.9" cy="17.2" r="1.45"/><circle class="coral" cx="17.7" cy="14.3" r="1.15"/>''',
    "backgroundImage": '''<rect class="ink" x="2.5" y="3" width="19" height="18" rx="3.5"/><circle class="coral" cx="17.5" cy="7" r="2"/><path class="violet" d="m5.2 17.8 4.3-5.1 2.7 3 2.4-2.4 4.2 4.5H5.2Z"/><path class="mint" d="m9.5 12.7 2.7 3-1.2 1.2-3-2.1 1.5-2.1Z"/><path class="paper" d="M5.2 18.7h13.6v1H5.2z"/>''',
    "gradientStyle": '''<path class="ink" d="M3 4.5C3 3.1 4.1 2 5.5 2h7C13.9 2 15 3.1 15 4.5v15C15 20.9 13.9 22 12.5 22h-7C4.1 22 3 20.9 3 19.5v-15Z"/><path class="violet" d="M9 4.5C9 3.1 10.1 2 11.5 2h7C19.9 2 21 3.1 21 4.5v15c0 1.4-1.1 2.5-2.5 2.5h-7C10.1 22 9 20.9 9 19.5v-15Z"/><path class="mint" d="M9 7h6v10H9V7Z"/><circle class="coral" cx="18.2" cy="5.4" r="1.2"/>''',
    "appearanceMode": '''<circle class="ink" cx="12" cy="12" r="9.8"/><path class="paper" d="M12 4.2a7.8 7.8 0 0 0 0 15.6V4.2Z"/><path class="violet" d="M12 4.2a7.8 7.8 0 0 1 0 15.6V4.2Z"/><path class="mint" d="M10.8 2.2h2.4v3h-2.4z"/><circle class="coral" cx="18.8" cy="7.2" r="1.15"/>''',
})


PREVIEW_ORDER = [
    ("Navigation", ["home", "podcast", "library", "search", "profile", "settings", "back", "more"]),
    ("Playback", ["play", "pause", "previous", "next", "shuffle", "repeat", "queue", "waveform"]),
    ("Actions", ["like", "download", "share", "add", "comment", "bell", "filter", "check"]),
    ("Sound", ["headphones", "equalizer", "immersive", "microphone", "karaoke", "radio", "quality", "storage"]),
    ("Library", ["cloud", "clock", "history", "lock", "translate", "sparkle", "music", "lyrics"]),
    ("Explore", ["emotion", "electronic", "book", "tech", "travel", "food", "news", "palette"]),
]


ALL_SEMANTICS = """home homeFilled podcast podcastFilled library libraryFilled search profile profileFilled play pause next previous stop repeatMode repeatOne shuffle refresh like liked list back more close trash fm bell settings download cloud chevronRight chevronLeft chevronDown chevronUp magnifyingGlass xmark fullscreen sparkle soundQuality storage haptic info clock musicNoteList chart translate karaoke lock unlock qr phone send musicNote save playerDownload comment history playCircle warning personEmpty playNext add addToQueue radio micSlash waveform skipBack skipForward rewind15 forward15 xmarkCircle playCircleFill gridSquare checkmark shrinkScreen expandScreen headphones heartSlash personCircle album infoCircle arrowDownCircle sun moon halfCircle equalizer immersive playerTheme catMusic catLife catEmotion catCreate catAcg catEntertain catTalkshow catBook catKnowledge catBusiness catHistory catNews catParenting catTravel catCrosstalk catFood catTech catDefault catPodcast catElectronic catStar catDrama catStory catOther catPublish emoji share logInfo logDebug logError logNetwork logSuccess arrowDownToLine filter microphone fmMode audioWave mv layers hitokoto tabBar minimalBar floatingBall themeStyle appBrand interfaceIconSet systemTabBar floatingBarStyle liquidGlass fluidBackground backgroundGlobal backgroundPlaylist backgroundPlayer colorEngine backgroundImage gradientStyle appearanceMode""".split()


STATE_SOURCES = {
    "homeFilled": "home", "podcastFilled": "podcast", "libraryFilled": "library",
    "profileFilled": "profile", "repeatMode": "repeat", "repeatOne": "repeat",
    "list": "queue", "magnifyingGlass": "search", "xmark": "close",
    "soundQuality": "quality", "musicNoteList": "music", "playerDownload": "download",
    "playCircle": "play", "playNext": "queue", "addToQueue": "queue",
    "playCircleFill": "play", "gridSquare": "grid", "checkmark": "check",
    "catMusic": "music", "catEmotion": "emotion", "catBook": "book",
    "catNews": "news", "catTravel": "travel", "catFood": "food",
    "catTech": "tech", "catElectronic": "electronic", "audioWave": "waveform",
}


def semantic_bodies() -> dict[str, str]:
    """Resolve every application semantic to a real, editable SVG body."""
    result: dict[str, str] = {}
    filled_states = {"homeFilled", "podcastFilled", "libraryFilled", "profileFilled", "playCircleFill"}
    action_states = {"playCircle", "playerDownload", "playNext", "addToQueue", "audioWave"}
    for semantic in ALL_SEMANTICS:
        if semantic in ICON_BODIES:
            result[semantic] = ICON_BODIES[semantic]
            continue
        source = STATE_SOURCES.get(semantic)
        if source is None or source not in ICON_BODIES:
            raise KeyError(f"missing Pulse Bloom artwork for semantic: {semantic}")
        body = ICON_BODIES[source]
        if semantic in filled_states:
            body += '<circle class="coral" cx="19.4" cy="4.6" r="1.7"/><path class="mint" d="M17.4 20.4h4v1.6h-4z"/>'
        elif semantic in action_states:
            body += '<path class="mint" d="M18.2 2.6h3.2v3.2h-3.2z"/>'
        elif semantic == "repeatOne":
            body += '<circle class="coral" cx="12" cy="12" r="1.3"/>'
        elif semantic == "repeatMode":
            body += '<circle class="mint" cx="20" cy="8" r="1.2"/>'
        elif semantic.startswith("cat"):
            body += '<circle class="coral" cx="20.2" cy="4.2" r="1.25"/>'
        result[semantic] = body
    return result


def svg_document(body: str, title: str, dark: bool = False) -> str:
    style = STYLE
    if dark:
        style += """
  .ink { fill:#F7F4FF; }
  .soft { fill:#D8D0F2; }
  .paper { fill:#171225; }
  .line { stroke:#F7F4FF; }
  .line-soft { stroke:#D8D0F2; }
"""
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" role="img" aria-labelledby="title">
  <title id="title">Pulse Bloom {title}</title>
  <style>{style}</style>
  <g id="base">{body}</g>
</svg>\n'''


def write_icons() -> None:
    dark_icons = ROOT / "icons-dark"
    dark_icons.mkdir(parents=True, exist_ok=True)
    for name, body in semantic_bodies().items():
        (ICONS / f"{name}.svg").write_text(svg_document(body, name), encoding="utf-8")
        (dark_icons / f"{name}.svg").write_text(svg_document(body, name, dark=True), encoding="utf-8")


def write_preview() -> None:
    # Square artboard keeps macOS Quick Look from cropping the wide contact sheet
    # and leaves each row enough breathing room for labels.
    width, height = 1680, 1680
    x0, y0 = 290, 300
    dx, dy = 164, 218
    defs = "\n".join(
        f'<symbol id="icon-{name}" viewBox="0 0 24 24">{body}</symbol>'
        for name, body in ICON_BODIES.items()
    )
    cells: list[str] = []
    for row, (section, names) in enumerate(PREVIEW_ORDER):
        y = y0 + row * dy
        cells.append(f'<text class="section" x="88" y="{y + 47}">{section}</text>')
        for col, name in enumerate(names):
            x = x0 + col * dx
            cells.append(f'''<g class="icon-cell" transform="translate({x} {y})">
  <rect class="cell" x="-43" y="-35" width="112" height="112" rx="32"/>
  <use href="#icon-{name}" x="-13" y="-5" width="54" height="54"/>
  <text class="label" x="13" y="96" text-anchor="middle">{name}</text>
</g>''')

    preview = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
<defs>
  <linearGradient id="board" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#F6F3FF"/><stop offset=".56" stop-color="#F4FAF7"/><stop offset="1" stop-color="#FFF2F5"/></linearGradient>
  <filter id="softShadow" x="-30%" y="-30%" width="160%" height="170%"><feDropShadow dx="0" dy="14" stdDeviation="18" flood-color="#332858" flood-opacity=".11"/></filter>
  {defs}
</defs>
<style>
{STYLE}
  .title {{ font: 760 74px -apple-system,BlinkMacSystemFont,"Helvetica Neue",sans-serif; fill:#18142A; letter-spacing:-2px; }}
  .subtitle {{ font: 520 25px -apple-system,BlinkMacSystemFont,"Helvetica Neue",sans-serif; fill:#71698A; letter-spacing:4px; }}
  .section {{ font: 680 24px -apple-system,BlinkMacSystemFont,"Helvetica Neue",sans-serif; fill:#433A62; }}
  .label {{ font: 620 17px -apple-system,BlinkMacSystemFont,"Helvetica Neue",sans-serif; fill:#71698A; }}
  .cell {{ fill:#FFFFFF; fill-opacity:.82; stroke:#FFFFFF; stroke-width:2; filter:url(#softShadow); }}
  .icon-cell {{ transition:transform .32s cubic-bezier(.2,.8,.2,1); }}
  .icon-cell:hover {{ transform-box:fill-box; transform-origin:center; transform:scale(1.08) translateY(-4px); }}
  .icon-cell:nth-of-type(3n) .mint {{ animation:seedPulse 2.4s ease-in-out infinite; transform-box:fill-box; transform-origin:center; }}
  .icon-cell:nth-of-type(4n) .coral {{ animation:seedDrift 3s ease-in-out infinite; transform-box:fill-box; transform-origin:center; }}
  @keyframes seedPulse {{ 0%,100%{{transform:scale(1)}} 50%{{transform:scale(1.28)}} }}
  @keyframes seedDrift {{ 0%,100%{{transform:translate(0,0)}} 50%{{transform:translate(0,-1.2px)}} }}
  @media (prefers-reduced-motion:reduce) {{ * {{ animation:none!important; transition:none!important; }} }}
</style>
<rect width="100%" height="100%" fill="url(#board)"/>
<circle cx="1485" cy="80" r="190" fill="#8D7CFF" opacity=".08"/>
<circle cx="1600" cy="1570" r="280" fill="#66E8B4" opacity=".12"/>
<circle cx="80" cy="1510" r="210" fill="#FF728E" opacity=".08"/>
<text class="subtitle" x="88" y="76">MONO ICON SYSTEM / 24 PX</text>
<text class="title" x="88" y="164">PULSE BLOOM</text>
<text class="subtitle" x="1010" y="148">ORGANIC · DUOTONE · NON-NATIVE</text>
<path d="M88 205H1592" stroke="#332858" stroke-opacity=".12"/>
{''.join(cells)}
<text class="subtitle" x="88" y="1630">48 CORE GLYPHS · {len(ALL_SEMANTICS)} SEMANTIC SLOTS · EDITABLE SVG</text>
</svg>\n'''
    (ROOT / "pulse-bloom-preview.svg").write_text(preview, encoding="utf-8")


def write_complete_preview() -> None:
    bodies = semantic_bodies()
    width = 2200
    columns = 11
    dx, dy = 188, 158
    x0, y0 = 120, 260
    row_count = (len(ALL_SEMANTICS) + columns - 1) // columns
    height = max(2200, y0 + row_count * dy + 110)
    defs = "\n".join(
        f'<symbol id="all-{name}" viewBox="0 0 24 24">{body}</symbol>'
        for name, body in bodies.items()
    )
    cells: list[str] = []
    for index, name in enumerate(ALL_SEMANTICS):
        row, col = divmod(index, columns)
        x, y = x0 + col * dx, y0 + row * dy
        cells.append(f'''<g transform="translate({x} {y})">
  <rect class="tile" x="0" y="0" width="112" height="112" rx="30"/>
  <use href="#all-{name}" x="30" y="28" width="52" height="52"/>
  <text class="name" x="56" y="136" text-anchor="middle">{name}</text>
</g>''')
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
<defs>
  <linearGradient id="completeBoard" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#F5F1FF"/><stop offset=".48" stop-color="#F2FBF7"/><stop offset="1" stop-color="#FFF0F4"/></linearGradient>
  <filter id="tileShadow" x="-30%" y="-30%" width="160%" height="170%"><feDropShadow dx="0" dy="10" stdDeviation="13" flood-color="#2A2148" flood-opacity=".10"/></filter>
  {defs}
</defs>
<style>
{STYLE}
  .title {{ font:760 72px -apple-system,BlinkMacSystemFont,"Helvetica Neue",sans-serif; fill:#18142A; letter-spacing:-2px; }}
  .meta {{ font:620 24px -apple-system,BlinkMacSystemFont,"Helvetica Neue",sans-serif; fill:#71698A; letter-spacing:4px; }}
  .name {{ font:620 13px -apple-system,BlinkMacSystemFont,"Helvetica Neue",sans-serif; fill:#6C6484; }}
  .tile {{ fill:#fff; fill-opacity:.84; stroke:#fff; stroke-width:2; filter:url(#tileShadow); }}
</style>
<rect width="100%" height="100%" fill="url(#completeBoard)"/>
<circle cx="2050" cy="70" r="260" fill="#8D7CFF" opacity=".10"/>
<circle cx="130" cy="2140" r="280" fill="#FF728E" opacity=".09"/>
<text class="meta" x="92" y="76">PULSE BLOOM / COMPLETE SEMANTIC SET</text>
<text class="title" x="92" y="166">{len(ALL_SEMANTICS)} GLYPHS</text>
<text class="meta" x="1460" y="154">LIGHT · DARK · STATE READY</text>
<path d="M92 204H2108" stroke="#332858" stroke-opacity=".12"/>
{''.join(cells)}
</svg>\n'''
    (ROOT / "pulse-bloom-complete.svg").write_text(svg, encoding="utf-8")


def write_state_preview() -> None:
    samples = ["home", "play", "like", "equalizer", "catAcg", "floatingBall"]
    bodies = semantic_bodies()
    symbols: list[str] = []
    for name in samples:
        body = bodies[name]
        dark_body = (body
            .replace('class="ink"', 'class="ink-dark"')
            .replace('class="soft"', 'class="soft-dark"')
            .replace('class="paper"', 'class="paper-dark"')
            .replace('class="line"', 'class="line-dark"')
            .replace('class="line-soft"', 'class="line-soft-dark"'))
        symbols.append(f'<symbol id="state-{name}" viewBox="0 0 24 24">{body}</symbol>')
        symbols.append(f'<symbol id="state-dark-{name}" viewBox="0 0 24 24">{dark_body}</symbol>')
    defs = "\n".join(symbols)
    cells: list[str] = []
    for col, name in enumerate(samples):
        x = 130 + col * 205
        cells.append(f'''<g transform="translate({x} 300)"><rect class="light-tile" width="150" height="150" rx="42"/><use href="#state-{name}" x="43" y="38" width="64" height="64"/><text class="label" x="75" y="185" text-anchor="middle">{name}</text></g>''')
        cells.append(f'''<g transform="translate({x} 600)"><rect class="dark-tile" width="150" height="150" rx="42"/><use href="#state-dark-{name}" x="43" y="38" width="64" height="64"/><text class="label-dark" x="75" y="185" text-anchor="middle">dark</text></g>''')
        cells.append(f'''<g class="active-icon" transform="translate({x} 900)"><rect class="active-tile" width="150" height="150" rx="52"/><use href="#state-{name}" x="43" y="38" width="64" height="64"/><circle class="pulse" cx="121" cy="29" r="8"/><text class="label" x="75" y="185" text-anchor="middle">selected</text></g>''')
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="1400" height="1400" viewBox="0 0 1400 1400">
<defs>{defs}<filter id="stateShadow" x="-30%" y="-30%" width="160%" height="170%"><feDropShadow dx="0" dy="15" stdDeviation="20" flood-color="#241A42" flood-opacity=".16"/></filter></defs>
<style>
{STYLE}
  .title {{ font:760 68px -apple-system,BlinkMacSystemFont,"Helvetica Neue",sans-serif; fill:#18142A; }}
  .meta {{ font:620 22px -apple-system,BlinkMacSystemFont,"Helvetica Neue",sans-serif; fill:#71698A; letter-spacing:3px; }}
  .label,.label-dark {{ font:650 17px -apple-system,BlinkMacSystemFont,"Helvetica Neue",sans-serif; fill:#71698A; }}
  .label-dark {{ fill:#D8D0F2; }}
  .light-tile {{ fill:#fff; filter:url(#stateShadow); }}
  .dark-tile {{ fill:#19142A; filter:url(#stateShadow); }}
  .active-tile {{ fill:#ECE8FF; stroke:#fff; stroke-width:3; filter:url(#stateShadow); }}
  .ink-dark {{ fill:#F7F4FF; }} .soft-dark {{ fill:#D8D0F2; }} .paper-dark {{ fill:#19142A; }} .line-dark {{ fill:none;stroke:#F7F4FF;stroke-width:2.15;stroke-linecap:round;stroke-linejoin:round; }} .line-soft-dark {{ fill:none;stroke:#D8D0F2;stroke-width:1.55;stroke-linecap:round;stroke-linejoin:round; }}
  .pulse {{ fill:#FF728E; transform-box:fill-box; transform-origin:center; animation:signal 1.7s ease-in-out infinite; }}
  @keyframes signal {{ 0%,100%{{transform:scale(.8);opacity:.7}} 50%{{transform:scale(1.35);opacity:1}} }}
  @media(prefers-reduced-motion:reduce){{*{{animation:none!important}}}}
</style>
<rect width="100%" height="100%" fill="#F6F3FF"/>
<rect x="0" y="520" width="1400" height="280" fill="#211A38"/>
<text class="meta" x="80" y="72">PULSE BLOOM / STATE &amp; CONTRAST</text>
<text class="title" x="80" y="156">ONE SHAPE, THREE STATES</text>
<text class="meta" x="80" y="250">DEFAULT</text><text class="meta" x="80" y="555" fill="#D8D0F2">DARK</text><text class="meta" x="80" y="855">SELECTED + MOTION</text>
{''.join(cells)}
</svg>\n'''
    (ROOT / "pulse-bloom-states.svg").write_text(svg, encoding="utf-8")


def write_semantic_audit_preview() -> None:
    groups = [
        ("PROGRAM", ["podcast", "catPodcast"]),
        ("QUEUE", ["playNext", "addToQueue"]),
        ("RADIO", ["fm", "radio", "fmMode"]),
        ("DOWNLOAD", ["download", "playerDownload", "arrowDownToLine"]),
        ("MESSAGE", ["comment", "hitokoto"]),
        ("SURFACE", ["album", "floatingBall", "tabBar"]),
    ]
    bodies = semantic_bodies()
    names = [name for _, items in groups for name in items]
    defs = "\n".join(f'<symbol id="audit-{n}" viewBox="0 0 24 24">{bodies[n]}</symbol>' for n in names)
    rows: list[str] = []
    for row, (title, items) in enumerate(groups):
        y = 260 + row * 205
        rows.append(f'<text class="section" x="90" y="{y + 65}">{title}</text>')
        for col, name in enumerate(items):
            x = 410 + col * 300
            rows.append(f'''<g transform="translate({x} {y})"><rect class="tile" width="150" height="150" rx="42"/><use href="#audit-{name}" x="43" y="38" width="64" height="64"/><text class="label" x="75" y="185" text-anchor="middle">{name}</text></g>''')
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="1500" height="1500" viewBox="0 0 1500 1500">
<defs><linearGradient id="auditBoard" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#F5F1FF"/><stop offset=".5" stop-color="#F1FAF6"/><stop offset="1" stop-color="#FFF0F4"/></linearGradient><filter id="auditShadow" x="-30%" y="-30%" width="160%" height="170%"><feDropShadow dx="0" dy="14" stdDeviation="18" flood-color="#2A2148" flood-opacity=".13"/></filter>{defs}</defs>
<style>{STYLE}.title{{font:760 66px -apple-system,BlinkMacSystemFont,"Helvetica Neue",sans-serif;fill:#18142A}}.meta{{font:620 21px -apple-system,BlinkMacSystemFont,"Helvetica Neue",sans-serif;fill:#71698A;letter-spacing:3px}}.section{{font:760 22px -apple-system,BlinkMacSystemFont,"Helvetica Neue",sans-serif;fill:#433A62;letter-spacing:2px}}.label{{font:650 17px -apple-system,BlinkMacSystemFont,"Helvetica Neue",sans-serif;fill:#71698A}}.tile{{fill:#fff;filter:url(#auditShadow)}}</style>
<rect width="100%" height="100%" fill="url(#auditBoard)"/><text class="meta" x="90" y="72">PULSE BLOOM / DUPLICATE REPAIR</text><text class="title" x="90" y="150">ONE MEANING, ONE SILHOUETTE</text><path d="M90 195H1410" stroke="#332858" stroke-opacity=".12"/>{''.join(rows)}</svg>\n'''
    (ROOT / "pulse-bloom-semantic-audit.svg").write_text(svg, encoding="utf-8")


def write_appearance_preview() -> None:
    groups = [
        ("IDENTITY", ["themeStyle", "appBrand", "interfaceIconSet", "appearanceMode"]),
        ("NAVIGATION", ["systemTabBar", "floatingBarStyle", "liquidGlass"]),
        ("BACKGROUND", ["fluidBackground", "backgroundGlobal", "backgroundPlaylist", "backgroundPlayer"]),
        ("COLOR", ["colorEngine", "backgroundImage", "gradientStyle"]),
    ]
    bodies = semantic_bodies()
    names = [name for _, items in groups for name in items]
    light_symbols = "\n".join(
        f'<symbol id="appearance-{name}" viewBox="0 0 24 24">{bodies[name]}</symbol>'
        for name in names
    )
    dark_symbols: list[str] = []
    for name in names:
        dark_body = (bodies[name]
            .replace('class="ink"', 'class="ink-dark"')
            .replace('class="soft"', 'class="soft-dark"')
            .replace('class="paper"', 'class="paper-dark"')
            .replace('class="line"', 'class="line-dark"')
            .replace('class="line-soft"', 'class="line-soft-dark"'))
        dark_symbols.append(f'<symbol id="appearance-dark-{name}" viewBox="0 0 24 24">{dark_body}</symbol>')

    rows: list[str] = []
    y = 290
    for title, items in groups:
        rows.append(f'<text class="section" x="72" y="{y + 38}">{title}</text>')
        rows.append(f'<text class="section-dark" x="972" y="{y + 38}">{title}</text>')
        for col, name in enumerate(items):
            light_x = 246 + col * 162
            dark_x = 1146 + col * 162
            rows.append(f'''<g transform="translate({light_x} {y})">
  <use href="#appearance-{name}" x="0" y="0" width="62" height="62"/>
  <text class="label" x="31" y="91" text-anchor="middle">{name}</text>
</g>
<g transform="translate({dark_x} {y})">
  <use href="#appearance-dark-{name}" x="0" y="0" width="62" height="62"/>
  <text class="label-dark" x="31" y="91" text-anchor="middle">{name}</text>
</g>''')
        y += 285

    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="1800" height="1800" viewBox="0 0 1800 1800">
<defs>
  <linearGradient id="appearanceBoard" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#F5F1FF"/><stop offset=".52" stop-color="#F2FBF7"/><stop offset="1" stop-color="#FFF0F4"/></linearGradient>
  {light_symbols}
  {''.join(dark_symbols)}
</defs>
<style>
{STYLE}
  .ink-dark {{ fill:#F7F4FF; }} .soft-dark {{ fill:#D8D0F2; }} .paper-dark {{ fill:#171225; }}
  .line-dark {{ fill:none;stroke:#F7F4FF;stroke-width:2.15;stroke-linecap:round;stroke-linejoin:round; }}
  .line-soft-dark {{ fill:none;stroke:#D8D0F2;stroke-width:1.55;stroke-linecap:round;stroke-linejoin:round; }}
  .title {{ font:760 66px -apple-system,BlinkMacSystemFont,"Helvetica Neue",sans-serif;fill:#18142A;letter-spacing:-1.4px; }}
  .meta {{ font:620 21px -apple-system,BlinkMacSystemFont,"Helvetica Neue",sans-serif;fill:#71698A;letter-spacing:3px; }}
  .section,.section-dark {{ font:760 21px -apple-system,BlinkMacSystemFont,"Helvetica Neue",sans-serif;fill:#433A62;letter-spacing:2px; }}
  .section-dark {{ fill:#D8D0F2; }}
  .label {{ font:650 15px -apple-system,BlinkMacSystemFont,"Helvetica Neue",sans-serif;fill:#71698A; }}
  .label-dark {{ font:650 15px -apple-system,BlinkMacSystemFont,"Helvetica Neue",sans-serif;fill:#D8D0F2; }}
</style>
<rect width="100%" height="100%" fill="url(#appearanceBoard)"/>
<rect x="900" width="900" height="1800" fill="#19142A"/>
<circle cx="1670" cy="80" r="240" fill="#8D7CFF" opacity=".16"/>
<circle cx="110" cy="1420" r="250" fill="#66E8B4" opacity=".10"/>
<text class="meta" x="92" y="74">PULSE BLOOM / APPEARANCE CONTROLS</text>
<text class="title" x="92" y="154">APPEARANCE CONTROLS</text>
<text class="meta" x="1040" y="74" fill="#D8D0F2">DARK / TRANSPARENT ARTWORK</text>
<text class="title" x="1040" y="154" fill="#F7F4FF">TRANSPARENT SVG</text>
<path d="M92 198H820" stroke="#332858" stroke-opacity=".12"/>
<path d="M980 198H1708" stroke="#D8D0F2" stroke-opacity=".18"/>
{''.join(rows)}
</svg>\n'''
    (ROOT / "pulse-bloom-appearance.svg").write_text(svg, encoding="utf-8")


def write_manifest() -> None:
    bodies = semantic_bodies()
    slots = [
        {
            "semantic": semantic,
            "source": STATE_SOURCES.get(semantic, semantic),
            "status": "state-variant" if semantic in STATE_SOURCES else "designed",
            "light": f"icons/{semantic}.svg",
            "dark": f"icons-dark/{semantic}.svg",
        }
        for semantic in ALL_SEMANTICS
    ]
    payload = {
        "family": "Pulse Bloom",
        "grid": 24,
        "coreGlyphCount": len(ICON_BODIES),
        "exportedGlyphCount": len(bodies),
        "semanticSlotCount": len(ALL_SEMANTICS),
        "palette": {"ink": "#1B1730", "soft": "#3A315D", "mint": "#66E8B4", "coral": "#FF728E", "violet": "#8D7CFF"},
        "rules": [
            "weighted organic silhouette instead of uniform native outlines",
            "one open counter-shape whenever the metaphor permits",
            "one signal seed accent at most",
            "minimum optical gap 1.6 px on the 24 px grid",
            "selected state grows the accent layer rather than swapping to an unrelated glyph",
        ],
        "slots": slots,
    }
    (ROOT / "manifest.json").write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def write_readme() -> None:
    count = len(ALL_SEMANTICS)
    (ROOT / "README.md").write_text(f'''# Pulse Bloom / 脉瓣图标系统

为 Mono 设计的非原生风格 SVG 图标家族。它不复刻 SF Symbols 的等宽线框，而是用有重量差的有机轮廓、开放负形和一枚“信号种子”建立识别度。

## 视觉语法

- 24 × 24 基准网格，主要视觉体量控制在 18–20 px。
- 轮廓由柔性曲面、短弧和偏心圆构成，不使用机械式统一描边。
- 深墨色承担主轮廓；薄荷、珊瑚、紫罗兰只表达状态或信息层级。
- 每枚图标最多一个高亮信号点，避免彩色碎片堆叠。
- 静止状态首先保证 16–20 pt 可读；动画只作用于信号点、轨道或状态层。

## 状态规则

- 普通：主轮廓 + 次级层，信号点保持静止。
- 选中：信号层扩展 12–18%，主轮廓不替换，避免跳变。
- 按压：整体缩至 0.94，信号点向触点方向偏移 0.8 px。
- 播放：波形/轨道可做 1.8–2.8 秒非同步循环。
- 禁用：只降低次级层和信号层透明度，主轮廓保持可识别。

## 文件

- `pulse-bloom-preview.svg`：48 枚核心图标设计板，可直接在浏览器中查看悬停与轻动效。
- `pulse-bloom-complete.svg`：Mono 当前 {count} 个语义图标的完整总览。
- `pulse-bloom-states.svg`：默认、深色、选中和动态状态规范。
- `pulse-bloom-appearance.svg`：外观设置专用图标的浅色、深色对照板。
- `icons/*.svg`：{count} 枚浅色环境 SVG 源文件。
- `icons-dark/*.svg`：{count} 枚深色环境 SVG 源文件。
- `manifest.json`：所有语义、状态来源及浅深色文件路径。

## 工程说明

当前目录是完整设计源，不会自动改动 App 的现有图标包或运行时。确认方向后再生成 Xcode 资产目录并接入 `MonoIcon`。
''', encoding="utf-8")


if __name__ == "__main__":
    write_icons()
    write_preview()
    write_complete_preview()
    write_state_preview()
    write_semantic_audit_preview()
    write_appearance_preview()
    write_manifest()
    write_readme()
    print(f"generated {len(semantic_bodies())} light + dark icons in {ROOT}")
