#!/usr/bin/env python3
"""Export Pulse Bloom artwork as CoreSVG-compatible Xcode asset catalog images."""

from __future__ import annotations

import json
import xml.etree.ElementTree as ET
from pathlib import Path

import generate


ROOT = Path(__file__).resolve().parent
PACKAGE = ROOT.parents[2] / "Packages" / "Icons" / "PulseBloomIcons"
CATALOG = PACKAGE / "Sources" / "PulseBloomIcons" / "icons.xcassets"

LIGHT = {
    "ink": {"fill": "#1B1730"},
    "soft": {"fill": "#3A315D"},
    "mint": {"fill": "#66E8B4"},
    "coral": {"fill": "#FF728E"},
    "violet": {"fill": "#8D7CFF"},
    "paper": {"fill": "#F7F5FF"},
    "line": {"fill": "none", "stroke": "#1B1730", "stroke-width": "2.15", "stroke-linecap": "round", "stroke-linejoin": "round"},
    "line-soft": {"fill": "none", "stroke": "#3A315D", "stroke-width": "1.55", "stroke-linecap": "round", "stroke-linejoin": "round"},
}

DARK = {
    **LIGHT,
    "ink": {"fill": "#F7F4FF"},
    "soft": {"fill": "#D8D0F2"},
    "paper": {"fill": "#171225"},
    "line": {"fill": "none", "stroke": "#F7F4FF", "stroke-width": "2.15", "stroke-linecap": "round", "stroke-linejoin": "round"},
    "line-soft": {"fill": "none", "stroke": "#D8D0F2", "stroke-width": "1.55", "stroke-linecap": "round", "stroke-linejoin": "round"},
}


def production_svg(body: str, palette: dict[str, dict[str, str]]) -> str:
    group = ET.fromstring(f"<g>{body}</g>")
    for node in group.iter():
        class_name = node.attrib.pop("class", None)
        if class_name and class_name in palette:
            for key, value in palette[class_name].items():
                node.set(key, value)
    root = ET.Element("svg", {
        "xmlns": "http://www.w3.org/2000/svg",
        "width": "24",
        "height": "24",
        "viewBox": "0 0 24 24",
    })
    root.append(group)
    ET.indent(root, space="  ")
    return ET.tostring(root, encoding="unicode", short_empty_elements=True) + "\n"


def write_package() -> None:
    source = PACKAGE / "Sources" / "PulseBloomIcons"
    source.mkdir(parents=True, exist_ok=True)
    CATALOG.mkdir(parents=True, exist_ok=True)

    (PACKAGE / "Package.swift").write_text('''// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PulseBloomIcons",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "PulseBloomIcons", targets: ["PulseBloomIcons"]),
    ],
    targets: [
        .target(name: "PulseBloomIcons", resources: [.process("icons.xcassets")]),
    ]
)
''', encoding="utf-8")

    (source / "PulseBloomIcons.swift").write_text('''import Foundation
import UIKit

public struct PulseBloomIcons {}

public extension UIImage {
    convenience init?(pulseBloomIconId: String) {
        self.init(named: pulseBloomIconId, in: Bundle.module, compatibleWith: nil)
    }

    convenience init?(pulseBloomIconId: String, userInterfaceStyle: UIUserInterfaceStyle) {
        self.init(
            named: pulseBloomIconId,
            in: Bundle.module,
            compatibleWith: UITraitCollection(userInterfaceStyle: userInterfaceStyle)
        )
    }
}
''', encoding="utf-8")

    (CATALOG / "Contents.json").write_text(json.dumps({
        "info": {"author": "xcode", "version": 1}
    }, indent=2) + "\n", encoding="utf-8")

    for semantic, body in generate.semantic_bodies().items():
        imageset = CATALOG / f"{semantic}.imageset"
        imageset.mkdir(parents=True, exist_ok=True)
        (imageset / f"{semantic}.svg").write_text(production_svg(body, LIGHT), encoding="utf-8")
        (imageset / f"{semantic}_dark.svg").write_text(production_svg(body, DARK), encoding="utf-8")
        contents = {
            "images": [
                {"filename": f"{semantic}.svg", "idiom": "universal", "scale": "1x"},
                {
                    "appearances": [{"appearance": "luminosity", "value": "dark"}],
                    "filename": f"{semantic}_dark.svg",
                    "idiom": "universal",
                    "scale": "1x",
                },
            ],
            "info": {"author": "xcode", "version": 1},
            "properties": {"preserves-vector-representation": True},
        }
        (imageset / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    write_package()
    print(f"exported {len(generate.semantic_bodies())} adaptive icons to {PACKAGE}")
