#!/bin/sh
# 从模板生成一个新的提交目录。
#   tools/new-submission.sh <11位猜想编号> [slug]
set -eu

REPO=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$REPO/tools/lib/common.sh"

[ $# -ge 1 ] || die "用法: tools/new-submission.sh <11位猜想编号> [slug]"

ID=$1
SLUG=${2:-submission}

case $ID in
  [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]) ;;
  *) die "编号必须是 11 位数字，收到: $ID" ;;
esac

CONJ="$REPO/conjectures/$ID.md"
[ -f "$CONJ" ] || die "猜想文件不存在: conjectures/$ID.md"

DEST="$REPO/solutions/$ID/${SLUG}_$(date +%Y%m%d%H%M%S)"
[ -e "$DEST" ] && die "目标已存在: $DEST"

read_author

mkdir -p "$DEST"
cp -R "$REPO/tools/template/." "$DEST/"
python3 "$REPO/tools/lib/fill_template.py" \
  "$DEST" "$CONJ" "$ID" "$AUTHOR_NAME" "$AUTHOR_AFFILIATION"

# Mathlib 走共享池，每个提交不各存一份；.lake/ 本来就不进 git。
link_shared_mathlib "$DEST/lean"

printf '已生成 %s\n\n' "${DEST#"$REPO"/}"
printf '接下来:\n'
printf '  1. 写 %s/main.tex (把所有 TODO 换掉)\n' "${DEST#"$REPO"/}"
printf '  2. 写 %s/lean/Submission/Basic.lean\n' "${DEST#"$REPO"/}"
printf '  3. tools/build-submission.sh %s\n' "${DEST#"$REPO"/}"
printf '  4. tools/check-submission.sh %s\n' "${DEST#"$REPO"/}"
