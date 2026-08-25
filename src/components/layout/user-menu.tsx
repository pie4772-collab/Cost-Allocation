"use client";

import { useEffect, useState } from "react";
import { LogOut, User } from "lucide-react";

export function UserMenu() {
  const [user, setUser] = useState<{ email: string; name: string } | null>(null);

  useEffect(() => {
    fetch("/api/auth/me", { credentials: "include" })
      .then((r) => r.json())
      .then((data) => {
        if (data?.email) setUser({ email: data.email, name: data.name });
      })
      .catch(() => {});
  }, []);

  const handleLogout = async () => {
    await fetch("/api/auth/logout", { method: "POST", credentials: "include" });
    window.location.href = "/login";
  };

  return (
    <div className="p-4 border-t border-navy-700 text-xs text-navy-400">
      <div className="flex items-center gap-2 mb-2">
        <User size={14} />
        <span className="truncate">{user?.name ?? user?.email ?? "게스트"}</span>
      </div>
      {user && (
        <button
          onClick={handleLogout}
          className="flex items-center gap-2 text-navy-300 hover:text-white transition-colors"
        >
          <LogOut size={14} />
          로그아웃
        </button>
      )}
    </div>
  );
}
