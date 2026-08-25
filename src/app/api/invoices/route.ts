import { NextRequest } from "next/server";
import prisma from "@/lib/db";
import { getSessionUser } from "@/lib/auth";
import { jsonOk, handleApiError, serializeBigInt } from "@/lib/api-utils";
import {
  generateInvoicesFromRun,
  issueInvoice,
  confirmProjectCosts,
  reopenProjectCosts,
} from "@/lib/services/allocation-service";
import { createAuditLog } from "@/lib/audit";

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const runId = searchParams.get("runId");
    const projectId = searchParams.get("projectId");
    const status = searchParams.get("status");

    const invoices = await prisma.invoice.findMany({
      where: {
        ...(runId ? { runId } : {}),
        ...(projectId ? { run: { projectId } } : {}),
        ...(status ? { status: status as never } : {}),
      },
      include: {
        company: true,
        run: { include: { project: { include: { period: true } } } },
        lines: { orderBy: { lineNumber: "asc" } },
      },
      orderBy: { createdAt: "desc" },
    });
    return jsonOk(serializeBigInt(invoices));
  } catch (error) {
    return handleApiError(error);
  }
}

export async function POST(request: NextRequest) {
  try {
    const user = await getSessionUser(request);
    if (!user) return handleApiError(new Error("FORBIDDEN"));

    const body = await request.json();

    if (body.action === "generate") {
      const invoices = await generateInvoicesFromRun(body.runId, user.id);
      return jsonOk(serializeBigInt(invoices), 201);
    }

    if (body.action === "confirm_costs") {
      const project = await confirmProjectCosts(body.projectId, user.id);
      return jsonOk(serializeBigInt(project));
    }

    if (body.action === "reopen_costs") {
      const project = await reopenProjectCosts(body.projectId, user.id);
      return jsonOk(serializeBigInt(project));
    }

    return handleApiError(new Error("Unknown action"));
  } catch (error) {
    return handleApiError(error);
  }
}

export async function PATCH(request: NextRequest) {
  try {
    const user = await getSessionUser(request);
    if (!user) return handleApiError(new Error("FORBIDDEN"));

    const { invoiceId, action } = await request.json();

    if (action === "approve") {
      const invoice = await prisma.invoice.update({
        where: { id: invoiceId },
        data: { status: "APPROVED" },
      });
      await createAuditLog({
        userId: user.id,
        action: "INVOICE_APPROVE",
        entityType: "Invoice",
        entityId: invoiceId,
      });
      return jsonOk(serializeBigInt(invoice));
    }

    if (action === "issue") {
      const invoice = await issueInvoice(invoiceId, user.id);
      return jsonOk(serializeBigInt(invoice));
    }

    return handleApiError(new Error("Unknown action"));
  } catch (error) {
    return handleApiError(error);
  }
}
