# Supabase export SQL → 로컬 PostgreSQL 복원
param(
  [string]$PostgresPassword = $env:POSTGRES_ADMIN_PASSWORD,
  [string]$Database = "cost_allocation",
  [string]$SqlFile = "backups\supabase-export.sql"
)

$ErrorActionPreference = "Stop"
$psql = "C:\Program Files\PostgreSQL\18\bin\psql.exe"
$SqlFile = Join-Path (Split-Path $PSScriptRoot -Parent) $SqlFile
if (-not (Test-Path $SqlFile)) {
  $SqlFile = Join-Path (Get-Location) "backups\supabase-export.sql"
}

if (-not $PostgresPassword) {
  Write-Host "POSTGRES_ADMIN_PASSWORD 환경 변수를 설정하세요." -ForegroundColor Yellow
  exit 1
}

if (-not (Test-Path $SqlFile)) {
  Write-Host "SQL 파일 없음: $SqlFile — 먼저 Supabase export 실행" -ForegroundColor Red
  exit 1
}

$env:PGPASSWORD = $PostgresPassword
Write-Host "=== 로컬 DB 복원: $SqlFile ===" -ForegroundColor Cyan
& $psql -U postgres -h localhost -p 5432 -d $Database -v ON_ERROR_STOP=0 -f $SqlFile
Write-Host "✓ 복원 완료 (일부 Supabase 전용 객체 경고는 무시 가능)" -ForegroundColor Green
