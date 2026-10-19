#!/usr/bin/env python3
"""Extract the Golden/RIT acrylic drawdown spectra to a flat CSV.

Offline ingest step 1 (DATA-5). Reads the archived source workbook
`tool/ingest/raw/rit/GoldenSpectra.zip` — "Reflectance Data for Golden HB 10 mil
Drawdowns over White.xlsx" (Okumura 2005; Berns/RIT Art Spectral Database;
redistribution per the written permission held, gate G-3) — and writes
`tool/ingest/raw/rit/golden_spectra.csv`, the tracked, reproducible input the
Dart ingest (`tool/ingest/acrylic.dart`) reads.

The workbook (sheet 1) lays out, per paint row: Prod # (col A), Name (col B),
published L*/a*/b* under D65/10° (cols C/D/E), and % Reflectance at 400–700 nm
@ 10 nm (cols G..AK = the canonical 31-bin grid). % Reflectance is stored in
percent; this writes it as a 0..1 fraction. No resampling — the native grid is
already the canonical grid.

Pure standard library (an .xlsx is a zip of XML), so no third-party dependency.
Run with `python3 -I tool/ingest/extract_golden.py` from the repo root.
"""
import csv
import re
import sys
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

NS = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}"
ROOT = Path(__file__).resolve().parents[2]
ZIP = ROOT / "tool/ingest/raw/rit/GoldenSpectra.zip"
XLSX_NAME = "Reflectance Data for Golden HB 10 mil Drawdowns over White.xlsx"
OUT = ROOT / "tool/ingest/raw/rit/golden_spectra.csv"
WAVELENGTHS = list(range(400, 701, 10))  # 31 canonical bins
REFL_COL0 = 7  # column G (1-based): the 400 nm reflectance sample


def _col_to_num(col: str) -> int:
    n = 0
    for ch in col:
        n = n * 26 + (ord(ch) - 64)
    return n


def _cellref(ref: str):
    m = re.match(r"([A-Z]+)(\d+)", ref)
    return _col_to_num(m.group(1)), int(m.group(2))


def main() -> int:
    if not ZIP.exists():
        print(f"missing source workbook: {ZIP}", file=sys.stderr)
        return 1
    with zipfile.ZipFile(ZIP) as outer:
        with outer.open(XLSX_NAME) as fh:
            wb = zipfile.ZipFile(fh)
            strings = [
                "".join(t.text or "" for t in si.iter(NS + "t"))
                for si in ET.fromstring(wb.read("xl/sharedStrings.xml")).findall(NS + "si")
            ]
            rows: dict[int, dict[int, str]] = {}
            for c in ET.fromstring(wb.read("xl/worksheets/sheet1.xml")).iter(NS + "c"):
                v = c.find(NS + "v")
                if v is None:
                    continue
                col, row = _cellref(c.get("r"))
                val = strings[int(v.text)] if c.get("t") == "s" else v.text
                rows.setdefault(row, {})[col] = val

    # Header row 2 pins the reflectance wavelengths; assert the canonical grid.
    header = [rows[2].get(REFL_COL0 + i) for i in range(len(WAVELENGTHS))]
    assert [int(float(h)) for h in header] == WAVELENGTHS, f"unexpected grid: {header}"

    out_rows = []
    for r in range(3, 81):
        cells = rows.get(r)
        if not cells:
            continue
        name = (cells.get(2) or "").strip()
        if not name:
            continue
        refl = [float(cells[REFL_COL0 + i]) / 100.0 for i in range(len(WAVELENGTHS))]
        out_rows.append(
            [cells.get(1), name, cells.get(3), cells.get(4), cells.get(5)] + refl
        )

    assert len(out_rows) == 78, f"expected 78 paints, got {len(out_rows)}"
    with OUT.open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["prod", "name", "L", "a", "b"] + [f"R{nm}" for nm in WAVELENGTHS])
        w.writerows(out_rows)
    print(f"wrote {OUT} ({len(out_rows)} paints)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
