"""Measure the native CORDIC worker on a representative iCE40 HX8K target.

Requires GHDL, Yosys, and nextpnr-ice40. Set CORDIC_FPGA_TOOL_ROOT to a package
root containing usr/bin and usr/share when the latter two are not installed.
"""

from pathlib import Path
import json
import os
import shutil
import subprocess
from collections import Counter


APP = Path(__file__).resolve().parents[2]
WORK = APP / "out" / "cordic-ice40-hx8k"
TOP = "cordic_sin_cos_q15_synthesis_top"


def tool(name: str, root: Path | None) -> Path:
    installed = shutil.which(name)
    if installed:
        return Path(installed)
    if root:
        candidate = root / "usr/bin" / name
        if candidate.exists():
            return candidate
    raise SystemExit(f"missing {name}; install it or set CORDIC_FPGA_TOOL_ROOT")


def main() -> None:
    WORK.mkdir(parents=True, exist_ok=True)
    root_value = os.environ.get("CORDIC_FPGA_TOOL_ROOT")
    root = Path(root_value).resolve() if root_value else None
    ghdl = tool("ghdl", None)
    yosys = tool("yosys", root)
    nextpnr = tool("nextpnr-ice40", root)

    sources = [
        APP / "out/debug/lib/Livt.Lang.Package.vhd",
        APP / "out/debug/lib/Livt.Lang.IContext.Package.vhd",
        APP / "src/trigonometry/CordicSinCosQ15Primitive.vhd",
        APP / "tests/rtl/CordicSinCosQ15SynthesisTop.vhd",
    ]
    subprocess.run([ghdl, "-a", "--std=08", *map(str, sources)], cwd=WORK, check=True)
    verilog = subprocess.run(
        [ghdl, "--synth", "--std=08", "--out=verilog", TOP],
        cwd=WORK,
        check=True,
        text=True,
        capture_output=True,
    ).stdout
    verilog_path = WORK / "cordic.v"
    verilog_path.write_text(verilog)

    environment = os.environ.copy()
    if root:
        environment["YOSYS_DATDIR"] = str(root / "usr/share/yosys")
        library = str(root / "usr/lib/x86_64-linux-gnu")
        environment["LD_LIBRARY_PATH"] = library + os.pathsep + environment.get(
            "LD_LIBRARY_PATH", ""
        )

    json_path = WORK / "cordic.json"
    yosys_command = (
        f"read_verilog {verilog_path}; "
        f"synth_ice40 -top {TOP} -json {json_path}; stat"
    )
    yosys_run = subprocess.run(
        [yosys, "-Q", "-p", yosys_command],
        cwd=WORK,
        env=environment,
        check=True,
        text=True,
        capture_output=True,
    )
    (WORK / "yosys.log").write_text(yosys_run.stdout + yosys_run.stderr)
    netlist = json.loads(json_path.read_text())
    cells = Counter(
        cell["type"] for cell in netlist["modules"][TOP]["cells"].values()
    )

    report_path = WORK / "nextpnr-report.json"
    nextpnr_command = [
        nextpnr,
        "--hx8k",
        "--package",
        "ct256",
        "--json",
        json_path,
        "--asc",
        WORK / "cordic.asc",
        "--report",
        report_path,
        "--freq",
        "50",
        "--seed",
        "1",
        "--pcf-allow-unconstrained",
    ]
    if root:
        bubblewrap = tool("bwrap", None)
        nextpnr_command = [
            bubblewrap,
            "--ro-bind",
            "/",
            "/",
            "--ro-bind",
            root / "usr/share",
            "/usr/share",
            "--bind",
            WORK,
            WORK,
            *nextpnr_command,
        ]
    nextpnr_run = subprocess.run(
        list(map(str, nextpnr_command)),
        cwd=WORK,
        env=environment,
        check=True,
        text=True,
        capture_output=True,
    )
    (WORK / "nextpnr.log").write_text(nextpnr_run.stdout + nextpnr_run.stderr)

    report = json.loads(report_path.read_text())
    clock = next(iter(report.get("fmax", {}).values()), {})
    result = {
        "target": "Lattice iCE40 HX8K CT256",
        "constraint_mhz": 50,
        "yosys": subprocess.run(
            [yosys, "-V"], env=environment, text=True, capture_output=True, check=True
        ).stdout.strip(),
        "nextpnr": subprocess.run(
            [nextpnr, "--version"],
            env=environment,
            text=True,
            capture_output=True,
            check=True,
        ).stderr.strip(),
        "logic_cells": report["utilization"]["ICESTORM_LC"]["used"],
        "flip_flops": sum(
            count for cell, count in cells.items() if cell.startswith("SB_DFF")
        ),
        "lut4": cells.get("SB_LUT4", 0),
        "carry_cells": cells.get("SB_CARRY", 0),
        "dsp_blocks": cells.get("SB_MAC16", 0),
        "ram_blocks": report["utilization"]["ICESTORM_RAM"]["used"],
        "achieved_mhz": clock.get("achieved"),
    }
    (WORK / "result.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
