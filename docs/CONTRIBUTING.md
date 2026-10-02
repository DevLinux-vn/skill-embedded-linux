# Contributing

## Chapter frame (references/*.md)

Every chapter that is not `Status: stub` has, in this order:

```
# Title

Status: complete            (or: stub)
Verified: kernel=<branch@version>; yocto=<release/rev or n/a>; buildroot=<release or n/a>

## 1. When to use / not to use
## 2. Conceptual model
## 3. API and kernel versions
## 4. Device Tree binding
## 5. Minimal example
## 6. Common pitfalls
## 7. How to test
## 8. References
```

- Sections that do not apply say "Not applicable" and why; they are not
  deleted (the validator checks for all eight).
- `Verified:` states what was *actually* checked and how (compiled, parsed,
  read from source). Use `[UNVERIFIED]` inline for claims you could not
  check. Never write "verified" for something that was not run.
- Stubs contain `Status: stub` and a TODO; the validator reports them.

## SKILL.md rules

- Frontmatter: `name` (= directory), `description` (<= 1024 chars) with
  **"Use when ..."** and **"Do NOT use ..."** naming the other skill.
- Under 500 lines. Details go to `references/`, loaded on demand.
- Include an applicability check where a wrong assumption is costly.

## Content rules

- **No copyrighted text.** Write concise original explanations; point to
  `Documentation/` paths (with version) and book chapters. Do not paste
  mainline or vendor source; templates are original work.
- **No hardware facts from memory** (GPIO, I2C bus/address, CSI lanes,
  clock rates, supplies). Use `TODO(board)` / `TODO(datasheet)` and the
  command that obtains the value. Facts read from a named source file may be
  cited with the file and version.
- **One source, three adapters:** CMake core; Yocto/Buildroot only call it.
- Commands in docs must be ones you ran or clearly marked as untested.

## Templates

Templates must pass `tools/validate_skills.py`: kernel C compiles with
`W=1` and no warnings against the target branch, overlays compile with `dtc`
and apply to the real base DTB, shell scripts pass `shellcheck`, CMake
toolchain files configure and build.

## Commits

[Conventional Commits](https://www.conventionalcommits.org/): `type(scope):
summary` in the imperative, <= 72 chars, body explaining *why* and what was
verified.

Types: `feat`, `fix`, `docs`, `test`, `build`, `chore`, `refactor`.
Scopes: skill names without the `elinux-` prefix (`core`, `kernel`,
`buildsys`, `testing`, `yocto`, `userspace`, `buildroot`), plus `tools`,
`evals`, `repo`.
