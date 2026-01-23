$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ErrorActionPreference = "Stop"

# 颜色定义
$ESC = [char]27
$RED = "$ESC[31m"
$GREEN = "$ESC[32m"
$YELLOW = "$ESC[33m"
$BLUE = "$ESC[34m"
$NC = "$ESC[0m"

if (-not $IsMacOS) {
    Write-Host "$RED❌ 当前脚本仅支持 macOS（需要 PowerShell Core: pwsh）$NC"
    exit 1
}

function Write-Banner {
    Write-Host ""
    Write-Host "$GREEN================ Cursor 清理工具（macOS） ================$NC"
    Write-Host "$BLUE仓库：$NC https://gitee.com/loong5201314/cursor-cleaning-tool"
    Write-Host "$GREEN========================================================$NC"
    Write-Host ""
}

function Stop-CursorProcesses {
    Write-Host "$BLUE🔒 [进程]$NC 正在检查并关闭 Cursor 相关进程..."
    $processes = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match "^Cursor$|^Cursor Helper|^cursor$" }
    if (-not $processes) {
        Write-Host "$GREEN✅ [进程]$NC 未发现运行中的 Cursor 进程"
        return
    }
    try {
        $processes | Stop-Process -Force -ErrorAction Stop
        Write-Host "$GREEN✅ [进程]$NC 已关闭 Cursor 相关进程"
    } catch {
        Write-Host "$YELLOW⚠️  [进程]$NC 关闭进程失败：$($_.Exception.Message)"
    }
}

function Get-AppSupportFromStorageFile {
    param([Parameter(Mandatory = $true)][string]$StorageFile)
    $globalStorageDir = Split-Path -Parent $StorageFile
    $userDir = Split-Path -Parent $globalStorageDir
    return (Split-Path -Parent $userDir)
}

function Resolve-CursorStorageFile {
    $home = [Environment]::GetFolderPath([System.Environment+SpecialFolder]::UserProfile)
    $default = Join-Path $home "Library/Application Support/Cursor/User/globalStorage/storage.json"
    if (Test-Path $default) {
        return $default
    }

    $alt = Join-Path $home "Library/Application Support/cursor/User/globalStorage/storage.json"
    if (Test-Path $alt) {
        return $alt
    }

    $appSupportRoot = Join-Path $home "Library/Application Support"
    if (-not (Test-Path $appSupportRoot)) {
        return $null
    }

    $candidates = Get-ChildItem -Path $appSupportRoot -Recurse -Filter "storage.json" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match "globalStorage" -and ($_.FullName -match "Cursor" -or $_.FullName -match "cursor" -or $_.FullName -match "todesktop") } |
        Select-Object -First 1

    if ($candidates) {
        return $candidates.FullName
    }

    return $null
}

function Get-CursorPaths {
    $home = [Environment]::GetFolderPath([System.Environment+SpecialFolder]::UserProfile)
    $storageFile = Resolve-CursorStorageFile
    $appSupport = $null
    if ($storageFile) {
        $appSupport = Get-AppSupportFromStorageFile -StorageFile $storageFile
    }
    $storageDir = if ($storageFile) { Split-Path -Parent $storageFile } else { $null }
    $machineIdFile = if ($appSupport) { Join-Path $appSupport "machineid" } else { $null }
    $cacheDir = Join-Path $home "Library/Caches/Cursor"
    $cursorDotDir = Join-Path $home ".cursor"

    return @{
        Home = $home
        AppSupport = $appSupport
        StorageDir = $storageDir
        StorageFile = $storageFile
        MachineIdFile = $machineIdFile
        CacheDir = $cacheDir
        CursorDotDir = $cursorDotDir
    }
}

function New-RandomHex {
    param([int]$ByteLength = 32)
    $bytes = New-Object byte[] $ByteLength
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $rng.GetBytes($bytes)
    } finally {
        $rng.Dispose()
    }
    return ([System.BitConverter]::ToString($bytes) -replace "-", "").ToLower()
}

function Update-StorageJson {
    param(
        [Parameter(Mandatory = $true)][string]$StorageFile
    )

    if (-not $StorageFile -or -not (Test-Path $StorageFile)) {
        Write-Host "$RED❌ [配置]$NC 未找到 storage.json: $StorageFile"
        Write-Host "$YELLOW💡 [提示]$NC 请先启动一次 Cursor 生成配置文件"
        return $false
    }

    $backupPath = "$StorageFile.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Copy-Item -Path $StorageFile -Destination $backupPath -Force
    Write-Host "$GREEN💾 [备份]$NC 已备份: $backupPath"

    $json = Get-Content -Path $StorageFile -Raw | ConvertFrom-Json

    $machineId = New-RandomHex 32
    $macMachineId = [System.Guid]::NewGuid().ToString()
    $devDeviceId = [System.Guid]::NewGuid().ToString()
    $sqmId = "{$([System.Guid]::NewGuid().ToString().ToUpper())}"
    $serviceMachineId = [System.Guid]::NewGuid().ToString()
    $sessionId = [System.Guid]::NewGuid().ToString()
    $firstSessionDate = (Get-Date).ToString("o")

    $json.'telemetry.machineId' = $machineId
    $json.'telemetry.macMachineId' = $macMachineId
    $json.'telemetry.devDeviceId' = $devDeviceId
    $json.'telemetry.sqmId' = $sqmId
    $json.'storage.serviceMachineId' = $serviceMachineId
    $json.'telemetry.firstSessionDate' = $firstSessionDate
    $json.'telemetry.sessionId' = $sessionId

    $json | ConvertTo-Json -Depth 64 | Set-Content -Path $StorageFile -Encoding UTF8
    Write-Host "$GREEN✅ [配置]$NC storage.json 已更新"

    return @{
        machineId = $machineId
        macMachineId = $macMachineId
        devDeviceId = $devDeviceId
        sqmId = $sqmId
        serviceMachineId = $serviceMachineId
        sessionId = $sessionId
        firstSessionDate = $firstSessionDate
    }
}

function Update-MachineIdFile {
    param(
        [Parameter(Mandatory = $true)][string]$MachineIdFile,
        [Parameter(Mandatory = $true)][string]$ServiceMachineId
    )

    try {
        $dir = Split-Path -Parent $MachineIdFile
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        if (Test-Path $MachineIdFile) {
            $backup = "$MachineIdFile.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            Copy-Item -Path $MachineIdFile -Destination $backup -Force
            Write-Host "$GREEN💾 [备份]$NC machineid 已备份: $backup"
        }
        [System.IO.File]::WriteAllText($MachineIdFile, $ServiceMachineId, [System.Text.Encoding]::UTF8)
        Write-Host "$GREEN✅ [machineid]$NC 已写入: $ServiceMachineId"
    } catch {
        Write-Host "$YELLOW⚠️  [machineid]$NC 写入失败: $($_.Exception.Message)"
    }
}

function Confirm-DeepClean {
    Write-Host ""
    Write-Host "$YELLOW⚠️  [可选]$NC 是否执行“彻底清理”（删除 Cursor 本地数据）？"
    Write-Host "$YELLOW⚠️  [警告]$NC 该操作会删除 Cursor 配置与缓存，需重新登录/配置"
    $inputText = Read-Host "请输入 YES 继续（其他任意输入将跳过）"
    return ($inputText -eq "YES")
}

function Invoke-DeepClean {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Paths
    )

    $targets = @(
        $Paths.CursorDotDir,
        $Paths.AppSupport,
        $Paths.CacheDir
    ) | Where-Object { $_ }

    foreach ($path in $targets) {
        if (Test-Path $path) {
            try {
                Remove-Item -Path $path -Recurse -Force
                Write-Host "$GREEN✅ [删除]$NC 已删除: $path"
            } catch {
                Write-Host "$YELLOW⚠️  [删除]$NC 删除失败: $path | $($_.Exception.Message)"
            }
        } else {
            Write-Host "$BLUEℹ️  [删除]$NC 不存在: $path"
        }
    }
}

Write-Banner
Stop-CursorProcesses

$paths = Get-CursorPaths
if ($paths.AppSupport) {
    Write-Host "$BLUEℹ️  [路径]$NC Cursor 数据目录: $($paths.AppSupport)"
}
if ($paths.StorageFile) {
    Write-Host "$BLUEℹ️  [路径]$NC storage.json: $($paths.StorageFile)"
}

if (Confirm-DeepClean) {
    Invoke-DeepClean -Paths $paths
    Write-Host "$GREEN✅ [完成]$NC 深度清理完成，请重新启动 Cursor 生成配置文件"
    exit 0
}

$result = Update-StorageJson -StorageFile $paths.StorageFile
if (-not $result) {
    exit 1
}

Update-MachineIdFile -MachineIdFile $paths.MachineIdFile -ServiceMachineId $result.serviceMachineId

Write-Host ""
Write-Host "$GREEN🎉 [完成]$NC macOS 清理完成，可重新启动 Cursor"
