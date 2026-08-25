import { NextRequest } from "next/server";
import prisma from "@/lib/db";
import { jsonOk, handleApiError, serializeBigInt } from "@/lib/api-utils";
import { isRateTotalAcceptable } from "@/lib/math";
import { projectTypeLabel } from "@/lib/period-utils";

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const projectId = searchParams.get("projectId");

    const project = projectId
      ? await prisma.allocationProject.findUnique({
          where: { id: projectId },
          include: { period: true },
        })
      : null;

    if (projectId && !project) {
      return handleApiError(new Error("프로젝트를 찾을 수 없습니다."));
    }

    const companies = await prisma.company.findMany({
      where: { isActive: true, deletedAt: null },
    });

    const overseasCount = companies.filter(
      (c) => c.companyType === "OVERSEAS"
    ).length;

    let totalCost = 0n;
    let totalBilling = 0n;
    let totalMarkup = 0n;
    let rateTotal = 0;
    let roundingDiffAbs = 0n;
    let errorCount = 0;
    let pendingIssue = 0;

    if (project) {
      const costs = await prisma.monthlyCost.groupBy({
        by: ["costAccountId"],
        where: { projectId: project.id, status: "CONFIRMED" },
        _sum: { amount: true },
      });
      totalCost = costs.reduce((s, c) => s + (c._sum.amount ?? 0n), 0n);

      const latestRun = await prisma.allocationRun.findFirst({
        where: { projectId: project.id, runType: "FINAL" },
        orderBy: { createdAt: "desc" },
        include: { reconciliation: true },
      });

      if (latestRun) {
        totalBilling = latestRun.totalBilling;
        totalMarkup = latestRun.totalMarkup;
        roundingDiffAbs =
          latestRun.reconciliation?.accountRoundingDiff ?? 0n;
        if (roundingDiffAbs < 0n) roundingDiffAbs = -roundingDiffAbs;
      }

      const rateVersion = await prisma.allocationRateVersion.findFirst({
        where: { projectId: project.id },
        orderBy: { version: "desc" },
      });
      if (rateVersion) {
        rateTotal = Number(rateVersion.totalRate) * 100;
        if (!isRateTotalAcceptable(rateTotal)) errorCount++;
      }

      pendingIssue = await prisma.invoice.count({
        where: { status: "APPROVED", run: { projectId: project.id } },
      });
    }

    return jsonOk(
      serializeBigInt({
        project,
        metrics: {
          totalCost: totalCost.toString(),
          companyCount: companies.length,
          overseasCount,
          totalMarkup: totalMarkup.toString(),
          totalBilling: totalBilling.toString(),
          rateTotal,
          rateValid: isRateTotalAcceptable(rateTotal),
          roundingDiffAbs: roundingDiffAbs.toString(),
          errorCount,
          pendingIssue,
        },
        storyInBrief: project
          ? `${project.period.label} ${projectTypeLabel(project.period)} 공동비용 배부 — ${project.name} (${project.status})`
          : "프로젝트를 선택하세요.",
      })
    );
  } catch (error) {
    return handleApiError(error);
  }
}
