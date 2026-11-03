"""Compile and run the native CORDIC lifecycle/latency test.

Run after `livt build` so the generated wrapper and language packages exist.
"""

from pathlib import Path
import subprocess


APP = Path(__file__).resolve().parents[2]
WORK = APP / "out" / "cordic-lifecycle-test"


def main() -> None:
    WORK.mkdir(parents=True, exist_ok=True)
    files = [
        APP / "out/debug/lib/Livt.Lang.Package.vhd",
        APP / "out/debug/lib/Livt.Lang.IContext.Package.vhd",
        APP / "out/debug/lib/Livt.Lang.IComponent.Package.vhd",
        APP / "out/debug/main/Livt.Math.Trigonometry.CordicSinCosQ15Primitive.Package.vhd",
        APP / "out/debug/main/Livt.Math.Trigonometry.CordicSinCosQ15.Package.vhd",
        APP / "out/debug/main/CordicSinCosQ15Primitive.vhd",
        APP / "out/debug/main/Livt.Math.Trigonometry.CordicSinCosQ15.vhd",
        APP / "tests/rtl/CordicSinCosQ15LifecycleTb.vhd",
    ]
    subprocess.run(["ghdl", "-a", "--std=08", *map(str, files)], cwd=WORK, check=True)
    subprocess.run(
        ["ghdl", "-e", "--std=08", "cordic_sin_cos_q15_lifecycle_tb"],
        cwd=WORK,
        check=True,
    )
    subprocess.run(
        [
            "ghdl",
            "-r",
            "--std=08",
            "cordic_sin_cos_q15_lifecycle_tb",
            "--assert-level=error",
        ],
        cwd=WORK,
        check=True,
    )


if __name__ == "__main__":
    main()
