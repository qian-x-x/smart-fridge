#Requires -Version 7.0
<#
.SYNOPSIS
    让局域网内的手机/其它电脑访问本机运行的冰箱应用。

.DESCRIPTION
    Docker Desktop 在 Windows 上只把容器端口发布到 127.0.0.1，
    因此同一 Wi-Fi 下的设备无法直接访问。这个脚本用系统端口代理
    （netsh interface portproxy）把 0.0.0.0 上的端口转发到回环地址，
    重启后依然有效。

    需要以管理员身份运行。若不想提权，改用 scripts/lan-bridge.py。

.PARAMETER PublicPort
    对外暴露的端口，默认 3000。

.PARAMETER TargetPort
    容器实际发布在 127.0.0.1 上的端口，默认 3030。

.PARAMETER Remove
    删除已添加的转发规则。
#>
[CmdletBinding()]
param(
    [int]$PublicPort = 3000,
    [int]$TargetPort = 3030,
    [switch]$Remove
)

$ErrorActionPreference = 'Stop'

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw '需要管理员权限：请以管理员身份打开 PowerShell 后重新运行，或改用 python scripts/lan-bridge.py 3000=3030'
}

if ($Remove) {
    netsh interface portproxy delete v4tov4 listenaddress=0.0.0.0 listenport=$PublicPort | Out-Null
    Write-Output "已删除 0.0.0.0:$PublicPort 的转发规则"
    exit 0
}

# iphlpsvc 负责 portproxy，未启动时规则不生效。
$service = Get-Service -Name iphlpsvc
if ($service.Status -ne 'Running') {
    Start-Service -Name iphlpsvc
}

netsh interface portproxy delete v4tov4 listenaddress=0.0.0.0 listenport=$PublicPort 2>$null | Out-Null
netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=$PublicPort connectaddress=127.0.0.1 connectport=$TargetPort | Out-Null

# 局域网来源在防火墙里放行一次，避免手机连不上。
$ruleName = "小易冰箱 LAN $PublicPort"
if (-not (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Action Allow `
        -Protocol TCP -LocalPort $PublicPort -Profile Private, Public | Out-Null
}

$addresses = Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
    Select-Object -ExpandProperty IPAddress

Write-Output "已转发 0.0.0.0:$PublicPort -> 127.0.0.1:$TargetPort"
foreach ($address in $addresses) {
    Write-Output "  局域网访问：http://${address}:$PublicPort"
}
Write-Output '提示：手机与电脑需在同一 Wi-Fi；改端口后重新运行本脚本。'
