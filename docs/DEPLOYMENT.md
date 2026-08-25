# OCI VM + PostgreSQL 배포 가이드

팀 2~3명 내부용으로 **Oracle Cloud Compute VM 1대**에 Next.js + PostgreSQL을 운영하는 방법입니다.  
Supabase는 **사용하지 않습니다** (자체 이메일/비밀번호 로그인).

---

## 1. 아키텍처

```
[팀원 PC] ──HTTPS/HTTP──▶ [OCI VM]
                              ├── Next.js (port 3000)
                              ├── PostgreSQL (port 5432, localhost only)
                              └── PM2 (프로세스 관리)
```

---

## 2. OCI VM 생성

1. OCI Console → **Compute → Instances → Create**
2. **Always Free** ARM VM (Ampere) 권장 — Ubuntu 22.04/24.04
3. **Security List** (방화벽):
   - SSH 22: 관리자 IP만
   - HTTP 3000 또는 443: 팀 IP 대역 (또는 VPN 뒤)
   - **5432는 외부 개방하지 말 것** (PostgreSQL은 localhost만)

---

## 3. VM 초기 설정

```bash
# 패키지
sudo apt update && sudo apt install -y git curl

# Node.js 20
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# PM2
sudo npm install -g pm2

# Docker (PostgreSQL용 — 선택)
sudo apt install -y docker.io docker-compose-v2
sudo usermod -aG docker $USER
# 재로그인 후
```

---

## 4. PostgreSQL 실행

### 방법 A: Docker Compose (권장)

프로젝트 루트의 `docker-compose.yml`:

```bash
cd /opt/cost-allocation   # clone 경로
docker compose up -d
```

### 방법 B: OS 패키지

```bash
sudo apt install -y postgresql postgresql-contrib
sudo -u postgres createuser costapp -P
sudo -u postgres createdb cost_allocation -O costapp
```

---

## 5. 앱 배포

```bash
git clone <your-repo> /opt/cost-allocation
cd /opt/cost-allocation
npm install

cp .env.example .env
# .env 편집 (아래 참고)

npm run db:push
npm run db:seed
npm run build

pm2 start npm --name cost-allocation -- start
pm2 save
pm2 startup   # 부팅 시 자동 시작
```

### `.env` (OCI VM 예시)

```env
DATABASE_URL="postgresql://costapp:STRONG_PASSWORD@localhost:5432/cost_allocation?schema=public"
NEXT_PUBLIC_APP_URL="http://YOUR_VM_PUBLIC_IP:3000"
SESSION_SECRET="<openssl rand -base64 32 결과>"
SEED_ADMIN_PASSWORD="<초기 관리자 비밀번호>"
```

---

## 6. 로그인

| 항목 | 값 |
|------|-----|
| URL | `http://VM_IP:3000/login` |
| 이메일 | `admin@kbi.local` |
| 비밀번호 | `SEED_ADMIN_PASSWORD` (seed 시 설정) |

팀원 추가:

```bash
npx tsx --env-file=.env scripts/add-user.ts jaeyong.lee@kbigrp.com "이름" "비밀번호"
```

또는 `npm run db:studio`로 `users` 레코드 직접 편집 (비밀번호는 bcrypt 해시 필요).

---

## 7. 백업

```bash
# PostgreSQL 덤프 (매일 cron 권장)
docker exec cost-allocation-db pg_dump -U costapp cost_allocation > backup_$(date +%F).sql
```

---

## 8. 로컬 개발 (동일 구성)

```powershell
cd "Cost Allocation"
docker compose up -d
Copy-Item .env.example .env
npm install
npm run db:push
npm run db:seed
npm run dev
```

확인: `npm run db:check` → http://localhost:3000/login

---

## 9. AUTH_DISABLED (선택)

로컬에서 로그인 없이 테스트:

```env
AUTH_DISABLED=true
```

---

## 10. Supabase에서 마이그레이션

기존 Supabase PostgreSQL 데이터가 있다면:

1. Supabase에서 `pg_dump`로 export
2. OCI PostgreSQL에 import
3. `.env`에서 Supabase URL/키 **제거**
4. `users.passwordHash`가 없는 계정은 seed 또는 비밀번호 재설정 필요

---

## 문제 해결

| 증상 | 해결 |
|------|------|
| `Can't reach database` | `docker compose ps`, DATABASE_URL 확인 |
| 로그인 실패 | `npm run db:seed` 재실행, passwordHash 확인 |
| 401 on API | SESSION_SECRET 설정, 쿠키/HTTPS 확인 |
| 포트 접속 불가 | OCI Security List 인바운드 규칙 |
