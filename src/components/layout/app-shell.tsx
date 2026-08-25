"use client";

import { usePathname } from "next/navigation";
import { Sidebar } from "./sidebar";
import { ProjectProvider } from "@/lib/project-context";

const AUTH_PATHS = ["/login", "/auth"];

export function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const isAuthPage = AUTH_PATHS.some((p) => pathname.startsWith(p));

  if (isAuthPage) {
    return <>{children}</>;
  }

  return (
    <ProjectProvider>
      <div className="flex min-h-screen">
        <Sidebar />
        <main className="flex-1 overflow-auto">
          <div className="p-6 max-w-[1600px] mx-auto">{children}</div>
        </main>
      </div>
    </ProjectProvider>
  );
}
