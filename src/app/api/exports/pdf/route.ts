import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/db";
import { handleApiError } from "@/lib/api-utils";
import { getInvoiceFormData } from "@/lib/services/invoice-form-service";
import { buildInvoicePdf } from "@/lib/pdf/invoice-pdf";

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const invoiceId = searchParams.get("invoiceId");
    if (!invoiceId) return handleApiError(new Error("invoiceId is required"));

    const invoice = await prisma.invoice.findUniqueOrThrow({
      where: { id: invoiceId },
      select: { company: { select: { code: true } } },
    });

    const formData = await getInvoiceFormData(invoiceId);
    const pdfBytes = await buildInvoicePdf(formData);
    const filename = `invoice-${invoice.company.code}.pdf`;

    return new NextResponse(Buffer.from(pdfBytes), {
      headers: {
        "Content-Type": "application/pdf",
        "Content-Disposition": `attachment; filename="${filename}"`,
      },
    });
  } catch (error) {
    return handleApiError(error);
  }
}
