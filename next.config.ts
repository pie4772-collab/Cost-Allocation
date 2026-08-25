import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  experimental: {
    serverActions: {
      bodySizeLimit: "10mb",
    },
    optimizePackageImports: ["lucide-react"],
  },
  // 원격 Supabase DB — dev에서 연결 재사용
  serverExternalPackages: ["@prisma/client", "prisma"],
};

export default nextConfig;
