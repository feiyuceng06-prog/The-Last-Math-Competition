"""Fill the submission templates for one conjecture.

Reads conjectures/<id>.md, writes the placeholder values into the copied
template tree. Unicode mathematics in the source statement is rewritten into
LaTeX macros on a best-effort basis; anything left over is reported so it can
be typeset by hand rather than silently breaking the build.
"""

import datetime
import pathlib
import re
import sys

# Unicode that shows up in the generated conjecture statements, mapped to the
# LaTeX that tectonic can typeset without a unicode-aware font.
MATH = {
    "≤": r"\le", "≥": r"\ge", "≠": r"\ne", "≈": r"\approx", "≡": r"\equiv",
    "⊂": r"\subset", "⊆": r"\subseteq", "⊃": r"\supset", "⊇": r"\supseteq",
    "∈": r"\in", "∉": r"\notin", "∪": r"\cup", "∩": r"\cap", "∅": r"\emptyset",
    "∀": r"\forall", "∃": r"\exists", "¬": r"\neg", "∧": r"\wedge", "∨": r"\vee",
    "→": r"\to", "←": r"\leftarrow", "↦": r"\mapsto", "⇒": r"\Rightarrow",
    "∞": r"\infty", "∑": r"\sum", "∏": r"\prod", "∫": r"\int", "√": r"\sqrt",
    "∣": r"\mid", "∤": r"\nmid", "·": r"\cdot", "×": r"\times", "÷": r"\div",
    "±": r"\pm", "∘": r"\circ", "⌊": r"\lfloor", "⌋": r"\rfloor",
    "⌈": r"\lceil", "⌉": r"\rceil", "ℕ": r"\mathbb{N}", "ℤ": r"\mathbb{Z}",
    "ℚ": r"\mathbb{Q}", "ℝ": r"\mathbb{R}", "ℂ": r"\mathbb{C}", "ℙ": r"\mathbb{P}",
    "α": r"\alpha", "β": r"\beta", "γ": r"\gamma", "δ": r"\delta",
    "ε": r"\varepsilon", "ζ": r"\zeta", "η": r"\eta", "θ": r"\theta",
    "ι": r"\iota", "κ": r"\kappa", "λ": r"\lambda", "μ": r"\mu", "ν": r"\nu",
    "ξ": r"\xi", "π": r"\pi", "ρ": r"\rho", "σ": r"\sigma", "τ": r"\tau",
    "φ": r"\varphi", "χ": r"\chi", "ψ": r"\psi", "ω": r"\omega",
    "Γ": r"\Gamma", "Δ": r"\Delta", "Θ": r"\Theta", "Λ": r"\Lambda",
    "Ξ": r"\Xi", "Π": r"\Pi", "Σ": r"\Sigma", "Φ": r"\Phi", "Ψ": r"\Psi",
    "Ω": r"\Omega",
}

LATEX_ESCAPE = {"&": r"\&", "%": r"\%", "#": r"\#", "_": r"\_"}


def to_latex(text):
    out = []
    for ch in text:
        if ch in LATEX_ESCAPE:
            out.append(LATEX_ESCAPE[ch])
        elif ch in MATH:
            out.append("$" + MATH[ch] + "$")
        else:
            out.append(ch)
    joined = "".join(out)
    # Collapse the runs of adjacent single-symbol math this produces.
    joined = re.sub(r"\$ ?\$", " ", joined)
    leftover = sorted({c for c in joined if ord(c) > 127})
    return joined, leftover


def statements(path):
    text = path.read_text(encoding="utf-8")
    en = re.search(r"\*\*English\.\*\*\s*(.+?)(?:\n\n|\Z)", text, re.S)
    zh = re.search(r"\*\*中文。\*\*\s*(.+?)(?:\n\n|\Z)", text, re.S)
    return (
        " ".join(en.group(1).split()) if en else "",
        " ".join(zh.group(1).split()) if zh else "",
    )


def main():
    dest, conj_md, cid, author, affiliation = sys.argv[1:6]
    dest = pathlib.Path(dest)
    en, zh = statements(pathlib.Path(conj_md))
    if not en:
        sys.exit(f"找不到英文陈述: {conj_md}")

    en_tex, leftover = to_latex(en)
    today = datetime.date.today().isoformat()

    values = {
        "@@ID@@": cid,
        "@@TITLE@@": "TODO: title",
        "@@AUTHOR@@": author,
        "@@AFFILIATION@@": affiliation,
        "@@DATE@@": today,
        "@@ABSTRACT@@": "TODO: abstract",
        "@@STATEMENT@@": en_tex,
        "@@READING@@": "TODO: reading",
        "@@RESULT@@": "TODO: result",
        "@@PROOF@@": "TODO: proof",
        "@@REMARKS@@": "TODO: remarks",
    }
    lean_values = dict(values, **{"@@STATEMENT@@": en})

    for path in sorted(dest.rglob("*")):
        if not path.is_file() or path.suffix not in {".tex", ".lean", ".md"}:
            continue
        src = path.read_text(encoding="utf-8")
        table = lean_values if path.suffix == ".lean" else values
        for key, val in table.items():
            src = src.replace(key, val)
        path.write_text(src, encoding="utf-8")

    (dest / "STATEMENT.md").write_text(
        f"# {cid}\n\n**English.** {en}\n\n**中文。** {zh}\n", encoding="utf-8"
    )

    if leftover:
        print("警告: 陈述里这些字符没有映射，需手工排版: " + " ".join(leftover))


main()
