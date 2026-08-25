"use client";

import { useEffect, useState } from "react";
import { PageHeader, StatusBadge, LoadingState } from "@/components/ui/common";

interface Approval {
  id: string;
  type: string;
  status: string;
  entityType: string;
  entityId: string;
  reason: string | null;
  createdAt: string;
  actions: Array<{
    action: string;
    comment: string | null;
    user: { name: string };
    createdAt: string;
  }>;
}

export default function ApprovalsPage() {
  const [approvals, setApprovals] = useState<Approval[]>([]);
  const [loading, setLoading] = useState(true);

  const load = () => {
    fetch("/api/approvals")
      .then((r) => r.json())
      .then(setApprovals)
      .finally(() => setLoading(false));
  };

  useEffect(() => { load(); }, []);

  const handleAction = async (requestId: string, action: string) => {
    await fetch("/api/approvals", {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ requestId, action, comment: "" }),
    });
    load();
  };

  if (loading) return <LoadingState />;

  return (
    <>
      <PageHeader title="승인함" description="배분율·배부·청구 승인 요청" />

      <div className="card overflow-x-auto">
        <table className="data-table">
          <thead>
            <tr>
              <th>유형</th>
              <th>상태</th>
              <th>대상</th>
              <th>사유</th>
              <th>요청일</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {approvals.length === 0 ? (
              <tr><td colSpan={6} className="text-center text-navy-400 py-8">승인 요청이 없습니다</td></tr>
            ) : (
              approvals.map((a) => (
                <tr key={a.id}>
                  <td>{a.type}</td>
                  <td><StatusBadge status={a.status} /></td>
                  <td className="text-xs font-mono">{a.entityType}/{a.entityId.slice(0, 8)}</td>
                  <td>{a.reason ?? "-"}</td>
                  <td>{new Date(a.createdAt).toLocaleDateString("ko-KR")}</td>
                  <td>
                    {a.status === "PENDING" && (
                      <>
                        <button
                          className="text-xs text-green-600 hover:underline mr-2"
                          onClick={() => handleAction(a.id, "APPROVED")}
                        >
                          승인
                        </button>
                        <button
                          className="text-xs text-red-600 hover:underline"
                          onClick={() => handleAction(a.id, "REJECTED")}
                        >
                          반려
                        </button>
                      </>
                    )}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </>
  );
}
