"""Synthesize the vectoring CORDIC and enforce its arithmetic structure."""

from pathlib import Path
import re
import subprocess


APP = Path(__file__).resolve().parents[2]
WORK = APP / "out" / "cordic-vectoring-structure-test"
ENTITY = "livt_math_trigonometry_cordicatan2magnitudeq15primitive"


def main() -> None:
    WORK.mkdir(parents=True, exist_ok=True)
    sources = [
        APP / "out/debug/lib/Livt.Lang.Package.vhd",
        APP / "out/debug/lib/Livt.Lang.IContext.Package.vhd",
        APP / "src/trigonometry/CordicAtan2MagnitudeQ15Primitive.vhd",
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

    variable_shifts = len(re.findall(r">>>\s+[A-Za-z_]", logic))
    multipliers = len(re.findall(r"\s\*\s", logic))
    dividers = len(re.findall(r"\s/\s", logic))
    assert variable_shifts == 2, variable_shifts
    assert multipliers == 0, multipliers
    assert dividers == 0, dividers
    print(
        "vectoring structure: two shared variable shifters, "
        "no multiplier, no divider"
    )


if __name__ == "__main__":
    main()
