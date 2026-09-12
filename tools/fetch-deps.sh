#!/bin/sh
# 建/更新共享 Mathlib 依赖池。首次要下几个 G，慢。
set -eu
REPO=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$REPO/tools/lib/common.sh"
lean_path
git_no_proxy
cd "$REPO/tools/lean-deps"
echo "==> lake update"
lake update
echo "==> lake exe cache get"
lake exe cache get
echo "==> 完成: $(du -sh .lake 2>/dev/null | cut -f1)"
