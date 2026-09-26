# Windows (PowerShell) 用: VPS 上の Claude Code スキル / エージェント / コマンドを同期する。
# Windows 10 以降に標準搭載の OpenSSH (ssh / scp) を使用します。
#
# 使い方:
#   .\scripts\claude-sync.ps1 pull    -VpsHost user@example.com   # VPS -> リポジトリの .claude\
#   .\scripts\claude-sync.ps1 install                             # リポジトリの .claude\ -> %USERPROFILE%\.claude\
#   .\scripts\claude-sync.ps1 direct  -VpsHost user@example.com   # VPS -> %USERPROFILE%\.claude\ に直接コピー
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('pull', 'install', 'direct')]
    [string]$Command,
    [string]$VpsHost = $env:VPS_HOST,
    [string]$VpsClaudeDir = $(if ($env:VPS_CLAUDE_DIR) { $env:VPS_CLAUDE_DIR } else { '~/.claude' }),
    [int]$Port = $(if ($env:VPS_SSH_PORT) { [int]$env:VPS_SSH_PORT } else { 22 }),
    [string]$LocalClaudeDir = (Join-Path $HOME '.claude')
)
$ErrorActionPreference = 'Stop'

$Kinds = @('skills', 'agents', 'commands')
$RepoClaudeDir = Join-Path (Split-Path $PSScriptRoot -Parent) '.claude'

function Pull-To([string]$DestRoot) {
    if (-not $VpsHost) { throw 'VpsHost を指定してください (例: -VpsHost user@example.com)' }
    foreach ($kind in $Kinds) {
        ssh -p $Port $VpsHost "test -d $VpsClaudeDir/$kind"
        if ($LASTEXITCODE -ne 0) { Write-Host "スキップ: VPS に $VpsClaudeDir/$kind がありません"; continue }
        $dest = Join-Path $DestRoot $kind
        New-Item -ItemType Directory -Force -Path $dest | Out-Null
        Write-Host "取得: ${VpsHost}:$VpsClaudeDir/$kind -> $dest"
        scp -r -P $Port "${VpsHost}:$VpsClaudeDir/$kind/*" "$dest\"
        if ($LASTEXITCODE -ne 0) { throw "scp に失敗しました ($kind)" }
    }
}

switch ($Command) {
    'pull'    { Pull-To $RepoClaudeDir; Write-Host '完了。git add .claude; git commit で共有できます' }
    'direct'  { Pull-To $LocalClaudeDir; Write-Host '完了。Claude Code を再起動すると反映されます' }
    'install' {
        foreach ($kind in $Kinds) {
            $src = Join-Path $RepoClaudeDir $kind
            if (-not (Test-Path $src)) { continue }
            $dest = Join-Path $LocalClaudeDir $kind
            New-Item -ItemType Directory -Force -Path $dest | Out-Null
            Get-ChildItem $src -Exclude '.gitkeep' | ForEach-Object {
                Write-Host "インストール: $($_.FullName) -> $dest"
                Copy-Item $_.FullName $dest -Recurse -Force
            }
        }
        Write-Host '完了。Claude Code を再起動すると反映されます'
    }
}
