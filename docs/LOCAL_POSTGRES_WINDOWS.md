# Windows 로컬 PostgreSQL 설정

PostgreSQL 18 Windows 설치 후 이 프로젝트를 **완전 로컬 DB**로 실행하는 방법입니다.

---

## 1. DB·사용자 생성 (최초 1회)

PowerShell (프로젝트 루트):

```powershell
cd "c:\Users\pie84\Cost Allocation"

# PostgreSQL 설치 시 설정한 postgres 슈퍼유저 비밀번호
$env:POSTGRES_ADMIN_PASSWORD = "여기에-postgres-비밀번호"

.\scripts\setup-local-postgres.ps1
```

생성 결과:

| 항목 | 값 |
|------|-----|
| DB | `cost_allocation` |
| 사용자 | `costapp` / `costapp` |
| 포트 | `5432` |

`.env`의 `DATABASE_URL`은 이미 로컬 URL로 설정되어 있습니다.

---

## 2-A. 새 DB로 시작 (권장 — 빠름)

```powershell
npm run db:push
npm run db:seed
npx tsx --env-file=.env scripts/add-user.ts jaeyong.lee@kbigrp.com "이재용" "원하는비밀번호"
npm run db:check
npm run dev
```

로그인: http://localhost:3000/login

---

## 2-B. Supabase 데이터 이전 (기존 작업 유지)

Supabase에서 export:

```powershell
$env:PGPASSWORD = "Supabase-DB-비밀번호"
& "C:\Program Files\PostgreSQL\18\bin\pg_dump.exe" `
  -h aws-0-ap-northeast-2.pooler.supabase.com -p 5432 `
  -U postgres.vdycbwvozeopictnggct -d postgres `
  --no-owner --no-acl -F p `
  -f backups\supabase-export.sql
```

로컬 복원 (1단계 setup 후):

```powershell
$env:POSTGRES_ADMIN_PASSWORD = "postgres-비밀번호"
.\scripts\restore-local-postgres.ps1
npm run db:check
npm run dev
```

---

## 3. psql PATH 추가 (선택)

```powershell
[Environment]::SetEnvironmentVariable(
  "Path",
  $env:Path + ";C:\Program Files\PostgreSQL\18\bin",
  "User"
)
```

PowerShell 재시작 후 `psql --version` 확인.

---

## 문제 해결

| 증상 | 해결 |
|------|------|
| `password authentication failed for user "costapp"` | `setup-local-postgres.ps1` 재실행 |
| `database "cost_allocation" does not exist` | setup 스크립트 실행 |
| `Can't reach database server` | 서비스 `postgresql-x64-18` 실행 중인지 확인 |
| Supabase 복원 오류 | `db:push` + `db:seed`로 새로 시작 (2-A) |
