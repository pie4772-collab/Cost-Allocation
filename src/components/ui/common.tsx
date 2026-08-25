import { cn, formatAmount, statusColor, STATUS_LABELS } from "@/lib/utils";

interface MetricCardProps {
  label: string;
  value: string;
  sub?: string;
  variant?: "default" | "success" | "warning" | "danger";
}

export function MetricCard({ label, value, sub, variant = "default" }: MetricCardProps) {
  const colors = {
    default: "border-navy-200",
    success: "border-green-300 bg-green-50",
    warning: "border-orange-300 bg-orange-50",
    danger: "border-red-300 bg-red-50",
  };

  return (
    <div className={cn("card", colors[variant])}>
      <p className="text-xs text-navy-500 mb-1">{label}</p>
      <p className="text-xl font-semibold text-navy-900">{value}</p>
      {sub && <p className="text-xs text-navy-400 mt-1">{sub}</p>}
    </div>
  );
}

export function StatusBadge({ status }: { status: string }) {
  return (
    <span className={cn("badge", statusColor(status))}>
      {STATUS_LABELS[status] ?? status}
    </span>
  );
}

export function PageHeader({
  title,
  description,
  actions,
}: {
  title: string;
  description?: string;
  actions?: React.ReactNode;
}) {
  return (
    <div className="flex items-start justify-between mb-6">
      <div>
        <h1 className="text-2xl font-bold text-navy-900">{title}</h1>
        {description && (
          <p className="text-sm text-navy-500 mt-1">{description}</p>
        )}
      </div>
      {actions && <div className="flex gap-2">{actions}</div>}
    </div>
  );
}

export function AmountCell({ value }: { value: string | number }) {
  return <td className="amount">{formatAmount(value)}</td>;
}

export function LoadingState() {
  return (
    <div className="flex items-center justify-center py-20 text-navy-400">
      데이터를 불러오는 중...
    </div>
  );
}

export function EmptyState({ message }: { message: string }) {
  return (
    <div className="flex items-center justify-center py-20 text-navy-400">
      {message}
    </div>
  );
}

export function ErrorState({ message }: { message: string }) {
  return (
    <div className="card border-red-300 bg-red-50 text-red-700">{message}</div>
  );
}
