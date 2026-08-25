import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function main() {
  const before = {
    runs: await prisma.allocationRun.count(),
    details: await prisma.allocationDetail.count(),
    summaries: await prisma.companyAllocationSummary.count(),
    invoices: await prisma.invoice.count(),
    invoiceLines: await prisma.invoiceLine.count(),
    reconciliation: await prisma.reconciliationResult.count(),
    rates: await prisma.allocationRate.count(),
    rateVersions: await prisma.allocationRateVersion.count(),
  };

  console.log("삭제 전:", before);

  const invoiceLines = await prisma.invoiceLine.deleteMany();
  const invoices = await prisma.invoice.deleteMany();
  const reconciliation = await prisma.reconciliationResult.deleteMany();
  const runs = await prisma.allocationRun.deleteMany();

  const reset = await prisma.allocationProject.updateMany({
    where: {
      status: {
        in: ["CALCULATED", "RECONCILED", "BILLING_APPROVED", "CLOSED"],
      },
    },
    data: { status: "RATES_APPROVED" },
  });

  const approvalCleanup = await prisma.approvalRequest.deleteMany({
    where: {
      type: {
        in: ["ALLOCATION_APPROVAL", "INVOICE_APPROVAL", "INVOICE_ISSUE"],
      },
    },
  });

  const after = {
    runs: await prisma.allocationRun.count(),
    details: await prisma.allocationDetail.count(),
    summaries: await prisma.companyAllocationSummary.count(),
    invoices: await prisma.invoice.count(),
    invoiceLines: await prisma.invoiceLine.count(),
    reconciliation: await prisma.reconciliationResult.count(),
    rates: await prisma.allocationRate.count(),
    rateVersions: await prisma.allocationRateVersion.count(),
  };

  console.log("\n삭제 완료:");
  console.log(`  allocation_runs: ${runs.count}건`);
  console.log(`  invoices: ${invoices.count}건`);
  console.log(`  invoice_lines: ${invoiceLines.count}건`);
  console.log(`  reconciliation_results: ${reconciliation.count}건`);
  console.log(`  (details/summaries는 run 삭제 시 cascade)`);
  console.log(`  관련 승인 요청: ${approvalCleanup.count}건`);
  console.log(`  프로젝트 상태 RATES_APPROVED로 복원: ${reset.count}건`);
  console.log("\n삭제 후 (배부율 유지 확인):", after);
}

main()
  .catch((e) => {
    console.error("❌", e.message ?? e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
