import ExcelJS from "exceljs";
import path from "path";

const filePath =
  process.argv[2] ??
  "c:\\Users\\pie84\\OneDrive\\문서\\공동비용 배분\\260710 Scripture Room Cost Allocation Report (For Development Use).xlsx";

async function main() {
  const wb = new ExcelJS.Workbook();
  await wb.xlsx.readFile(filePath);

  console.log("=== SHEETS ===");
  for (const sheet of wb.worksheets) {
    console.log(`\n--- ${sheet.name} (${sheet.rowCount} rows) ---`);
    for (let r = 1; r <= Math.min(25, sheet.rowCount); r++) {
      const row = sheet.getRow(r);
      const vals: string[] = [];
      row.eachCell({ includeEmpty: false }, (cell, col) => {
        const v = cell.value;
        let s =
          typeof v === "object" && v !== null && "result" in v
            ? String((v as { result: unknown }).result)
            : String(v ?? "");
        if (s.length > 40) s = s.slice(0, 40) + "…";
        vals[col - 1] = s;
      });
      if (vals.some(Boolean)) console.log(`R${r}:`, vals.join(" | "));
    }
  }
}

main().catch(console.error);
