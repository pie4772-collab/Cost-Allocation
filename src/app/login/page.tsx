"use client";

import { useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";

export default function LoginPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const next = searchParams.get("next") ?? "/";

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError("");

    try {
      const res = await fetch("/api/auth/login", {
        method: "POST",
        credentials: "include",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password }),
      });
      const data = await res.json();
      if (!res.ok) {
        throw new Error(data.error ?? "로그인에 실패했습니다.");
      }
      router.push(next);
      router.refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : "로그인에 실패했습니다.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-navy-900">
      <div className="w-full max-w-md card mx-4">
        <div className="mb-6 text-center">
          <h1 className="text-xl font-bold text-navy-900">KBI 공동비용 배부·청구</h1>
          <p className="text-sm text-navy-500 mt-1">계정으로 로그인</p>
        </div>

        <form onSubmit={handleLogin} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-navy-700 mb-1">
              이메일
            </label>
            <input
              type="email"
              className="input"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="admin@kbi.local"
              required
              autoComplete="email"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-navy-700 mb-1">
              비밀번호
            </label>
            <input
              type="password"
              className="input"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              autoComplete="current-password"
            />
          </div>

          {error && (
            <div className="text-sm text-red-600 bg-red-50 border border-red-200 rounded p-2">
              {error}
            </div>
          )}

          <button type="submit" className="btn-primary w-full" disabled={loading}>
            {loading ? "로그인 중..." : "로그인"}
          </button>
        </form>

        <p className="text-xs text-navy-400 mt-6 text-center">
          초기 관리자: <code className="text-navy-600">admin@kbi.local</code>
          <br />
          비밀번호는 <code className="text-navy-600">SEED_ADMIN_PASSWORD</code> (seed 시 설정)
        </p>
      </div>
    </div>
  );
}
