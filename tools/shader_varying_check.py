#!/usr/bin/env python3
"""Shader varying budget check (design 1 Oct §CG: the game draws the same on every machine).

Godot gives every `varying` in a spatial shader one slot (mat2 2, mat3 3, mat4 4, arrays
times their length), numbered after the slots its own Forward+ scene shader keeps for
itself. From Godot 4.4 on, a shader whose last slot passes the GPU's limit is REJECTED
when it compiles ("Too many varyings used in shader (N used, maximum supported is M)"),
and every material using it is drawn with Godot's grey default material instead: the
grey boxes of Mike's 1 Oct 23:11 and 2 Oct 22:52 plays.

Read from Godot's own source (servers/rendering/renderer_rd/forward_clustered/
scene_shader_forward_clustered.cpp `base_varying_index`; shader_language.cpp, the check):

    Godot      slots Godot keeps   checked?   limit (Metal / desktop Vulkan)
    4.3        12                  no         (31 / 32 in hardware)
    4.4, 4.5   14                  yes        31 / 32
    4.6, 4.7   15                  yes        31 / 32

So a spatial shader may use at most 31 - 15 = 16 slots on a Mac with Godot 4.6 or later.
The house limit is 12, so the next few Godot releases (which have kept more slots each
time: 12, 14, 15) still fit.

Usage:  python3 tools/shader_varying_check.py [--house N] [shader files...]
Exit 1 if any spatial shader is over the house limit.
"""
import argparse
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
RESERVED = {"4.3": 12, "4.4": 14, "4.5": 14, "4.6": 15, "4.7": 15}
CHECKED = {"4.3": False, "4.4": True, "4.5": True, "4.6": True, "4.7": True}
METAL_MAX = 31  # Apple GPUs (Godot's Metal driver; MoltenVK: 124 components / 4)
VULKAN_MAX = 32  # typical desktop Vulkan: min(maxVertexOutputComponents, maxFragmentInputComponents) / 4
HOUSE_LIMIT = 12

DECL = re.compile(
    r"^\s*varying\s+(?:(?:flat|smooth)\s+)?(?:(?:lowp|mediump|highp)\s+)?(\w+)\s+([^;]+);",
    re.MULTILINE,
)
INCLUDE = re.compile(r'^\s*#include\s+"res://([^"]+)"', re.MULTILINE)
TYPE = re.compile(r"^\s*shader_type\s+(\w+)\s*;", re.MULTILINE)
SIZE = {"mat2": 2, "mat3": 3, "mat4": 4}


def strip_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    return re.sub(r"//[^\n]*", "", text)


def varyings(path: pathlib.Path, seen=None):
    """[(type, name, slots)] declared in `path` and the files it includes."""
    seen = seen if seen is not None else set()
    if path in seen or not path.exists():
        return []
    seen.add(path)
    text = strip_comments(path.read_text(encoding="utf-8"))
    out = []
    for inc in INCLUDE.findall(text):
        out += varyings(ROOT / inc, seen)
    for vtype, names in DECL.findall(text):
        for part in names.split(","):
            m = re.match(r"\s*(\w+)\s*(?:\[\s*(\d+)\s*\])?\s*$", part)
            if not m:
                continue
            count = int(m.group(2)) if m.group(2) else 1
            out.append((vtype, m.group(1), SIZE.get(vtype, 1) * count))
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--house", type=int, default=HOUSE_LIMIT, help="the most slots a spatial shader may use (default 12)")
    ap.add_argument("files", nargs="*", help="shader files (default: shaders/*.gdshader)")
    args = ap.parse_args()
    files = [pathlib.Path(f).resolve() for f in args.files] or sorted((ROOT / "shaders").glob("*.gdshader"))

    newest = max(RESERVED, key=lambda v: tuple(int(x) for x in v.split(".")))
    hard = METAL_MAX - RESERVED[newest]
    print(f"Spatial shaders: slots used (house limit {args.house}; Godot {newest} on a Mac rejects more than {hard})")
    fails = 0
    for f in files:
        text = strip_comments(f.read_text(encoding="utf-8"))
        st = TYPE.search(text)
        kind = st.group(1) if st else "?"
        vs = varyings(f)
        slots = sum(s for _, _, s in vs)
        if kind != "spatial":
            if slots:
                print(f"  {f.name:28s} {kind}: {slots} slots (not a Forward+ scene shader; not budgeted here)")
            continue
        verdicts = []
        for ver in RESERVED:
            last = RESERVED[ver] + slots
            if not CHECKED[ver]:
                verdicts.append(f"{ver} {last}/31 (unchecked)")
            elif last > METAL_MAX:
                verdicts.append(f"{ver} {last}/31 REJECTED")
            else:
                verdicts.append(f"{ver} {last}/31")
        state = "FAIL" if slots > args.house else "ok"
        if slots > args.house:
            fails += 1
        if slots or state == "FAIL":
            print(f"  {state:4s} {f.name:26s} {slots:2d} slots  | " + " · ".join(verdicts))
            if state == "FAIL":
                for vtype, name, s in vs:
                    print(f"         {vtype:6s} {name}" + (f" ({s} slots)" if s > 1 else ""))
    print(f"{fails} over the house limit." if fails else "All spatial shaders within the house limit.")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
