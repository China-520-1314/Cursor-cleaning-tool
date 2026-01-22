# cursor-cleaning-tool

用于分发 Cursor 清理脚本的仓库（PowerShell）。

## 一句话结论

- 想让“别人不登录也能用”，仓库必须 **公开**（私有仓库的 raw 地址通常需要鉴权，`irm` 会直接 403/跳转登录）。

## 使用方式（推荐：先下载再执行）

1) 下载脚本到本地（把 `<RAW_URL>` 换成下面的 raw 链接，例如指向 `scripts/run/cursor_win_id_modifier.ps1`）：

```powershell
irm "<RAW_URL>" -OutFile "./cursor_clean.ps1"
```

2) 执行：

```powershell
powershell -ExecutionPolicy Bypass -File "./cursor_clean.ps1"
```

## Gitee raw 链接模板

分支 raw（不建议用于分发“清理/修改”类脚本，容易被你后续更新影响）：

```text
https://gitee.com/<owner>/<repo>/raw/<branch>/scripts/run/cursor_win_id_modifier.ps1
```

建议做法：打 tag（例如 `v1.0.0`），然后用 tag raw：

```text
https://gitee.com/<owner>/<repo>/raw/v1.0.0/scripts/run/cursor_win_id_modifier.ps1
```

> 不建议直接 `irm ... | iex`，因为它等同于“远程代码直接执行”。如果你坚持提供，也建议至少固定到 tag/commit。
