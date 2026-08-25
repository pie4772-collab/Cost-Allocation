import { Suspense } from "react";
import { LoadingState } from "@/components/ui/common";

export default function RatesLayout({ children }: { children: React.ReactNode }) {
  return <Suspense fallback={<LoadingState />}>{children}</Suspense>;
}
