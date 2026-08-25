import ExcelJS from "exceljs";
import { formatCompanyCode } from "./company-utils";

export const DEFAULT_EXCEL_PATH =
  "c:\\Users\\pie84\\OneDrive\\문서\\공동비용 배분\\260710 Scripture Room Cost Allocation Report (For Development Use).xlsx";

function cellNum(cell: ExcelJS.Cell | undefined): number {
  if (cell?.value == null) return 0;
  const v = cell.value;
  if (typeof v === "number") return Math.round(v);
  if (typeof v === "object" && v !== null && "result" in v) {
    const r = (v as { result: unknown }).result;
    if (typeof r === "number") return Math.round(r);
  }
  const n = parseFloat(String(v).replace(/,/g, ""));
  return isNaN(n) ? 0 : Math.round(n);
}

function cellStr(cell: ExcelJS.Cell | undefined): string {
  if (cell?.value == null) return "";
  const v = cell.value;
  if (typeof v === "object" && v !== null && "richText" in v) {
    return (v as ExcelJS.CellRichTextValue).richText.map((t) => t.text).join("");
  }
  if (typeof v === "object" && v !== null && "text" in v) {
    return String((v as { text: string }).text);
  }
  return String(v).trim();
}

export interface ParsedAccount {
  code: string;
  nameKo: string;
  category: string;
  sortOrder: number;
}

export interface ParsedCompany {
  code: string;
  nameKo: string;
  nameEn?: string;
  rate: number;
  companyType: "DOMESTIC" | "OVERSEAS";
  contactName?: string;
  contactTitle?: string;
  address?: string;
  sortOrder: number;
}

export interface ParsedMonthlyCost {
  accountCode: string;
  month: number;
  amount: number;
}

export interface ParsedExcelData {
  accounts: ParsedAccount[];
  companies: ParsedCompany[];
  monthlyCosts: ParsedMonthlyCost[];
  halfYearTotals: Record<string, number>;
  rateTotal: number;
  grandTotal: number;
}

const OVERSEAS_KEYWORDS = [
  "GMBH",
  "L.L.C",
  "MEXICO",
  "VINA",
  "YANCHENG",
  "INDIA",
  "JAPAN",
  "LABO",
  "LIMITED",
  "CO., LTD",
];

/** 비용집계 시트 컬럼 (C2~C20) */
const COST_COLUMNS: Array<{ col: number; category: string; nameKo: string }> = [
  { col: 2, category: "급상여", nameKo: "급료와임금" },
  { col: 3, category: "급상여", nameKo: "상여금" },
  { col: 4, category: "급상여", nameKo: "복리후생비(기타)" },
  { col: 5, category: "복리후생", nameKo: "건강보험" },
  { col: 6, category: "복리후생", nameKo: "국민연금" },
  { col: 7, category: "복리후생", nameKo: "산재보험" },
  { col: 8, category: "복리후생", nameKo: "고용보험" },
  { col: 9, category: "기타", nameKo: "식대(식권)" },
  { col: 10, category: "기타", nameKo: "업무추진비" },
  { col: 11, category: "기타", nameKo: "소모품비" },
  { col: 12, category: "기타", nameKo: "국내출장비" },
  { col: 13, category: "기타", nameKo: "지급수수료" },
  { col: 14, category: "기타", nameKo: "통신비" },
  { col: 15, category: "기타", nameKo: "도서인쇄비" },
  { col: 16, category: "기타", nameKo: "국외출장비" },
  { col: 17, category: "기타", nameKo: "감가상각비(차량)" },
  { col: 18, category: "기타", nameKo: "차량관리비" },
  { col: 19, category: "기타", nameKo: "기타지급" },
  { col: 20, category: "기타", nameKo: "지급수수료(일반)" },
];

function isOverseas(name: string, address?: string): boolean {
  if (address && address.length > 8) return true;
  const upper = name.toUpperCase();
  return OVERSEAS_KEYWORDS.some((k) => upper.includes(k));
}

export async function parseExcelCosts(
  filePath: string,
  options: { months?: number[] } = {}
): Promise<Pick<ParsedExcelData, "accounts" | "monthlyCosts" | "halfYearTotals" | "grandTotal">> {
  const months = options.months ?? [1, 2, 3, 4, 5, 6];
  const wb = new ExcelJS.Workbook();
  await wb.xlsx.readFile(filePath);

  const costSheet = wb.getWorksheet("비용집계");
  if (!costSheet) {
    throw new Error("비용집계 시트를 찾을 수 없습니다.");
  }

  const accounts: ParsedAccount[] = COST_COLUMNS.map((c, i) => ({
    code: `ACC-${String(i + 1).padStart(2, "0")}`,
    nameKo: c.nameKo,
    category: c.category,
    sortOrder: i + 1,
  }));

  const monthlyCosts: ParsedMonthlyCost[] = [];
  const halfYearTotals: Record<string, number> = {};

  for (const month of months) {
    const row = costSheet.getRow(5 + month);
    for (const acc of accounts) {
      const col = COST_COLUMNS.find((c) => c.nameKo === acc.nameKo)!.col;
      monthlyCosts.push({
        accountCode: acc.code,
        month,
        amount: cellNum(row.getCell(col)),
      });
    }
  }

  const totalRow = costSheet.getRow(12);
  for (const acc of accounts) {
    const col = COST_COLUMNS.find((c) => c.nameKo === acc.nameKo)!.col;
    halfYearTotals[acc.code] = cellNum(totalRow.getCell(col));
  }

  const grandTotal = cellNum(totalRow.getCell(22));

  return { accounts, monthlyCosts, halfYearTotals, grandTotal };
}

export async function parseExcelFile(filePath = DEFAULT_EXCEL_PATH): Promise<ParsedExcelData> {
  const wb = new ExcelJS.Workbook();
  await wb.xlsx.readFile(filePath);

  const costSheet = wb.getWorksheet("비용집계");
  const rateSheet = wb.getWorksheet("배분비율_배포용") ?? wb.getWorksheet("배분비율");
  const rateDetailSheet = wb.getWorksheet("배분비율");

  if (!costSheet || !rateSheet) {
    throw new Error("비용집계 또는 배분비율 시트를 찾을 수 없습니다.");
  }

  const { accounts, monthlyCosts, halfYearTotals, grandTotal } =
    await parseExcelCosts(filePath);

  const companies: ParsedCompany[] = [];
  let rateTotal = 0;

  for (let r = 4; r <= 40; r++) {
    const row = rateSheet.getRow(r);
    const name = cellStr(row.getCell(1));
    if (!name || name === "합계" || name.includes("구분")) continue;

    const rateDecimal = parseFloat(String(row.getCell(2).value ?? 0));
    if (rateDecimal <= 0) continue;

    let address: string | undefined;
    if (rateDetailSheet) {
      for (let dr = 4; dr <= 40; dr++) {
        const detailName = cellStr(rateDetailSheet.getRow(dr).getCell(2));
        if (detailName === name) {
          address = cellStr(rateDetailSheet.getRow(dr).getCell(8)) || undefined;
          break;
        }
      }
    }

    const overseas = isOverseas(name, address);
    companies.push({
      code: formatCompanyCode(companies.length + 1),
      nameKo: name,
      nameEn: overseas ? name : undefined,
      rate: rateDecimal,
      companyType: overseas ? "OVERSEAS" : "DOMESTIC",
      contactName: cellStr(row.getCell(3)) || undefined,
      contactTitle: cellStr(row.getCell(4)) || undefined,
      address,
      sortOrder: companies.length + 1,
    });
    rateTotal += rateDecimal;
  }

  return {
    accounts,
    companies,
    monthlyCosts,
    halfYearTotals,
    rateTotal: rateTotal * 100,
    grandTotal,
  };
}
