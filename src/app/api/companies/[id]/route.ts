import { NextRequest } from "next/server";
import prisma from "@/lib/db";
import { getSessionUser } from "@/lib/auth";
import { jsonOk, handleApiError, serializeBigInt } from "@/lib/api-utils";
import { companyUpdateSchema } from "@/lib/validations";
import { createAuditLog } from "@/lib/audit";

type RouteParams = { params: Promise<{ id: string }> };

export async function PATCH(request: NextRequest, { params }: RouteParams) {
  try {
    const user = await getSessionUser(request);
    if (!user) return handleApiError(new Error("FORBIDDEN"));

    const { id } = await params;
    const { address, ...body } = companyUpdateSchema.parse(await request.json());

    const before = await prisma.company.findUniqueOrThrow({
      where: { id, deletedAt: null },
      include: { addresses: { where: { deletedAt: null, isPrimary: true } } },
    });

    const company = await prisma.$transaction(async (tx) => {
      await tx.company.update({
        where: { id },
        data: {
          ...body,
          contactEmail: body.contactEmail === "" ? null : body.contactEmail,
        },
      });

      if (address) {
        const existingAddr = before.addresses[0];
        if (existingAddr) {
          await tx.companyAddress.update({
            where: { id: existingAddr.id },
            data: address,
          });
        } else {
          await tx.companyAddress.create({
            data: { companyId: id, ...address, isPrimary: true },
          });
        }
      }

      return tx.company.findUniqueOrThrow({
        where: { id },
        include: { addresses: { where: { deletedAt: null } } },
      });
    });

    await createAuditLog({
      userId: user.id,
      action: "UPDATE",
      entityType: "Company",
      entityId: id,
      beforeData: before,
      afterData: company,
    });

    if (body.isActive === false) {
      const { removeCompanyFromDraftRateVersions } = await import(
        "@/lib/services/master-data-service"
      );
      await removeCompanyFromDraftRateVersions(id);
    }

    return jsonOk(serializeBigInt(company));
  } catch (error) {
    return handleApiError(error);
  }
}

export async function DELETE(request: NextRequest, { params }: RouteParams) {
  try {
    const user = await getSessionUser(request);
    if (!user) return handleApiError(new Error("FORBIDDEN"));

    const { id } = await params;
    const before = await prisma.company.findUniqueOrThrow({
      where: { id, deletedAt: null },
    });

    const company = await prisma.company.update({
      where: { id },
      data: { isActive: false, deletedAt: new Date() },
      include: { addresses: true },
    });

    const { removeCompanyFromDraftRateVersions } = await import(
      "@/lib/services/master-data-service"
    );
    await removeCompanyFromDraftRateVersions(id);

    await createAuditLog({
      userId: user.id,
      action: "DELETE",
      entityType: "Company",
      entityId: id,
      beforeData: before,
    });

    return jsonOk(serializeBigInt(company));
  } catch (error) {
    return handleApiError(error);
  }
}
