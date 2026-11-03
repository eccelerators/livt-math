"""Compile and run the vectoring CORDIC lifecycle test after `livt build`."""

from pathlib import Path
import subprocess


APP = Path(__file__).resolve().parents[2]
WORK = APP / "out" / "cordic-vectoring-lifecycle-test"


def main() -> None:
    WORK.mkdir(parents=True, exist_ok=True)
    files = [
        APP / "out/debug/lib/Livt.Lang.Package.vhd",
        APP / "out/debug/lib/Livt.Lang.IContext.Package.vhd",
        APP / "out/debug/lib/Livt.Lang.IComponent.Package.vhd",
        APP / "out/debug/main/Livt.Math.Trigonometry.CordicAtan2MagnitudeQ15Primitive.Package.vhd",
        APP / "out/debug/main/Livt.Math.Trigonometry.CordicAtan2MagnitudeQ15.Package.vhd",
        APP / "out/debug/main/CordicAtan2MagnitudeQ15Primitive.vhd",
        APP / "out/debug/main/Livt.Math.Trigonometry.CordicAtan2MagnitudeQ15.vhd",
        APP / "tests/rtl/CordicAtan2MagnitudeQ15LifecycleTb.vhd",
    ]
    subprocess.run(["ghdl", "-a", "--std=08", *map(str, files)], cwd=WORK, check=True)
    subprocess.run(
        ["ghdl", "-e", "--std=08", "cordic_atan2_magnitude_q15_lifecycle_tb"],
        cwd=WORK,
        check=True,
    )
    subprocess.run(
        [
            "ghdl", "-r", "--std=08",
            "cordic_atan2_magnitude_q15_lifecycle_tb",
            "--assert-level=error",
        ],
        cwd=WORK,
        check=True,
    )


if __name__ == "__main__":
    main()
