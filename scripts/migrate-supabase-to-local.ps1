# Supabase export → 로컬 PostgreSQL 전체 이전
param(
  [string]$SupabasePassword = $env:SUPABASE_DB_PASSWORD,
  [string]$PostgresPassword = $env:POSTGRES_ADMIN_PASSWORD,
  [string]$Database = "cost_allocation",
  [string]$AppUser = "costapp"
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$psql = "C:\Program Files\PostgreSQL\18\bin\psql.exe"
$sqlFile = Join-Path $root "backups\supabase-export.sql"

if (-not $SupabasePassword -or -not $PostgresPassword) {
  Write-Host "환경 변수 필요:" -ForegroundColor Yellow
  Write-Host '  $env:SUPABASE_DB_PASSWORD = "Supabase DB 비밀번호"'
  Write-Host '  $env:POSTGRES_ADMIN_PASSWORD = "로컬 postgres 비밀번호"'
  exit 1
}

$env:SUPABASE_DB_PASSWORD = $SupabasePassword
& (Join-Path $PSScriptRoot "export-supabase.ps1")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$env:PGPASSWORD = $PostgresPassword
Write-Host "=== 로컬 DB 초기화 ($Database) ===" -ForegroundColor Cyan

& $psql -U postgres -h localhost -p 5432 -d postgres -v ON_ERROR_STOP=1 -c @"
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = '$Database' AND pid <> pg_backend_pid();
"@

& $psql -U postgres -h localhost -p 5432 -d postgres -v ON_ERROR_STOP=1 -c "DROP DATABASE IF EXISTS $Database;"
& $psql -U postgres -h localhost -p 5432 -d postgres -v ON_ERROR_STOP=1 -c "CREATE DATABASE $Database OWNER $AppUser;"

Write-Host "=== 복원 중 ===" -ForegroundColor Cyan
& $psql -U postgres -h localhost -p 5432 -d $Database -v ON_ERROR_STOP=0 -f $sqlFile

& $psql -U postgres -h localhost -p 5432 -d $Database -v ON_ERROR_STOP=1 -c @"
GRANT ALL ON SCHEMA public TO $AppUser;
GRANT ALL ON ALL TABLES IN SCHEMA public TO $AppUser;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO $AppUser;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO $AppUser;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO $AppUser;
"@

Write-Host "✓ Supabase → 로컬 이전 완료" -ForegroundColor Green
