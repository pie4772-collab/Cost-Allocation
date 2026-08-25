import ExcelJS from "exceljs";

const path =
  process.argv[2] ??
  "c:\\Users\\pie84\\OneDrive\\문서\\공동비용 배분\\260710 Scripture Room Cost Allocation Report (Invoice form).xlsx";

function cellStr(cell: ExcelJS.Cell | undefined): string {
  if (!cell || cell.value == null) return "";
  const v = cell.value;
  if (typeof v === "object" && v !== null && "richText" in v) {
    return (v as ExcelJS.CellRichTextValue).richText.map((t) => t.text).join("");
  }
  if (typeof v === "object" && v !== null && "text" in v) {
    return String((v as { text: string }).text);
  }
  if (typeof v === "object" && v !== null && "result" in v) {
    return String((v as { result: unknown }).result ?? "");
  }
  return String(v).trim();
}

async function main() {
  const wb = new ExcelJS.Workbook();
  await wb.xlsx.readFile(path);

  for (const ws of wb.worksheets) {
    console.log(`\n=== Sheet: ${ws.name} (${ws.rowCount}x${ws.columnCount}) ===`);
    for (let r = 1; r <= Math.min(60, ws.rowCount || 60); r++) {
      const parts: string[] = [];
      for (let c = 1; c <= Math.min(12, ws.columnCount || 12); c++) {
        const s = cellStr(ws.getCell(r, c));
        if (s) parts.push(`C${c}=${JSON.stringify(s)}`);
      }
      if (parts.length) console.log(`R${r}: ${parts.join(" | ")}`);
    }

    // merges
    const merges = (ws as unknown as { _merges?: Record<string, unknown> })._merges;
    if (merges) {
      console.log("Merges:", Object.keys(merges).slice(0, 20).join(", "));
    }
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
