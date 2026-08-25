import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  productionBrowserSourceMaps: false,
  experimental: {
    cpus: 1,
    serverActions: {
      bodySizeLimit: "10mb",
    },
    optimizePackageImports: ["lucide-react"],
  },
  serverExternalPackages: ["@prisma/client", "prisma"],
};

export default nextConfig;
