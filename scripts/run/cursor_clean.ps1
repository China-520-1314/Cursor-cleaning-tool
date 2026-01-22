$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ErrorActionPreference = "Stop"

param(
    [string]$UpstreamScriptUrl = "https://wget.la/https://raw.githubusercontent.com/yuaotian/go-cursor-help/refs/heads/master/scripts/run/cursor_win_id_modifier.ps1",
    [switch]$SkipConfirm
)

function Write-Banner {
    $esc = [char]27
    $green = "$esc[32m"
    $yellow = "$esc[33m"
    $blue = "$esc[34m"
    $nc = "$esc[0m"

    Write-Host ""
    Write-Host "${green}Cursor 清理工具（自定义分发）${nc}"
    Write-Host "${blue}仓库：${nc}https://gitee.com/loong5201314/cursor-cleaning-tool"
    Write-Host ""
}

function Confirm-Run {
    if ($SkipConfirm) {
        return
    }

    Write-Host "即将从远程下载并执行脚本："
    Write-Host "  $UpstreamScriptUrl"
    Write-Host ""
    $inputText = Read-Host "请输入 YES 继续（其他任意输入将退出）"
    if ($inputText -ne "YES") {
        throw "用户取消执行"
    }
}

function Invoke-UpstreamScript {
    $tempDir = [System.IO.Path]::GetTempPath()
    $tempScriptPath = Join-Path $tempDir "cursor_win_id_modifier.ps1"

    Write-Host "下载脚本到临时文件：$tempScriptPath"
    irm "$UpstreamScriptUrl" -OutFile "$tempScriptPath"

    try {
        & "$tempScriptPath"
    } catch {
        $psExe = (Get-Command "powershell" -ErrorAction SilentlyContinue)?.Source
        if (-not $psExe) {
            throw
        }
        & "$psExe" -ExecutionPolicy Bypass -File "$tempScriptPath"
    }
}

Write-Banner
Confirm-Run
Invoke-UpstreamScript

