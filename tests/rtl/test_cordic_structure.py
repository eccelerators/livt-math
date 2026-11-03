"""Synthesize the narrow CORDIC worker and enforce its structural budget.

This is tool-independent structural evidence, not an FPGA LUT/timing report.
Run after `livt build` so the generated language context package exists.
"""

from pathlib import Path
import json
import re
import subprocess


APP = Path(__file__).resolve().parents[2]
WORK = APP / "out" / "cordic-structure-test"
ENTITY = "livt_math_trigonometry_cordicsincosq15primitive"


def width(declaration: str) -> int:
    match = re.search(r"\[(\d+):0\]", declaration)
    return int(match.group(1)) + 1 if match else 1


def main() -> None:
    WORK.mkdir(parents=True, exist_ok=True)
    sources = [
        APP / "out/debug/lib/Livt.Lang.Package.vhd",
        APP / "out/debug/lib/Livt.Lang.IContext.Package.vhd",
        APP / "src/trigonometry/CordicSinCosQ15Primitive.vhd",
    ]
    subprocess.run(["ghdl", "-a", "--std=08", *map(str, sources)], cwd=WORK, check=True)
    synthesized = subprocess.run(
        ["ghdl", "--synth", "--std=08", "--out=verilog", ENTITY],
        cwd=WORK,
        check=True,
        text=True,
        capture_output=True,
    ).stdout
    logic = re.sub(r"/\*.*?\*/", "", synthesized, flags=re.DOTALL)
    logic = re.sub(r"//.*", "", logic)

    declarations = {
        match.group(2): match.group(0)
        for match in re.finditer(r"\breg\s+(\[[^]]+\]\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*;", logic)
    }
    clocked = set(re.findall(r"always @\(posedge [^)]+\)\s+([A-Za-z_][A-Za-z0-9_]*) <=", logic))
    registered_bits = sum(width(declarations[name]) for name in clocked)
    variable_shifts = len(re.findall(r">>>\s+[A-Za-z_]", logic))
    multipliers = len(re.findall(r"\s\*\s", logic))
    dividers = len(re.findall(r"\s/\s", logic))

    result = {
        "tool": subprocess.run(
            ["ghdl", "--version"], text=True, capture_output=True, check=True
        ).stdout.splitlines()[0],
        "registered_bits": registered_bits,
        "variable_right_shifts": variable_shifts,
        "multipliers": multipliers,
        "dividers": dividers,
        "coordinate_bits": 19,
        "residual_angle_bits": 20,
        "iteration_bits": 4,
    }
    (WORK / "result.json").write_text(json.dumps(result, indent=2) + "\n")

    assert registered_bits <= 100, result
    assert variable_shifts == 2, result
    assert multipliers == 0, result
    assert dividers == 0, result
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
