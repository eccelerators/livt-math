"""Check generated special-function arithmetic remains shift/add based."""

from pathlib import Path
import re


APP = Path(__file__).resolve().parents[2]


def generated_source(name: str) -> str:
    path = APP / "out" / "debug" / "main" / name
    source = path.read_text()
    source = re.sub(r"--.*", "", source)
    return source.replace("/=", "")


def main() -> None:
    shift_add_components = [
        "Livt.Math.Approximation.Log2UQ15.vhd",
        "Livt.Math.Approximation.Exp2Q11.vhd",
        "Livt.Math.Approximation.TanhQ15.vhd",
    ]
    shift_add_components.extend(
        path.name
        for path in (APP / "out" / "debug" / "main").glob(
            "Livt.Math.Approximation.LinearInterpolationQ15_*.vhd"
        )
        if ".Package." not in path.name
    )
    assert len(shift_add_components) == 5, shift_add_components
    for component in shift_add_components:
        source = generated_source(component)
        assert "*" not in source, component
        assert "/" not in source, component

    reciprocal = generated_source("Livt.Math.FixedPoint.ReciprocalUQ15.vhd")
    assert "unsigneddivision" in reciprocal.lower()
    print("special-function structure: shift/add interpolation and iterative reciprocal")


if __name__ == "__main__":
    main()
