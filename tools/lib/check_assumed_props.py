"""Detect propositions that are assumed rather than proved.

The pattern this catches is a nullary `def NAME : Prop := ...` that is then
taken as a hypothesis of a theorem:

    def VD3 : Prop := ∀ q, ...          -- van der Waerden, not proved
    theorem main (hvd : VD3) ... : ...  -- the real content is assumed

Such a submission proves an implication, not the conjecture, and no `sorry`
appears anywhere — so the usual checks pass. A *parametrized* predicate used as
a hypothesis is ordinary and is not reported: `def inA (n : ℕ) : Prop` with
`(ha : inA a)` is just a definition, not an assumed theorem.
"""

import pathlib
import re
import sys

NULLARY_PROP = re.compile(
    r"^[ \t]*(?:private[ \t]+|protected[ \t]+)?(?:def|abbrev)[ \t]+"
    r"([A-Za-z_][A-Za-z0-9_'!?]*)[ \t]*:[ \t]*Prop\b",
    re.M,
)


def binder_use(name):
    # (h : NAME)  [h : NAME]  {h : NAME}  ⦃h : NAME⦄ — and the anonymous `(_ : NAME)`
    return re.compile(r"[(\[{⦃][^()\[\]{}⦃⦄:]*:[ \t]*" + re.escape(name) + r"[ \t]*[)\]}⦄]")


def proved(name):
    # a declaration whose conclusion is NAME, e.g. `theorem vd3 : VD3 := ...`
    return re.compile(
        r"^[ \t]*(?:theorem|lemma|instance|example)\b[^:\n]*:[ \t]*"
        + re.escape(name)
        + r"[ \t]*(?::=|$)",
        re.M,
    )


def main():
    files = [q for q in (pathlib.Path(p) for p in sys.argv[1:]) if q.is_file()]
    if not files:
        return 0
    blob = "\n".join(f.read_text(encoding="utf-8", errors="replace") for f in files)

    findings = []
    for f in files:
        text = f.read_text(encoding="utf-8", errors="replace")
        for m in NULLARY_PROP.finditer(text):
            name = m.group(1)
            if not binder_use(name).search(blob):
                continue
            line = text[: m.start()].count("\n") + 1
            findings.append((f, line, name, bool(proved(name).search(blob))))

    if not findings:
        return 0

    unproved = [x for x in findings if not x[3]]
    for f, line, name, is_proved in findings:
        tag = "本项目内有证明" if is_proved else "本项目内没有证明"
        print(f"    {f.name}:{line}: `{name}` 是无参数 Prop，且被当作假设使用（{tag}）")
    if unproved:
        print("    -> 待证命题被写成了 hypothesis：定理证的是蕴涵式，不是命题本身。")
        print("       先查 Mathlib 有没有现成的（如 van der Waerden 可由 Hales-Jewett 得到）。")
        return 1
    print("    -> 这些在本项目内有证明，大概率没问题，但请确认定理用的是证明而非假设。")
    return 0


sys.exit(main())
