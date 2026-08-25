"use client";

import { useProjectContext } from "@/lib/project-context";
import { projectHref } from "@/lib/use-project-id";

const STEPS = [
  { step: 1, label: "공동비용(원가) 입력", path: "/costs" },
  { step: 2, label: "배분율 입력", path: "/rates" },
  { step: 3, label: "배분 계산", path: "/allocation" },
  { step: 4, label: "절사·대사", path: "/reconciliation" },
  { step: 5, label: "청구서 작성", path: "/invoices" },
] as const;

export function ProcessSteps({ current }: { current: 1 | 2 | 3 | 4 | 5 }) {
  const { selectedProject } = useProjectContext();
  const projectId = selectedProject?.id ?? null;

  return (
    <div className="flex flex-wrap gap-2 mb-6">
      {STEPS.map(({ step, label, path }) => (
        <a
          key={step}
          href={projectHref(path, projectId)}
          className={`flex items-center gap-2 px-3 py-1.5 rounded-full text-xs border transition-colors ${
            current === step
              ? "bg-navy-800 text-white border-navy-800"
              : "bg-white text-navy-600 border-navy-200 hover:border-navy-400"
          }`}
        >
          <span
            className={`w-5 h-5 rounded-full flex items-center justify-center text-[10px] font-bold ${
              current === step ? "bg-white text-navy-800" : "bg-navy-100 text-navy-600"
            }`}
          >
            {step}
          </span>
          {label}
        </a>
      ))}
    </div>
  );
}
