import { NextRequest } from "next/server";
import prisma from "@/lib/db";
import { getSessionUser } from "@/lib/auth";
import { jsonOk, handleApiError, serializeBigInt } from "@/lib/api-utils";
import { companySchema } from "@/lib/validations";
import { createAuditLog } from "@/lib/audit";
import { generateCompanyCode } from "@/lib/company-utils";

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const activeOnly = searchParams.get("active") !== "false";

    const companies = await prisma.company.findMany({
      where: activeOnly ? { isActive: true, deletedAt: null } : { deletedAt: null },
      include: { addresses: { where: { deletedAt: null } } },
      orderBy: { sortOrder: "asc" },
    });
    return jsonOk(serializeBigInt(companies));
  } catch (error) {
    return handleApiError(error);
  }
}

export async function POST(request: NextRequest) {
  try {
    const user = await getSessionUser(request);
    if (!user) return handleApiError(new Error("FORBIDDEN"));

    const raw = await request.json();
    const { address, ...body } = companySchema.parse(raw);

    const code = body.code?.trim() || (await generateCompanyCode());

    const company = await prisma.company.create({
      data: {
        ...body,
        code,
        addresses: address
          ? {
              create: {
                line1: address.line1,
                line2: address.line2,
                city: address.city,
                state: address.state,
                postalCode: address.postalCode,
                country: address.country,
              },
            }
          : undefined,
      },
      include: { addresses: true },
    });

    const { syncCompanyToDraftRateVersions } = await import(
      "@/lib/services/master-data-service"
    );
    await syncCompanyToDraftRateVersions(company.id);

    await createAuditLog({
      userId: user.id,
      action: "CREATE",
      entityType: "Company",
      entityId: company.id,
      afterData: company,
    });

    return jsonOk(serializeBigInt(company), 201);
  } catch (error) {
    return handleApiError(error);
  }
}
