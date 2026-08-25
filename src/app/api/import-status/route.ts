import { NextResponse } from "next/server";
import prisma from "@/lib/db";

export async function GET() {
  if (process.env.IMPORT_LOCAL_DATA !== "true") {
    return NextResponse.json({ error: "NOT_FOUND" }, { status: 404 });
  }

  const [users, companies, projects, invoices] = await Promise.all([
    prisma.user.count(),
    prisma.company.count(),
    prisma.allocationProject.count(),
    prisma.invoice.count(),
  ]);

  return NextResponse.json({
    dumpFound: process.env.IMPORT_DUMP_FOUND === "1",
    markerFound: process.env.IMPORT_MARKER_FOUND === "1",
    dumpName: process.env.IMPORT_DUMP_NAME ?? "",
    importState: process.env.IMPORT_STATE ?? "",
    users,
    companies,
    projects,
    invoices,
  });
}
