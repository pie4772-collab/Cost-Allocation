"use client";

import { useEffect, useState } from "react";
import { PageHeader, LoadingState } from "@/components/ui/common";

interface AuditLog {
  id: string;
  action: string;
  entityType: string;
  entityId: string;
  reason: string | null;
  createdAt: string;
  user: { name: string; email: string } | null;
  beforeData: unknown;
  afterData: unknown;
}

export default function AuditLogsPage() {
  const [logs, setLogs] = useState<AuditLog[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetch("/api/audit-logs?limit=100")
      .then((r) => r.json())
      .then((data) => {
        setLogs(data.logs);
        setTotal(data.total);
      })
      .finally(() => setLoading(false));
  }, []);

  if (loading) return <LoadingState />;

  return (
    <>
      <PageHeader title="감사로그" description={`전체 ${total}건`} />

      <div className="card overflow-x-auto">
        <table className="data-table">
          <thead>
            <tr>
              <th>시간</th>
              <th>사용자</th>
              <th>액션</th>
              <th>대상</th>
              <th>사유</th>
            </tr>
          </thead>
          <tbody>
            {logs.map((log) => (
              <tr key={log.id}>
                <td className="text-xs whitespace-nowrap">
                  {new Date(log.createdAt).toLocaleString("ko-KR")}
                </td>
                <td>{log.user?.name ?? "시스템"}</td>
                <td className="font-mono text-xs">{log.action}</td>
                <td className="text-xs">{log.entityType}/{log.entityId.slice(0, 8)}</td>
                <td>{log.reason ?? "-"}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}
