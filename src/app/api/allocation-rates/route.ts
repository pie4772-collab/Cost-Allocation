import { NextRequest } from "next/server";
import prisma from "@/lib/db";
import { getSessionUser } from "@/lib/auth";
import { jsonOk, handleApiError, serializeBigInt } from "@/lib/api-utils";
import { rateVersionSchema } from "@/lib/validations";
import { validateRates } from "@/lib/allocation-engine";
import { createAuditLog } from "@/lib/audit";

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const projectId = searchParams.get("projectId");
    if (!projectId) return handleApiError(new Error("projectId is required"));

    if (searchParams.get("previousSource") === "true") {
      const { getPreviousPeriodRateSource } = await import(
        "@/lib/services/rate-import-service"
      );
      return jsonOk(await getPreviousPeriodRateSource(projectId));
    }

    const user = await getSessionUser(request);
    const versionCount = await prisma.allocationRateVersion.count({
      where: { projectId },
    });
    if (versionCount === 0) {
      const { ensureDraftRateVersion } = await import(
        "@/lib/services/project-init-service"
      );
      await ensureDraftRateVersion(projectId, user?.id);
    }

    const { pruneInactiveRatesFromProject, activeCompanyWhere } = await import(
      "@/lib/services/master-data-service"
    );
    await pruneInactiveRatesFromProject(projectId);

    const versions = await prisma.allocationRateVersion.findMany({
      where: { projectId },
      include: {
        project: { include: { period: true } },
        rates: {
          where: { company: activeCompanyWhere },
          include: { company: true },
          orderBy: { company: { sortOrder: "asc" } },
        },
      },
      orderBy: { version: "desc" },
    });
    return jsonOk(serializeBigInt(versions));
  } catch (error) {
    return handleApiError(error);
  }
}

export async function POST(request: NextRequest) {
  try {
    const user = await getSessionUser(request);
    if (!user) return handleApiError(new Error("FORBIDDEN"));

    const body = rateVersionSchema.parse(await request.json());

    const companies = await prisma.company.findMany({
      where: { id: { in: body.rates.map((r) => r.companyId) }, isActive: true },
    });

    const rateInputs = body.rates.map((r) => {
      const company = companies.find((c) => c.id === r.companyId)!;
      return {
        companyId: r.companyId,
        companyCode: company.code,
        companyName: company.nameKo,
        companyType: company.companyType,
        rate: r.rate,
      };
    });

    const validation = validateRates(rateInputs);

    const lastVersion = await prisma.allocationRateVersion.findFirst({
      where: { projectId: body.projectId },
      orderBy: { version: "desc" },
    });
    const version = (lastVersion?.version ?? 0) + 1;

    const rateVersion = await prisma.allocationRateVersion.create({
      data: {
        projectId: body.projectId,
        version,
        status: "DRAFT",
        totalRate: validation.total / 100,
        notes: body.notes,
        createdById: user.id,
        rates: {
          create: body.rates.map((r) => ({
            companyId: r.companyId,
            rate: r.rate,
          })),
        },
      },
      include: {
        rates: { include: { company: true } },
      },
    });

    await createAuditLog({
      userId: user.id,
      action: "CREATE",
      entityType: "AllocationRateVersion",
      entityId: rateVersion.id,
      afterData: { totalRate: validation.total, valid: validation.valid },
    });

    return jsonOk(
      serializeBigInt({ ...rateVersion, validation }),
      201
    );
  } catch (error) {
    return handleApiError(error);
  }
}

export async function PATCH(request: NextRequest) {
  try {
    const user = await getSessionUser(request);
    if (!user) return handleApiError(new Error("FORBIDDEN"));

    const body = await request.json();
    const { rateVersionId, action } = body;

    if (action === "approve" || action === "confirm") {
      const { approveRateVersion } = await import(
        "@/lib/services/allocation-service"
      );
      const result = await approveRateVersion(rateVersionId, user.id);
      return jsonOk(serializeBigInt(result));
    }

    if (action === "reopen") {
      const { reopenRateVersion } = await import(
        "@/lib/services/allocation-service"
      );
      const result = await reopenRateVersion(rateVersionId, user.id);
      return jsonOk(serializeBigInt(result));
    }

    if (action === "import_previous") {
      const { importPreviousPeriodRates } = await import(
        "@/lib/services/rate-import-service"
      );
      const result = await importPreviousPeriodRates(rateVersionId, user.id);
      return jsonOk(serializeBigInt(result));
    }

    if (action === "submit") {
      const updated = await prisma.allocationRateVersion.update({
        where: { id: rateVersionId },
        data: { status: "PENDING_APPROVAL" },
      });
      return jsonOk(serializeBigInt(updated));
    }

    if (action === "add_company") {
      const { companyId } = body as { companyId: string };
      const { activeCompanyWhere } = await import(
        "@/lib/services/master-data-service"
      );

      const company = await prisma.company.findFirst({
        where: { id: companyId, ...activeCompanyWhere },
      });
      if (!company) {
        throw new Error("활성 법인만 배분 대상에 추가할 수 있습니다.");
      }

      const rateVersion = await prisma.allocationRateVersion.findUniqueOrThrow({
        where: { id: rateVersionId },
      });
      if (rateVersion.status === "APPROVED") {
        throw new Error("확정된 배분율에는 법인을 추가할 수 없습니다.");
      }

      const exists = await prisma.allocationRate.findFirst({
        where: { rateVersionId, companyId },
      });
      if (exists) {
        throw new Error("이미 포함된 법인입니다.");
      }

      const rate = await prisma.allocationRate.create({
        data: { rateVersionId, companyId, rate: 0 },
        include: { company: true },
      });

      return jsonOk(serializeBigInt(rate), 201);
    }

    if (action === "update_rates") {
      const { rates } = body as {
        rates: Array<{ companyId: string; rate: number }>;
      };

      const rateVersion = await prisma.allocationRateVersion.findUniqueOrThrow({
        where: { id: rateVersionId },
      });
      if (rateVersion.status === "APPROVED") {
        throw new Error("확정된 배분율은 수정할 수 없습니다. 수정하기를 눌러 다시 편집하세요.");
      }

      const { activeCompanyWhere } = await import(
        "@/lib/services/master-data-service"
      );

      const companies = await prisma.company.findMany({
        where: {
          id: { in: rates.map((r) => r.companyId) },
          ...activeCompanyWhere,
        },
      });

      if (companies.length !== rates.length) {
        throw new Error("비활성 또는 삭제된 법인은 배분율에 포함할 수 없습니다.");
      }

      const rateInputs = rates.map((r) => {
        const company = companies.find((c) => c.id === r.companyId)!;
        return {
          companyId: r.companyId,
          companyCode: company.code,
          companyName: company.nameKo,
          companyType: company.companyType,
          rate: r.rate,
        };
      });

      const validation = validateRates(rateInputs);

      await prisma.$transaction(async (tx) => {
        for (const r of rates) {
          await tx.allocationRate.updateMany({
            where: { rateVersionId, companyId: r.companyId },
            data: { rate: r.rate },
          });
        }
        await tx.allocationRateVersion.update({
          where: { id: rateVersionId },
          data: { totalRate: validation.total / 100 },
        });
      });

      await createAuditLog({
        userId: user.id,
        action: "RATE_UPDATE",
        entityType: "AllocationRateVersion",
        entityId: rateVersionId,
        afterData: { totalRate: validation.total, valid: validation.valid },
      });

      return jsonOk(serializeBigInt({ validation }));
    }

    return handleApiError(new Error("Unknown action"));
  } catch (error) {
    return handleApiError(error);
  }
}
