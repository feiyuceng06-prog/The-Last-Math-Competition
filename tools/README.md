# tools

给这个仓库做提交用的脚手架。目标是让「提交一个猜想的证明」变成几条命令，
而不是每次重新拼 Lean 项目和 LaTeX 骨架。

## 一次性准备

```sh
# 1. 装 Lean（elan 装到 ~/.elan，不碰 pacman，不要 root）
curl -fsSL https://elan.lean-lang.org/elan-init.sh | sh -s -- -y

# 2. 建共享 Mathlib 依赖池（首次约 7.5G，慢）
tools/fetch-deps.sh

# 3. 填作者信息
cp tools/author.conf.example tools/author.conf && $EDITOR tools/author.conf
```

## 做一个提交

```sh
tools/new-submission.sh 00000000006 disproof
# -> solutions/00000000006/disproof_20260912064756/

# 写 main.tex 和 lean/Submission/Basic.lean，然后：
tools/build-submission.sh solutions/00000000006/disproof_20260912064756
tools/check-submission.sh solutions/00000000006/disproof_20260912064756
```

`check-submission.sh` 全过了才提 PR。它查的是 README 规则 3 的硬要求加几条
容易踩的坑：目录位置、LaTeX/PDF/Lean 三件套齐不齐、PDF 是不是比 tex 旧、
占位符有没有填完、Lean 里有没有 `sorry`/`admit`/`axiom`/`native_decide`、
**待证命题有没有被写成假设**、`lake build` 过不过（含「Nothing to build」）、
`.lake/` 有没有误入 git。

## 两个最容易漏掉的失败模式

这两种都能让一份实际上没验证任何东西的提交通过常规检查，所以脚本专门查：

**`lake build` 空转。** `lakefile.lean` 里写了 `lean_lib Foo` 但没加
`@[default_target]`，`lake build` 会输出「Nothing to build」并**返回 0**。
reviewer 看到绿色就过了，其实一行 Lean 都没编译。

**待证命题被写成假设。** 例如：

```lean
def VD3 : Prop := ...                        -- van der Waerden，没证
theorem main (hvd : VD3) : 猜想 := by ...    -- 证的是蕴涵式，不是猜想
```

全文没有 `sorry`，`#print axioms` 也干净，但真正的数学内容被假设掉了。
判据是**无参数**的 `Prop` 被当作 hypothesis——带参数的谓词（如
`def inA (n : ℕ) : Prop` 配 `(ha : inA a)`）是正常定义，不报。
遇到这种先查 Mathlib：van der Waerden 就可以由 `Combinatorics.exists_mono_homothetic_copy`
（Hales–Jewett 的推论）直接得到。

## 两个设计上的决定

**Mathlib 走共享池。** 每个提交一份 Mathlib 是 7.5G × N，不现实。所以
`tools/lean-deps/` 存唯一一份，各提交的 `lean/.lake/packages` 软链过去，
`lake-manifest.json` 从池子里拷，保证版本一致。`.lake/` 本来就不进 git，
PR 里只有 `lakefile.toml` + `lean-toolchain` + `lake-manifest.json` + 源码，
别人 clone 下来自己 `lake exe cache get` 就能复现。

**不要在 Lean 里重新定义标准概念。** 用 Mathlib 的 `Nat.Prime` 而不是自己写一个
`def Prime n := 1 < n ∧ ¬ Composite n`。后者就算证明全通过，证的也是「你自己
定义的素数」，review 时会被直接打回。`check-submission.sh` 会对这种情况报警告。

## 环境上的坑

这台机器的 git 全局配了 `socks5h://127.0.0.1:10808`，代理没起的时候 `lake`
拉依赖会失败（curl 直连 GitHub 反而是通的）。脚本里的 `git_no_proxy` 会探测
10808 端口，没在听就在**本进程内**屏蔽掉 http.proxy / https.proxy——不改动
全局 git 配置。代理起着的时候照常走代理。

## Lean toolchain

钉在 `leanprover/lean4:v4.33.1`，对应 Mathlib 的 `v4.33.1` tag。要升级的话
`tools/lean-deps/lean-toolchain`、`tools/template/lean/lean-toolchain` 和两处
`lakefile.toml` 里的 `rev` 要一起改，然后重跑 `tools/fetch-deps.sh`。
