import ExcelJS from "exceljs";

const DEFAULT_PATH =
  "c:\\Users\\pie84\\OneDrive\\문서\\공동비용 배분\\260710 Scripture Room Cost Allocation Report (For Development Use).xlsx";

function cellNum(cell: ExcelJS.Cell | undefined): number {
  if (!cell || cell.value == null) return 0;
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
  if (!cell || cell.value == null) return "";
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
}

const OVERSEAS_KEYWORDS = [
  "GmbH",
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

function isOverseas(name: string, address?: string): boolean {
  if (address && address.length > 5) return true;
  const upper = name.toUpperCase();
  return OVERSEAS_KEYWORDS.some((k) => upper.includes(k.toUpperCase()));
}

function slugCode(name: string, index: number): string {
  const map: Record<string, string> = {
    "케이비아이메탈㈜ 음성공장": "METAL",
    "케이비아이동국실업 ㈜ 신아산공장": "SILUP",
    "케이비오토텍 주식회사": "AT-HQ",
    "KDK Automotive GmbH": "KDK",
    "케이비아이코스모링크 주식회사": "COSMO",
    "케이비아이동양철관 주식회사": "STEEL",
    "케이비아이건설 주식회사": "CONST",
    "KB REMICON L.L.C": "REMICON-AJ",
    "K B READY MIX L.L.C": "REMICON-SH",
    "의료법인갑을의료재단갑을장유병원": "HOSPITAL",
    "DONG KOOK MEXICO": "MEXICO",
    "KBI COSMOLINK VINA CABLE CO., LTD": "VINA",
    "㈜케이비아이에이스텍 아산1공장": "ACETEC",
    "주식회사 케이비아이국인산업": "KUKIN",
    "케이비아이알로이 주식회사": "ALLOY",
    "YANCHENG DONG KOOK AUTO PARTS CO., LTD.": "YANCHENG",
    "주식회사 석문에너지": "SEOKMOON",
    "갑을합섬㈜": "HAPSUM",
    "㈜케이비아이텍": "KBI-TEC",
    "KB AUTOTECH INDIA PRIVATE LIMITED": "AT-IN",
    "대구에코 주식회사": "DAEGU-ECO",
    "케이비아이유상테크 주식회사": "USANG",
    "케이비아이울트라 주식회사": "ULTRA",
    "KBI JAPAN CO., LTD.": "JAPAN",
    "KBI LABO CO., LTD.": "LABO",
    "케이비아이정무 주식회사": "JEONGMU",
    "케이비아이뷰티앤 주식회사": "BEAUTYN",
    "케이비아이산업개발 주식회사": "IND-DEV",
    "케이비아이상사 주식회사": "SANGSA",
    "케이비아이화공 주식회사": "HWAKONG",
  };
  return map[name] ?? `C${String(index + 1).padStart(2, "0")}`;
}

export async function parseExcelFile(filePath = DEFAULT_PATH): Promise<ParsedExcelData> {
  const wb = new ExcelJS.Workbook();
  await wb.xlsx.readFile(filePath);

  const costSheet = wb.getWorksheet("비용집계");
  const rateSheet = wb.getWorksheet("배분비율_배포용") ?? wb.getWorksheet("배분비율");
  const rateDetailSheet = wb.getWorksheet("배분비율");

  if (!costSheet || !rateSheet) {
    throw new Error("비용집계 또는 배분비율 시트를 찾을 수 없습니다.");
  }

  // Account columns from row 5 (1-indexed row 5)
  const accountCols: Array<{ col: number; name: string; category: string }> = [];
  const headerRow5 = costSheet.getRow(5);
  const categoryRow4 = costSheet.getRow(4);

  for (let c = 2; c <= 20; c++) {
    const name = cellStr(headerRow5.getCell(c));
    if (!name || name === "계" || name === "월") continue;
    const category = cellStr(categoryRow4.getCell(c)) || "기타";
    accountCols.push({ col: c, name, category });
  }

  const accounts: ParsedAccount[] = accountCols.map((a, i) => ({
    code: `ACC-${String(i + 1).padStart(2, "0")}`,
    nameKo: a.name,
    category: a.category,
    sortOrder: i + 1,
  }));

  const monthlyCosts: ParsedMonthlyCost[] = [];
  const halfYearTotals: Record<string, number> = {};

  for (let month = 1; month <= 6; month++) {
    const row = costSheet.getRow(5 + month); // rows 6-11
    for (const acc of accounts) {
      const colInfo = accountCols.find((a) => a.name === acc.nameKo)!;
      const amount = cellNum(row.getCell(colInfo.col));
      monthlyCosts.push({
        accountCode: acc.code,
        month,
        amount,
      });
    }
  }

  const totalRow = costSheet.getRow(12);
  for (const acc of accounts) {
    const colInfo = accountCols.find((a) => a.name === acc.nameKo)!;
    halfYearTotals[acc.code] = cellNum(totalRow.getCell(colInfo.col));
  }

  // Companies from 배분비율_배포용 starting row 4
  const companies: ParsedCompany[] = [];
  let rateTotal = 0;

  for (let r = 4; r <= 40; r++) {
    const row = rateSheet.getRow(r);
    const name = cellStr(row.getCell(1));
    const rate = cellNum(row.getCell(2)) / (cellNum(row.getCell(2)) > 1 ? 100 : 1);
    // rates in excel are decimals like 0.255...
    let rateDecimal = parseFloat(String(row.getCell(2).value ?? 0));
    if (rateDecimal > 1) rateDecimal = rateDecimal / 100;

    if (!name || name === "합계" || name.includes("구분")) continue;
    if (rateDecimal <= 0) continue;

    let address: string | undefined;
    if (rateDetailSheet) {
      for (let dr = 4; dr <= 40; dr++) {
        if (cellStr(rateDetailSheet.getRow(dr).getCell(2)) === name) {
          address = cellStr(rateDetailSheet.getRow(dr).getCell(8)) || undefined;
          break;
        }
      }
    }

    const overseas = isOverseas(name, address);
    companies.push({
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
  };
}

async function main() {
  const data = await parseExcelFile(process.argv[2]);
  console.log(JSON.stringify(data, null, 2));
  console.error(`\nAccounts: ${data.accounts.length}`);
  console.error(`Companies: ${data.companies.length}`);
  console.error(`Monthly costs: ${data.monthlyCosts.length}`);
  console.error(`Rate total: ${data.rateTotal.toFixed(6)}%`);
}

if (require.main === module) {
  main().catch(console.error);
}
