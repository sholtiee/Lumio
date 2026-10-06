#!/usr/bin/env python3
"""Builds Lumio/Resources/Localizable.xcstrings from the keys Xcode extracted
during the last build (build/**/*.stringsdata) and scripts/ru.json.
Run `make build` first; missing translations are listed and left English."""
import json, pathlib, sys

root = pathlib.Path(__file__).resolve().parent.parent
ru = json.loads((root / "scripts/ru.json").read_text())
keys = set()
decoder = json.JSONDecoder()
for path in root.glob("build/Build/Intermediates.noindex/Lumio.build/*/Lumio.build/**/*.stringsdata"):
    data = path.read_text()
    obj, _ = decoder.raw_decode(data)
    for table in obj.get("tables", {}).values():
        keys.update(entry["key"] for entry in table)

strings = {}
for key in sorted(keys):
    entry = {}
    if key in ru:
        entry["localizations"] = {"ru": {"stringUnit": {"state": "translated", "value": ru[key]}}}
    strings[key] = entry
catalog = {"sourceLanguage": "en", "strings": strings, "version": "1.0"}
out = root / "Lumio/Resources/Localizable.xcstrings"
out.write_text(json.dumps(catalog, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
missing = sorted(k for k in keys if k not in ru)
print(f"{len(keys)} keys, {len(missing)} untranslated")
for k in missing: print("  missing:", k)
sys.exit(1 if missing else 0)
