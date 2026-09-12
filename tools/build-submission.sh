#!/bin/sh
# 编译一个提交：LaTeX -> PDF，然后 lake build。
#   tools/build-submission.sh solutions/<id>/<name>
set -eu
REPO=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$REPO/tools/lib/common.sh"

[ $# -ge 1 ] || die "用法: tools/build-submission.sh <提交目录>"
DIR=$(CDPATH= cd -- "$1" && pwd) || die "目录不存在: $1"
lean_path
git_no_proxy

echo "==> tectonic main.tex"
[ -f "$DIR/main.tex" ] || die "缺 main.tex"
( cd "$DIR" && tectonic -X compile main.tex )

echo "==> lake build"
[ -f "$DIR/lean/lakefile.toml" ] || die "缺 lean/lakefile.toml"
[ -e "$DIR/lean/.lake/packages" ] || link_shared_mathlib "$DIR/lean"
( cd "$DIR/lean" && lake build )

echo "==> 编译通过"
