#!/bin/sh
# 提交前自检。对照 README 规则 3 的要求逐条查。
#   tools/check-submission.sh solutions/<id>/<name>
set -eu
REPO=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$REPO/tools/lib/common.sh"

[ $# -ge 1 ] || die "用法: tools/check-submission.sh <提交目录>"
DIR=$(CDPATH= cd -- "$1" && pwd) || die "目录不存在: $1"
REL=${DIR#"$REPO"/}
FAILED=0
lean_path
git_no_proxy

echo "检查 $REL"

echo "[1/7] 目录位置"
case $REL in
  solutions/[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]/?*)
    ID=$(printf '%s\n' "$REL" | cut -d/ -f2)
    if [ -f "$REPO/conjectures/$ID.md" ]; then
      pass "solutions/$ID/... ，对应猜想存在"
    else
      fail "conjectures/$ID.md 不存在"
    fi ;;
  *) fail "必须放在 solutions/<11位编号>/<提交名>/ 下，当前是 $REL" ;;
esac

echo "[2/7] 规则 3 要求的三件套"
# 文件名和布局都不由规则规定：找任意 .tex 及同名 .pdf，Lean 项目可在根或 lean/ 下
TEX=$(find "$DIR" -maxdepth 1 -name '*.tex' | head -1)
if [ -n "$TEX" ]; then
  pass "LaTeX 源码 ${TEX##*/}"
  PDF="${TEX%.tex}.pdf"
  if [ -f "$PDF" ]; then
    pass "PDF ${PDF##*/}"
    [ "$TEX" -nt "$PDF" ] && warn "${TEX##*/} 比 PDF 新，PDF 是旧的，重新 build"
  else
    fail "缺与 ${TEX##*/} 对应的 PDF"
  fi
else
  fail "缺 LaTeX 源码"
fi
if [ -f "$DIR/lakefile.toml" ] || [ -f "$DIR/lakefile.lean" ]; then
  LEANDIR="$DIR"
elif [ -f "$DIR/lean/lakefile.toml" ] || [ -f "$DIR/lean/lakefile.lean" ]; then
  LEANDIR="$DIR/lean"
else
  LEANDIR=""
fi
if [ -n "$LEANDIR" ]; then
  if [ "$LEANDIR" = "$DIR" ]; then
    pass "Lean 项目在提交根目录"
  else
    pass "Lean 项目在 ${LEANDIR#"$DIR"/}/"
  fi
  for f in lean-toolchain lake-manifest.json; do
    [ -f "$LEANDIR/$f" ] && pass "Lean 项目 $f" || fail "Lean 项目缺 $f"
  done
else
  fail "找不到 lakefile"
fi

echo "[3/7] 占位符残留"
if grep -rIlq -e '@@' -e 'TODO' "$DIR" --include='*.tex' --include='*.lean' --include='*.md' 2>/dev/null; then
  grep -rIn -e '@@' -e 'TODO' "$DIR" --include='*.tex' --include='*.lean' --include='*.md' 2>/dev/null |
    sed 's|^'"$DIR"'/|    |' | head -20
  fail "还有没填的占位符 / TODO"
else
  pass "没有占位符残留"
fi

echo "[4/7] Lean 证明完整性"
LEAN_SRC=$(find "$DIR" -name '*.lean' -not -path '*/.lake/*' -not -name 'lakefile.lean' 2>/dev/null)
if [ -z "$LEAN_SRC" ]; then
  fail "没有 Lean 源文件"
else
  HOLE=0
  for pat in '\bsorry\b' '\badmit\b' '^\s*axiom\b' '\bnative_decide\b'; do
    if printf '%s\n' "$LEAN_SRC" | xargs grep -nE "$pat" 2>/dev/null | grep -q .; then
      printf '%s\n' "$LEAN_SRC" | xargs grep -nE "$pat" 2>/dev/null |
        sed 's|^'"$DIR"'/|    |' | head -10
      HOLE=1
    fi
  done
  [ "$HOLE" -eq 0 ] && pass "无 sorry / admit / axiom / native_decide" \
                    || fail "证明里有洞（见上）"
  if printf '%s\n' "$LEAN_SRC" | xargs grep -nE '^\s*(def|abbrev)\s+(Prime|Composite|Irrational)\b' 2>/dev/null | grep -q .; then
    warn "自己重定义了标准概念（Prime/Composite/...）；review 会质疑你证的不是原命题，改用 Mathlib 的定义"
  fi
fi

echo "[5/7] 待证命题是否被写成了假设"
if [ -n "$LEAN_SRC" ]; then
  if printf '%s\n' "$LEAN_SRC" | xargs python3 "$REPO/tools/lib/check_assumed_props.py"; then
    pass "没有把待证命题当作 hypothesis"
  else
    fail "有待证命题被写成了 hypothesis（见上）"
  fi
else
  pass "没有 Lean 源文件，跳过"
fi

echo "[6/7] lake build"
if [ -n "$LEANDIR" ]; then
  [ -e "$LEANDIR/.lake/packages" ] || link_shared_mathlib "$LEANDIR"
  if ( cd "$LEANDIR" && lake build >/tmp/lakebuild.$$ 2>&1 ); then
    # 「Nothing to build」意味着没有 default target：reviewer 会得到假绿
    if grep -q 'Nothing to build' /tmp/lakebuild.$$; then
      fail "lake build 说「Nothing to build」——没配 default target，等于什么都没验证"
    else
      pass "lake build 通过"
    fi
  else
    tail -25 /tmp/lakebuild.$$ | sed 's/^/    /'
    fail "lake build 失败"
  fi
  rm -f /tmp/lakebuild.$$
else
  fail "没有 Lean 项目，跳过"
fi

echo "[7/7] 不该进 git 的东西"
if git -C "$REPO" ls-files --error-unmatch "$DIR/.lake" "$DIR/lean/.lake" >/dev/null 2>&1; then
  fail ".lake/ 被 git 跟踪了"
else
  pass ".lake/ 没进 git"
fi

echo
if [ "$FAILED" -eq 0 ]; then
  echo "全部通过，可以提 PR。"
else
  echo "$FAILED 项没过。"
  exit 1
fi
