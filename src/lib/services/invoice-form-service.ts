import prisma from "../db";
import {
  INVOICE_BILLER,
  INVOICE_FORM_TITLE,
  type InvoiceFormData,
} from "../invoice-form-config";
import { isMonthlyPeriod } from "../period-utils";

function formatInvoicePeriod(period: {
  label: string;
  cadence?: string;
  year?: number;
  half?: number;
  month?: number | null;
}): string {
  if (isMonthlyPeriod(period) && period.month && period.year) {
    return `${period.year}년 ${period.month}월`;
  }
  if (period.year && period.half === 1) {
    return `${period.year}년 상반기 (1월~6월)`;
  }
  if (period.year && period.half === 2) {
    return `${period.year}년 하반기 (7월~12월)`;
  }
  return period.label;
}

function formatInvoiceDate(value: Date | null | undefined): string {
  const date = value ?? new Date();
  return date.toLocaleDateString("ko-KR", {
    year: "numeric",
    month: "long",
    day: "numeric",
  });
}

export async function getInvoiceFormData(
  invoiceId: string
): Promise<InvoiceFormData> {
  const invoice = await prisma.invoice.findUniqueOrThrow({
    where: { id: invoiceId },
    include: {
      company: true,
      lines: { orderBy: { lineNumber: "asc" } },
      run: {
        include: {
          project: { include: { period: true } },
          rateVersion: { include: { rates: true } },
        },
      },
    },
  });

  const accountIds = invoice.lines
    .map((l) => l.costAccountId)
    .filter((id): id is string => !!id);

  const accounts =
    accountIds.length > 0
      ? await prisma.costAccount.findMany({
          where: { id: { in: accountIds } },
        })
      : [];

  const accountMap = new Map(accounts.map((a) => [a.id, a]));

  const companyRate = invoice.run.rateVersion.rates.find(
    (r) => r.companyId === invoice.companyId
  );
  const allocationRatePercent = companyRate
    ? Number(companyRate.rate) * 100
    : 0;

  const isOverseas = invoice.invoiceType === "OVERSEAS";

  return {
    id: invoice.id,
    invoiceNumber: invoice.invoiceNumber,
    invoiceType: invoice.invoiceType,
    status: invoice.status,
    title: isOverseas ? "INVOICE" : INVOICE_FORM_TITLE,
    biller: INVOICE_BILLER,
    billToName: invoice.company.nameKo,
    billToNameEn: invoice.company.nameEn,
    periodDisplay: formatInvoicePeriod(invoice.run.project.period),
    issueDateDisplay: formatInvoiceDate(invoice.issueDate),
    allocationRatePercent,
    lines: invoice.lines.map((line) => {
      const account = line.costAccountId
        ? accountMap.get(line.costAccountId)
        : null;
      return {
        lineNumber: line.lineNumber,
        category: account?.description?.trim() || "기타",
        accountName: line.description,
        amount: line.amount.toString(),
      };
    }),
    subtotal: invoice.subtotal.toString(),
    markupAmount: invoice.markupAmount.toString(),
    totalAmount: invoice.totalAmount.toString(),
    runId: invoice.runId,
  };
}
