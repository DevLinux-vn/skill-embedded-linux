#!/usr/bin/env python3
"""Validate the skills in this repository.

Checks (always):
  * SKILL.md frontmatter: name == directory, description present, <= 1024
    chars, contains "Use when" and "Do NOT use".
  * SKILL.md length < 500 lines.
  * Reference chapters: "Status:" line; non-stub chapters need a "Verified:"
    line (kernel=/yocto=/buildroot=) and the 8-section frame (## 1. .. ## 8.).
  * Dead links: markdown links and backticked repo paths must exist.
  * Eval files (tests/evals/*.json): valid JSON with required keys.
  * Shell scripts: bash -n (and shellcheck, if installed).

Checks that need external tools (each reports PASS, FAIL or SKIP with the
reason; SKIP never hides a failure that could have been detected):
  * templates/*.c      compiled against a prepared kernel tree (--kdir):
                       make M=<tmp> W=1 <obj>, any warning is a failure.
  * templates/*.dts    dtc; with --base-dtb, applied to it via fdtoverlay.
  * templates/*.yaml   parsed with PyYAML.
  * templates/*.cmake  configure + build a tiny project with the cross compiler.
  * Makefile.cross     built for the cross targets whose compiler exists.

Usage:
  tools/validate_skills.py [--kdir KERNEL_DIR] [--base-dtb BASE.dtb]
                           [--arch arm64] [--cross-compile aarch64-linux-gnu-]
                           [--require-toolchain] [--root REPO]
Exit status: 1 if any FAIL (or any SKIP with --require-toolchain), else 0.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

MAX_SKILL_LINES = 500
MAX_DESC_CHARS = 1024
SECTION_RE = re.compile(r"^## ([1-8])\. (.*)$", re.M)
SECTION_TITLES = ["When to use", "Conceptual model", "API and kernel versions",
                  "Device Tree binding", "Minimal example", "Common pitfalls",
                  "How to test", "References"]
LINK_RE = re.compile(r"(?<!\!)\[[^\]]*\]\(([^)\s]+)\)")
TICK_RE = re.compile(r"`([^`\n]+)`")
PATH_TOKEN_RE = re.compile(
    r"^(?:(?:\.\./)+|skills/|elinux-[a-z-]+/)?"
    r"(?:references|templates|scripts|tests|tools|docs|targets|subsystems|"
    r"device-model|fundamentals|bsp-notes)/[A-Za-z0-9_./%+-]+$"
    r"|^skills/elinux-[a-z-]+/[A-Za-z0-9_./%+-]+$"
    r"|^elinux-[a-z-]+/[A-Za-z0-9_./%+-]+$"
)
# Paths that live in a *kernel source tree*, not in this repository.
KERNEL_TREE_PATHS = ("scripts/kconfig/", "scripts/checkpatch.pl",
                     "scripts/faddr2line", "scripts/decode_stacktrace.sh")
EVAL_KEYS = {"id", "title", "skills", "profile", "prompt", "must", "must_not", "verify"}


class Report:
    def __init__(self) -> None:
        self.fails = 0
        self.skips = 0
        self.passes = 0

    def ok(self, msg: str) -> None:
        self.passes += 1
        print(f"PASS  {msg}")

    def fail(self, msg: str) -> None:
        self.fails += 1
        print(f"FAIL  {msg}")

    def skip(self, msg: str) -> None:
        self.skips += 1
        print(f"SKIP  {msg}")


def rel(p: Path, root: Path) -> str:
    try:
        return str(p.relative_to(root))
    except ValueError:
        return str(p)


def parse_frontmatter(text: str) -> dict[str, str] | None:
    if not text.startswith("---\n"):
        return None
    end = text.find("\n---", 4)
    if end < 0:
        return None
    out: dict[str, str] = {}
    for line in text[4:end].splitlines():
        m = re.match(r"^([A-Za-z_-]+):\s*(.*)$", line)
        if m:
            out[m.group(1)] = m.group(2).strip().strip('"')
    return out


def run(cmd: list[str], **kw) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


# --------------------------------------------------------------------- SKILL.md
def check_skill_md(skill: Path, root: Path, r: Report) -> None:
    f = skill / "SKILL.md"
    name = rel(f, root)
    if not f.is_file():
        r.fail(f"{name}: missing")
        return
    text = f.read_text(encoding="utf-8")
    fm = parse_frontmatter(text)
    if fm is None:
        r.fail(f"{name}: no frontmatter")
        return
    if fm.get("name") != skill.name:
        r.fail(f"{name}: frontmatter name {fm.get('name')!r} != directory {skill.name!r}")
    else:
        r.ok(f"{name}: name matches directory")
    desc = fm.get("description", "")
    if not desc:
        r.fail(f"{name}: empty description")
    else:
        problems = []
        if len(desc) > MAX_DESC_CHARS:
            problems.append(f"{len(desc)} chars > {MAX_DESC_CHARS}")
        if "Use when" not in desc:
            problems.append('missing "Use when"')
        if "Do NOT use" not in desc:
            problems.append('missing "Do NOT use"')
        if problems:
            r.fail(f"{name}: description: {', '.join(problems)}")
        else:
            r.ok(f"{name}: description has use / do-not-use ({len(desc)} chars)")
    n = len(text.splitlines())
    if n >= MAX_SKILL_LINES:
        r.fail(f"{name}: {n} lines (limit < {MAX_SKILL_LINES})")
    else:
        r.ok(f"{name}: {n} lines")


# --------------------------------------------------------------------- chapters
def check_chapter(f: Path, root: Path, r: Report) -> None:
    name = rel(f, root)
    text = f.read_text(encoding="utf-8")
    m = re.search(r"^Status:\s*(.+)$", text, re.M)
    if not m:
        r.fail(f"{name}: no 'Status:' line")
        return
    status = m.group(1).strip().lower()
    if status.startswith("stub"):
        r.ok(f"{name}: stub (reported, not validated)")
        return
    if not status.startswith("complete"):
        r.fail(f"{name}: unknown status {m.group(1)!r}")
        return
    problems = []
    v = re.search(r"^Verified:\s*(.+)$", text, re.M)
    if not v:
        problems.append("no 'Verified:' line")
    else:
        for key in ("kernel=", "yocto=", "buildroot="):
            if key not in v.group(1):
                problems.append(f"Verified lacks {key}")
    found = SECTION_RE.findall(text)
    if [n for n, _ in found] != [str(i) for i in range(1, 9)]:
        problems.append(f"section numbers are {[n for n, _ in found]}, expected 1..8")
    else:
        for (n, title), want in zip(found, SECTION_TITLES):
            if not title.startswith(want):
                problems.append(f"section {n} is '{title}', expected '{want}...'")
    if problems:
        r.fail(f"{name}: " + "; ".join(problems))
    else:
        r.ok(f"{name}: 8 sections, verified line")


# ------------------------------------------------------------------------ links
def resolve_candidates(token: str, md: Path, root: Path) -> list[Path]:
    token = token.split("#", 1)[0]
    skill = next((p for p in [md, *md.parents] if p.parent.name == "skills"), None)
    bases = [md.parent, root, root / "skills"]
    if skill is not None:
        bases.append(skill)
    return [(b / token) for b in bases]


def check_links(md: Path, root: Path, r: Report) -> None:
    name = rel(md, root)
    text = md.read_text(encoding="utf-8")
    dead: list[str] = []
    for target in LINK_RE.findall(text):
        if re.match(r"^[a-z]+://|^mailto:|^#", target):
            continue
        t = target.split("#", 1)[0]
        if t and not (md.parent / t).exists():
            dead.append(target)
    in_fence = False
    for line in text.splitlines():
        if line.startswith("```"):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        for tok in TICK_RE.findall(line):
            tok = tok.strip()
            if any(c in tok for c in "<>*{}$ \t()") or "..." in tok:
                continue
            if not PATH_TOKEN_RE.match(tok) or tok.startswith(KERNEL_TREE_PATHS):
                continue
            if not any(c.exists() for c in resolve_candidates(tok, md, root)):
                dead.append(tok)
    if dead:
        r.fail(f"{name}: dead links/paths: {sorted(set(dead))}")
    else:
        r.ok(f"{name}: links ok")


# ------------------------------------------------------------------------ evals
def check_evals(root: Path, r: Report) -> None:
    d = root / "tests" / "evals"
    files = sorted(d.glob("*.json")) if d.is_dir() else []
    if not files:
        r.fail("tests/evals: no eval files")
        return
    for f in files:
        name = rel(f, root)
        try:
            data = json.loads(f.read_text(encoding="utf-8"))
        except json.JSONDecodeError as e:
            r.fail(f"{name}: invalid JSON: {e}")
            continue
        missing = EVAL_KEYS - set(data)
        bad_lists = [k for k in ("skills", "must", "must_not", "verify")
                     if k in data and not (isinstance(data[k], list) and data[k])]
        if missing or bad_lists:
            r.fail(f"{name}: missing {sorted(missing)}, empty/non-list {bad_lists}")
        else:
            skills_dir = root / "skills"
            unknown = [s for s in data["skills"] if not (skills_dir / s).is_dir()]
            if unknown:
                r.fail(f"{name}: unknown skills {unknown}")
            else:
                r.ok(f"{name}: valid eval ({len(data['must'])} must, {len(data['must_not'])} must_not)")


# ---------------------------------------------------------------------- scripts
def check_shell(f: Path, root: Path, r: Report) -> None:
    name = rel(f, root)
    p = run(["bash", "-n", str(f)])
    if p.returncode:
        r.fail(f"{name}: bash -n: {p.stderr.strip()}")
        return
    if shutil.which("shellcheck"):
        p = run(["shellcheck", "-S", "warning", str(f)])
        if p.returncode:
            r.fail(f"{name}: shellcheck:\n{p.stdout}")
            return
        r.ok(f"{name}: bash -n + shellcheck")
    else:
        r.ok(f"{name}: bash -n (shellcheck not installed)")
    if not os.access(f, os.X_OK):
        r.fail(f"{name}: not executable")


# -------------------------------------------------------------------- templates
def check_c_template(f: Path, root: Path, r: Report, args) -> None:
    name = rel(f, root)
    text = f.read_text(encoding="utf-8")
    if len(text.splitlines()) < 5 or "Status: stub" in text:
        r.ok(f"{name}: stub")
        return
    if not args.kdir:
        r.skip(f"{name}: compile needs --kdir (prepared kernel tree)")
        return
    kdir = Path(args.kdir)
    if not (kdir / "include/generated/autoconf.h").is_file():
        r.skip(f"{name}: {kdir} not prepared (run make <defconfig> modules_prepare)")
        return
    if not shutil.which(f"{args.cross_compile}gcc"):
        r.skip(f"{name}: {args.cross_compile}gcc not installed")
        return
    with tempfile.TemporaryDirectory() as tmp:
        obj = f.stem.replace("v4l2_sensor_driver", "mysensor")
        shutil.copy(f, Path(tmp) / f"{obj}.c")
        (Path(tmp) / "Kbuild").write_text(f"obj-m += {obj}.o\n")
        p = run(["make", "-C", str(kdir), f"ARCH={args.arch}",
                 f"CROSS_COMPILE={args.cross_compile}", f"M={tmp}", "W=1", f"{obj}.o"])
        out = p.stdout + p.stderr
        if p.returncode or re.search(r"\b(warning|error):", out):
            r.fail(f"{name}: kernel compile failed or warned:\n{out[-2000:]}")
        else:
            ver = (kdir / "Makefile").read_text().split("\n", 5)[:4]
            r.ok(f"{name}: compiled W=1, no warnings ({' '.join(x.split('=')[1].strip() for x in ver[:3] if '=' in x)})")


def check_dts_template(f: Path, root: Path, r: Report, args) -> None:
    name = rel(f, root)
    lint = root / "skills/elinux-kernel/scripts/lint_dts.sh"
    if not shutil.which("dtc"):
        r.skip(f"{name}: dtc not installed")
        return
    cmd = [str(lint), str(f), "--strict"]
    if args.base_dtb:
        if not shutil.which("fdtoverlay"):
            r.skip(f"{name}: fdtoverlay not installed (compile-only below)")
        else:
            cmd += ["--base", args.base_dtb]
    p = run(cmd)
    if p.returncode:
        r.fail(f"{name}: {p.stdout}{p.stderr}")
    else:
        what = "compiled and applied to base DTB" if args.base_dtb else "dtc-clean (no --base-dtb given)"
        r.ok(f"{name}: {what}")


def check_yaml_template(f: Path, root: Path, r: Report) -> None:
    name = rel(f, root)
    try:
        import yaml  # type: ignore
    except ImportError:
        r.skip(f"{name}: PyYAML not installed")
        return
    try:
        yaml.safe_load(f.read_text(encoding="utf-8"))
        r.ok(f"{name}: valid YAML (schema not checked: needs dt-schema)")
    except yaml.YAMLError as e:
        r.fail(f"{name}: {e}")


def tiny_project(tmp: Path) -> None:
    (tmp / "src").mkdir()
    (tmp / "src/main.c").write_text("#include <stdio.h>\nint main(void){puts(\"ok\");return 0;}\n")
    (tmp / "CMakeLists.txt").write_text(
        "cmake_minimum_required(VERSION 3.16)\nproject(app C)\nadd_executable(app src/main.c)\n")


def check_cmake_template(f: Path, root: Path, r: Report) -> None:
    name = rel(f, root)
    if not shutil.which("cmake"):
        r.skip(f"{name}: cmake not installed")
        return
    triple = {"toolchain-aarch64.cmake": "aarch64-linux-gnu",
              "toolchain-armv6.cmake": "arm-linux-gnueabihf"}.get(f.name)
    if triple is None:
        r.ok(f"{name}: no check defined")
        return
    if not shutil.which(f"{triple}-gcc"):
        r.skip(f"{name}: {triple}-gcc not installed")
        return
    with tempfile.TemporaryDirectory() as t:
        tmp = Path(t)
        tiny_project(tmp)
        p = run(["cmake", "-S", str(tmp), "-B", str(tmp / "b"), f"-DCMAKE_TOOLCHAIN_FILE={f}"])
        if p.returncode:
            r.fail(f"{name}: configure failed:\n{p.stderr[-1500:]}")
            return
        p = run(["cmake", "--build", str(tmp / "b")])
        if p.returncode:
            r.fail(f"{name}: build failed:\n{(p.stdout + p.stderr)[-1500:]}")
            return
        out = run(["file", str(tmp / "b/app")]).stdout
        want = "aarch64" if "aarch64" in triple else "ARM"
        if want not in out:
            r.fail(f"{name}: unexpected output type: {out.strip()}")
        else:
            r.ok(f"{name}: configured, built, produced {want} executable")


def check_makefile_cross(f: Path, root: Path, r: Report) -> None:
    name = rel(f, root)
    if not shutil.which("make"):
        r.skip(f"{name}: make not installed")
        return
    for target, triple in (("aarch64", "aarch64-linux-gnu"), ("armv6", "arm-linux-gnueabihf")):
        if not shutil.which(f"{triple}-gcc"):
            r.skip(f"{name} TARGET={target}: {triple}-gcc not installed")
            continue
        with tempfile.TemporaryDirectory() as t:
            tmp = Path(t)
            (tmp / "src").mkdir()
            (tmp / "src/main.c").write_text("#include <stdio.h>\nint main(void){puts(\"ok\");return 0;}\n")
            shutil.copy(f, tmp / "Makefile")
            p = run(["make", "-C", str(tmp), f"TARGET={target}"])
            if p.returncode or "warning:" in p.stderr:
                r.fail(f"{name} TARGET={target}: {(p.stdout + p.stderr)[-1200:]}")
            else:
                r.ok(f"{name} TARGET={target}: built")


def check_templates(skill: Path, root: Path, r: Report, args) -> None:
    tdir = skill / "templates"
    if not tdir.is_dir():
        return
    for f in sorted(tdir.rglob("*")):
        if not f.is_file():
            continue
        if f.suffix == ".c":
            check_c_template(f, root, r, args)
        elif f.suffix == ".dts":
            if "Status: stub" in f.read_text(encoding="utf-8")[:200]:
                r.ok(f"{rel(f, root)}: stub")
            else:
                check_dts_template(f, root, r, args)
        elif f.suffix in (".yaml", ".yml"):
            check_yaml_template(f, root, r)
        elif f.suffix == ".cmake":
            check_cmake_template(f, root, r)
        elif f.name == "Makefile.cross":
            check_makefile_cross(f, root, r)
        elif f.suffix == ".sh":
            check_shell(f, root, r)


# ------------------------------------------------------------------------- main
def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", default=str(Path(__file__).resolve().parent.parent))
    ap.add_argument("--kdir", default=os.environ.get("ELINUX_KDIR"))
    ap.add_argument("--base-dtb", default=os.environ.get("ELINUX_BASE_DTB"))
    ap.add_argument("--arch", default="arm64")
    ap.add_argument("--cross-compile", default="aarch64-linux-gnu-")
    ap.add_argument("--require-toolchain", action="store_true",
                    help="treat SKIP as failure (CI with full toolchain)")
    args = ap.parse_args()

    root = Path(args.root).resolve()
    skills_dir = root / "skills"
    r = Report()
    if not skills_dir.is_dir():
        print(f"FAIL  no skills/ directory under {root}")
        return 1

    for skill in sorted(p for p in skills_dir.iterdir() if p.is_dir()):
        check_skill_md(skill, root, r)
        for md in sorted(skill.rglob("*.md")):
            check_links(md, root, r)
        for ref in sorted((skill / "references").rglob("*.md")) if (skill / "references").is_dir() else []:
            check_chapter(ref, root, r)
        for sh in sorted((skill / "scripts").glob("*.sh")) if (skill / "scripts").is_dir() else []:
            check_shell(sh, root, r)
        check_templates(skill, root, r, args)
    for md in sorted(root.glob("*.md")) + sorted((root / "docs").glob("*.md")):
        check_links(md, root, r)
    check_evals(root, r)

    print(f"\n{r.passes} passed, {r.fails} failed, {r.skips} skipped")
    if r.skips:
        print("Skipped checks were NOT verified; pass --kdir/--base-dtb or install the tools.")
    return 1 if r.fails or (args.require_toolchain and r.skips) else 0


if __name__ == "__main__":
    sys.exit(main())
