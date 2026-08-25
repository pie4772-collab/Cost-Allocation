import type { Metadata } from "next";
import { Noto_Sans_KR } from "next/font/google";
import "./globals.css";
import { AppShell } from "@/components/layout/app-shell";

const noto = Noto_Sans_KR({
  subsets: ["latin"],
  weight: ["400", "500", "600", "700"],
});

export const metadata: Metadata = {
  title: "KBI 공동비용 배부·청구 시스템",
  description: "KBI Group 공동비용 배분 및 계열사 청구 관리",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="ko">
      <body className={noto.className}>
        <AppShell>{children}</AppShell>
      </body>
    </html>
  );
}
