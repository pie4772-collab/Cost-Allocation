import { NextRequest, NextResponse } from "next/server";
import ExcelJS from "exceljs";
import prisma from "@/lib/db";
import { handleApiError } from "@/lib/api-utils";

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const runId = searchParams.get("runId");
    const type = searchParams.get("type") ?? "allocation";

    if (!runId) return handleApiError(new Error("runId is required"));

    const run = await prisma.allocationRun.findUniqueOrThrow({
      where: { id: runId },
      include: {
        project: { include: { period: true } },
        details: {
          include: { company: true, costAccount: true },
        },
        summaries: { include: { company: true } },
        reconciliation: true,
      },
    });

    const workbook = new ExcelJS.Workbook();
    workbook.creator = "KBI Cost Allocation System";
    workbook.created = new Date();

    if (type === "allocation") {
      const ws = workbook.addWorksheet("배부결과");

      const accounts = [...new Set(run.details.map((d) => d.costAccount))].sort(
        (a, b) => a.sortOrder - b.sortOrder
      );

      ws.addRow([
        "법인",
        "구분",
        ...accounts.map((a) => a.nameKo),
        "배분비용",
        "Mark-up",
        "총청구금액",
      ]);

      for (const summary of run.summaries.sort(
        (a, b) => a.company.sortOrder - b.company.sortOrder
      )) {
        const row: (string | number)[] = [
          summary.company.nameKo,
          summary.company.companyType === "OVERSEAS" ? "해외" : "국내",
        ];
        for (const account of accounts) {
          const detail = run.details.find(
            (d) =>
              d.companyId === summary.companyId &&
              d.costAccountId === account.id
          );
          row.push(detail ? Number(detail.allocatedAmount) : 0);
        }
        row.push(
          Number(summary.allocationAmount),
          Number(summary.markupAmount),
          Number(summary.billingAmount)
        );
        ws.addRow(row);
      }

      const reconWs = workbook.addWorksheet("절사차이");
      reconWs.addRow(["계정", "원가", "배부합계", "절사차이"]);
      if (run.reconciliation?.details) {
        const details = run.reconciliation.details as Array<{
          name: string;
          sourceTotal: string;
          allocatedSum: string;
          roundingDiff: string;
        }>;
        for (const d of details) {
          reconWs.addRow([
            d.name,
            Number(d.sourceTotal),
            Number(d.allocatedSum),
            Number(d.roundingDiff),
          ]);
        }
      }
    }

    if (type === "invoices") {
      const invoices = await prisma.invoice.findMany({
        where: { runId },
        include: { company: true, lines: true },
      });
      const ws = workbook.addWorksheet("청구서");
      ws.addRow([
        "법인",
        "유형",
        "상태",
        "소계",
        "Mark-up",
        "총액",
        "청구번호",
      ]);
      for (const inv of invoices) {
        ws.addRow([
          inv.company.nameKo,
          inv.invoiceType,
          inv.status,
          Number(inv.subtotal),
          Number(inv.markupAmount),
          Number(inv.totalAmount),
          inv.invoiceNumber ?? "",
        ]);
      }
    }

    const buffer = await workbook.xlsx.writeBuffer();
    const filename = `allocation-${run.project.period.label}-${type}.xlsx`;

    return new NextResponse(buffer, {
      headers: {
        "Content-Type":
          "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        "Content-Disposition": `attachment; filename="${filename}"`,
      },
    });
  } catch (error) {
    return handleApiError(error);
  }
}
