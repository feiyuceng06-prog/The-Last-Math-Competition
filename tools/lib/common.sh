# 三个脚本共用的东西。用 . 引入，不单独执行。

die() { printf '错误: %s\n' "$*" >&2; exit 1; }
warn() { printf '  [警告] %s\n' "$*"; }
fail() { printf '  [失败] %s\n' "$*"; FAILED=$((FAILED + 1)); }
pass() { printf '  [通过] %s\n' "$*"; }

# elan 装在 ~/.elan，非登录 shell 不一定有。
lean_path() { PATH="$HOME/.elan/bin:$PATH"; export PATH; }

# git 全局配了 socks5h://127.0.0.1:10808；代理没起时 lake 拉依赖会直接失败。
# 这里只在本进程内屏蔽，不动用户的 global config。
git_no_proxy() {
  if ! ss -ltn 2>/dev/null | grep -q '127\.0\.0\.1:10808'; then
    GIT_CONFIG_COUNT=2
    GIT_CONFIG_KEY_0=http.proxy;  GIT_CONFIG_VALUE_0=
    GIT_CONFIG_KEY_1=https.proxy; GIT_CONFIG_VALUE_1=
    export GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0 \
           GIT_CONFIG_KEY_1 GIT_CONFIG_VALUE_1
  fi
}

read_author() {
  AUTHOR_NAME=$(git -C "$REPO" config user.name 2>/dev/null || echo "TODO: name")
  AUTHOR_AFFILIATION="TODO: affiliation"
  # shellcheck disable=SC1091
  [ -f "$REPO/tools/author.conf" ] && . "$REPO/tools/author.conf"
  export AUTHOR_NAME AUTHOR_AFFILIATION
}

link_shared_mathlib() {
  _proj=$1
  _pool="$REPO/tools/lean-deps"
  [ -d "$_pool/.lake/packages" ] || die "共享依赖池还没建好，先跑 tools/fetch-deps.sh"
  mkdir -p "$_proj/.lake"
  rm -rf "$_proj/.lake/packages"
  ln -s "$_pool/.lake/packages" "$_proj/.lake/packages"
  cp "$_pool/lake-manifest.json" "$_proj/lake-manifest.json"
}
