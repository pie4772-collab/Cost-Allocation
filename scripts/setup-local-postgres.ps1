# 로컬 PostgreSQL (Windows) DB·사용자 생성
# Usage:
#   $env:POSTGRES_ADMIN_PASSWORD = "설치 시 postgres 비밀번호"
#   .\scripts\setup-local-postgres.ps1

param(
  [string]$PostgresPassword = $env:POSTGRES_ADMIN_PASSWORD,
  [string]$AppUser = "costapp",
  [string]$AppPassword = "costapp",
  [string]$Database = "cost_allocation"
)

$ErrorActionPreference = "Stop"
$psql = "C:\Program Files\PostgreSQL\18\bin\psql.exe"

if (-not (Test-Path $psql)) {
  throw "psql not found at $psql — PostgreSQL 18 경로를 확인하세요."
}

if (-not $PostgresPassword) {
  Write-Host "postgres 슈퍼유저 비밀번호가 필요합니다." -ForegroundColor Yellow
  Write-Host '  $env:POSTGRES_ADMIN_PASSWORD = "설치 시 설정한 비밀번호"'
  Write-Host "  .\scripts\setup-local-postgres.ps1"
  exit 1
}

$env:PGPASSWORD = $PostgresPassword

Write-Host "=== 로컬 PostgreSQL 설정 ===" -ForegroundColor Cyan

& $psql -U postgres -h localhost -p 5432 -d postgres -v ON_ERROR_STOP=1 -c @"
DO `$`$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '$AppUser') THEN
    CREATE ROLE $AppUser LOGIN PASSWORD '$AppPassword';
  ELSE
    ALTER ROLE $AppUser WITH LOGIN PASSWORD '$AppPassword';
  END IF;
END
`$`$;
"@

$dbExists = (& $psql -U postgres -h localhost -p 5432 -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = '$Database'" 2>$null)
if ([string]::IsNullOrWhiteSpace($dbExists)) {
  & $psql -U postgres -h localhost -p 5432 -d postgres -v ON_ERROR_STOP=1 -c "CREATE DATABASE $Database OWNER $AppUser"
  Write-Host "✓ database $Database created"
} else {
  Write-Host "✓ database $Database already exists"
}

& $psql -U postgres -h localhost -p 5432 -d postgres -v ON_ERROR_STOP=1 -c "GRANT ALL PRIVILEGES ON DATABASE $Database TO $AppUser"
& $psql -U postgres -h localhost -p 5432 -d $Database -v ON_ERROR_STOP=1 -c "GRANT ALL ON SCHEMA public TO $AppUser"
& $psql -U postgres -h localhost -p 5432 -d $Database -v ON_ERROR_STOP=1 -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO $AppUser"
& $psql -U postgres -h localhost -p 5432 -d $Database -v ON_ERROR_STOP=1 -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO $AppUser"

Write-Host "✓ role $AppUser ready" -ForegroundColor Green
Write-Host ""
Write-Host "DATABASE_URL=postgresql://${AppUser}:${AppPassword}@localhost:5432/${Database}?schema=public"
