import ExcelJS from "exceljs";

const path =
  "c:\\Users\\pie84\\OneDrive\\문서\\공동비용 배분\\260710 Scripture Room Cost Allocation Report (For Development Use).xlsx";

function v(cell: ExcelJS.Cell | undefined) {
  if (!cell?.value) return "";
  const val = cell.value;
  if (typeof val === "object" && "result" in val) return String((val as {result:unknown}).result);
  return String(val);
}

async function main() {
  const wb = new ExcelJS.Workbook();
  await wb.xlsx.readFile(path);
  const s = wb.getWorksheet("비용집계")!;
  for (let r = 3; r <= 12; r++) {
    const parts: string[] = [];
    for (let c = 1; c <= 22; c++) {
      const val = v(s.getRow(r).getCell(c));
      if (val) parts.push(`C${c}=${val.slice(0,15)}`);
    }
    console.log(`R${r}:`, parts.join(" | "));
  }
}
main();
