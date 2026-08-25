import prisma from "./db";

export function formatCompanyCode(sequence: number): string {
  return `kbi-${String(sequence).padStart(2, "0")}`;
}

export function parseCompanyCodeNumber(code: string): number | null {
  const match = code.match(/^kbi-(\d+)$/i);
  if (!match) return null;
  const n = parseInt(match[1], 10);
  return Number.isFinite(n) ? n : null;
}

export async function generateCompanyCode(): Promise<string> {
  const companies = await prisma.company.findMany({ select: { code: true } });
  let max = 0;
  for (const company of companies) {
    const n = parseCompanyCodeNumber(company.code);
    if (n != null) max = Math.max(max, n);
  }
  return formatCompanyCode(max + 1);
}

export function nextCompanyCodeFromList(codes: string[]): string {
  let max = 0;
  for (const code of codes) {
    const n = parseCompanyCodeNumber(code);
    if (n != null) max = Math.max(max, n);
  }
  return formatCompanyCode(max + 1);
}
