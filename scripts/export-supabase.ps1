# Supabase PostgreSQL → SQL 파일 export
param(
  [string]$DbHost = "aws-0-ap-northeast-2.pooler.supabase.com",
  [int]$Port = 5432,
  [string]$User = "postgres.vdycbwvozeopictnggct",
  [string]$Database = "postgres",
  [string]$Password = $env:SUPABASE_DB_PASSWORD,
  [string]$OutFile = "backups\supabase-export.sql"
)

$ErrorActionPreference = "Stop"
$pgDump = "C:\Program Files\PostgreSQL\18\bin\pg_dump.exe"
$root = Split-Path $PSScriptRoot -Parent
$OutPath = Join-Path $root $OutFile

if (-not (Test-Path $pgDump)) {
  throw "pg_dump not found at $pgDump"
}

if (-not $Password) {
  Write-Host "SUPABASE_DB_PASSWORD 환경 변수를 설정하세요." -ForegroundColor Yellow
  exit 1
}

New-Item -ItemType Directory -Force -Path (Split-Path $OutPath -Parent) | Out-Null

$env:PGPASSWORD = $Password
Write-Host "=== Supabase export → $OutPath ===" -ForegroundColor Cyan

& $pgDump `
  -h $DbHost -p $Port -U $User -d $Database `
  --schema=public `
  --no-owner --no-acl `
  -F p `
  -f $OutPath

if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$size = (Get-Item $OutPath).Length
Write-Host "✓ export 완료 ($([math]::Round($size/1KB, 1)) KB)" -ForegroundColor Green
