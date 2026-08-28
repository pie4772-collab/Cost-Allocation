"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/utils";
import { useProjectContext } from "@/lib/project-context";
import { projectHref } from "@/lib/use-project-id";
import {
  LayoutDashboard,
  FolderKanban,
  Building2,
  Calculator,
  Percent,
  FileText,
  CheckSquare,
  ScrollText,
  CalendarDays,
  Users,
} from "lucide-react";
import { UserMenu } from "./user-menu";

const NAV_ITEMS = [
  { href: "/", label: "대시보드", icon: LayoutDashboard, needsProject: false },
  { href: "/monthly-projects", label: "월별 프로젝트", icon: CalendarDays, needsProject: false },
  { href: "/projects", label: "반기 프로젝트", icon: FolderKanban, needsProject: false },
  { href: "/costs", label: "① 원가 입력", icon: Calculator, needsProject: true },
  { href: "/rates", label: "② 배분율", icon: Percent, needsProject: true },
  { href: "/allocation", label: "③ 배분 계산", icon: Calculator, needsProject: true },
  { href: "/reconciliation", label: "④ 절사·대사", icon: CheckSquare, needsProject: true },
  { href: "/invoices", label: "⑤ 청구서", icon: FileText, needsProject: true },
  { href: "/companies", label: "법인 관리", icon: Building2, needsProject: false },
  { href: "/users", label: "사용자 관리", icon: Users, needsProject: false, adminOnly: true },
  { href: "/audit-logs", label: "감사로그", icon: ScrollText, needsProject: false },
];

export function Sidebar() {
  const pathname = usePathname();
  const { selectedProject } = useProjectContext();
  const [isAdmin, setIsAdmin] = useState(false);

  useEffect(() => {
    fetch("/api/auth/me", { credentials: "include" })
      .then((r) => r.json())
      .then((me) => {
        setIsAdmin(Array.isArray(me?.roles) && me.roles.includes("Admin"));
      })
      .catch(() => setIsAdmin(false));
  }, []);

  return (
    <aside className="w-56 bg-navy-900 text-white flex flex-col min-h-screen">
      <div className="p-4 border-b border-navy-700">
        <h1 className="text-sm font-bold leading-tight">KBI 공동비용</h1>
        <p className="text-xs text-navy-300 mt-1">배부·청구 시스템</p>
        {selectedProject && (
          <p className="text-[10px] text-navy-400 mt-2 leading-tight truncate" title={selectedProject.name}>
            {selectedProject.period.label}
          </p>
        )}
      </div>
      <nav className="flex-1 p-2 space-y-0.5">
        {NAV_ITEMS.filter((item) => !item.adminOnly || isAdmin).map(
          ({ href, label, icon: Icon, needsProject }) => {
            const linkHref = needsProject
              ? projectHref(href, selectedProject?.id ?? null)
              : href;
            const active = pathname === href || pathname.startsWith(`${href}?`);

            return (
              <Link
                key={href}
                href={linkHref}
                className={cn(
                  "flex items-center gap-2 px-3 py-2 rounded text-sm transition-colors",
                  active
                    ? "bg-navy-700 text-white"
                    : "text-navy-200 hover:bg-navy-800 hover:text-white"
                )}
              >
                <Icon size={16} />
                {label}
              </Link>
            );
          }
        )}
      </nav>
      <UserMenu />
    </aside>
  );
}
