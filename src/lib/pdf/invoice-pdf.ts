import fs from "fs";
import path from "path";
import { PDFDocument, PDFFont, PDFPage, rgb } from "pdf-lib";
import fontkit from "@pdf-lib/fontkit";
import {
  INVOICE_FOOTER_NOTE,
  type InvoiceFormData,
} from "@/lib/invoice-form-config";

const PAGE_WIDTH = 595;
const PAGE_HEIGHT = 842;
const MARGIN = 42;
const CONTENT_WIDTH = PAGE_WIDTH - MARGIN * 2;

const TITLE_HEIGHT = 28;
const META_LABEL_WIDTH = 78;
const META_ROW_HEIGHT = 20;
const HEADER_HEIGHT = 22;
const ROW_HEIGHT = 22;
const SUMMARY_HEIGHT = 22;
const FOOTER_RESERVE = 36;
const TITLE_SIZE = 13;
const BODY_SIZE = 9;
const FOOTER_SIZE = 8;
const COL_NO = 40;
const COL_CATEGORY = 78;
const COL_AMOUNT = 96;
const COL_ACCOUNT = CONTENT_WIDTH - COL_NO - COL_CATEGORY - COL_AMOUNT;

const TEXT = rgb(0.12, 0.16, 0.26);
const BORDER = rgb(0.55, 0.6, 0.68);
const HEADER_BG = rgb(0.93, 0.95, 0.97);
const SUMMARY_BG = rgb(0.96, 0.97, 0.98);

function formatKRW(value: string): string {
  return Number(value).toLocaleString("ko-KR");
}

async function loadKoreanFont(pdfDoc: PDFDocument) {
  pdfDoc.registerFontkit(fontkit);
  const fontPath = path.join(
    process.cwd(),
    "public",
    "fonts",
    "NotoSansKR-Regular.otf"
  );
  const bytes = fs.readFileSync(fontPath);
  const font = await pdfDoc.embedFont(bytes, { subset: true });
  return font;
}

/**
 * pdf-lib drawText y is the glyph baseline, not the cell top.
 * Noto CJK Hangul ink sits high in the Win-ascent box, so we center a
 * typical 1em glyph (92% above / 8% below baseline) instead of font.head metrics.
 */
function baselineY(
  cellTop: number,
  cellHeight: number,
  fontSize: number
): number {
  const cellBottom = cellTop - cellHeight;
  // Hangul visual center is ~0.38em above the baseline.
  return cellBottom + cellHeight / 2 - fontSize * 0.45;
}

function truncateText(
  text: string,
  font: PDFFont,
  size: number,
  maxWidth: number
): string {
  const ellipsis = "…";
  if (font.widthOfTextAtSize(text, size) <= maxWidth) return text;
  let result = text;
  while (
    result.length > 0 &&
    font.widthOfTextAtSize(result + ellipsis, size) > maxWidth
  ) {
    result = result.slice(0, -1);
  }
  return result + ellipsis;
}

export async function buildInvoicePdf(
  data: InvoiceFormData
): Promise<Uint8Array> {
  const pdfDoc = await PDFDocument.create();
  const font = await loadKoreanFont(pdfDoc);
  const isOverseas = data.invoiceType === "OVERSEAS";
  const billTo = isOverseas
    ? data.billToNameEn ?? data.billToName
    : data.billToName;

  let page = pdfDoc.addPage([PAGE_WIDTH, PAGE_HEIGHT]);
  let y = PAGE_HEIGHT - MARGIN;

  const drawText = (
    text: string,
    x: number,
    baseline: number,
    size: number,
    maxWidth?: number
  ) => {
    const display =
      maxWidth && font.widthOfTextAtSize(text, size) > maxWidth
        ? truncateText(text, font, size, maxWidth)
        : text;
    page.drawText(display, {
      x,
      y: baseline,
      size,
      font,
      color: TEXT,
    });
  };

  const fillCell = (
    x: number,
    cellTop: number,
    width: number,
    height: number,
    bg?: ReturnType<typeof rgb>
  ) => {
    page.drawRectangle({
      x,
      y: cellTop - height,
      width,
      height,
      borderColor: BORDER,
      borderWidth: 0.6,
      color: bg,
    });
  };

  const drawCellText = (
    text: string,
    x: number,
    cellTop: number,
    width: number,
    height: number,
    size: number,
    align: "left" | "center" | "right"
  ) => {
    const pad = 6;
    const maxW = Math.max(4, width - pad * 2);
    const display =
      font.widthOfTextAtSize(text, size) > maxW
        ? truncateText(text, font, size, maxW)
        : text;
    const tw = font.widthOfTextAtSize(display, size);
    let tx = x + pad;
    if (align === "center") tx = x + (width - tw) / 2;
    if (align === "right") tx = x + width - tw - pad;
    drawText(display, tx, baselineY(cellTop, height, size), size);
  };

  const ensureSpace = (needed: number) => {
    if (y - needed >= MARGIN) return;
    page = pdfDoc.addPage([PAGE_WIDTH, PAGE_HEIGHT]);
    y = PAGE_HEIGHT - MARGIN;
  };

  ensureSpace(TITLE_HEIGHT);
  fillCell(MARGIN, y, CONTENT_WIDTH, TITLE_HEIGHT, HEADER_BG);
  drawCellText(
    data.title,
    MARGIN,
    y,
    CONTENT_WIDTH,
    TITLE_HEIGHT,
    TITLE_SIZE,
    "center"
  );
  y -= TITLE_HEIGHT + 8;

  const metaRows: Array<[string, string]> = [
    [isOverseas ? "From" : "청구자", data.biller.name],
    [isOverseas ? "Address" : "주  소", data.biller.address],
    [isOverseas ? "Tel" : "연락처", data.biller.phone],
    ["", ""],
    [isOverseas ? "Bill To" : "청구대상", billTo],
    [isOverseas ? "Period" : "청구기간", data.periodDisplay],
    [isOverseas ? "Date" : "청구일자", data.issueDateDisplay],
    [
      isOverseas ? "Rate" : "배분비율",
      `${data.allocationRatePercent.toFixed(6)}%`,
    ],
  ];

  for (const [label, value] of metaRows) {
    if (!label && !value) {
      y -= 6;
      continue;
    }
    ensureSpace(META_ROW_HEIGHT);
    fillCell(MARGIN, y, META_LABEL_WIDTH, META_ROW_HEIGHT, HEADER_BG);
    fillCell(
      MARGIN + META_LABEL_WIDTH,
      y,
      CONTENT_WIDTH - META_LABEL_WIDTH,
      META_ROW_HEIGHT
    );
    drawCellText(
      label,
      MARGIN,
      y,
      META_LABEL_WIDTH,
      META_ROW_HEIGHT,
      BODY_SIZE,
      "left"
    );
    drawCellText(
      value,
      MARGIN + META_LABEL_WIDTH,
      y,
      CONTENT_WIDTH - META_LABEL_WIDTH,
      META_ROW_HEIGHT,
      BODY_SIZE,
      "left"
    );
    y -= META_ROW_HEIGHT;
  }

  y -= 10;

  const tableX = MARGIN;
  const headers = [
    { text: "No.", width: COL_NO },
    { text: isOverseas ? "Category" : "구분", width: COL_CATEGORY },
    { text: isOverseas ? "Description" : "계정과목", width: COL_ACCOUNT },
    { text: isOverseas ? "Amount (KRW)" : "금액(원)", width: COL_AMOUNT },
  ];

  const drawTableHeader = (target: PDFPage) => {
    page = target;
    ensureSpace(HEADER_HEIGHT);
    let x = tableX;
    for (const h of headers) {
      fillCell(x, y, h.width, HEADER_HEIGHT, HEADER_BG);
      drawCellText(h.text, x, y, h.width, HEADER_HEIGHT, BODY_SIZE, "center");
      x += h.width;
    }
    y -= HEADER_HEIGHT;
  };

  drawTableHeader(page);

  for (const line of data.lines) {
    if (y - ROW_HEIGHT < MARGIN + FOOTER_RESERVE) {
      page = pdfDoc.addPage([PAGE_WIDTH, PAGE_HEIGHT]);
      y = PAGE_HEIGHT - MARGIN;
      drawTableHeader(page);
    }

    const cells: Array<{
      text: string;
      width: number;
      align: "left" | "center" | "right";
    }> = [
      { text: String(line.lineNumber), width: COL_NO, align: "center" },
      { text: line.category, width: COL_CATEGORY, align: "center" },
      { text: line.accountName, width: COL_ACCOUNT, align: "left" },
      { text: formatKRW(line.amount), width: COL_AMOUNT, align: "right" },
    ];

    let x = tableX;
    for (const cell of cells) {
      fillCell(x, y, cell.width, ROW_HEIGHT);
      drawCellText(cell.text, x, y, cell.width, ROW_HEIGHT, BODY_SIZE, cell.align);
      x += cell.width;
    }
    y -= ROW_HEIGHT;
  }

  const drawSummaryRow = (label: string, amount: string) => {
    if (y - SUMMARY_HEIGHT < MARGIN + FOOTER_RESERVE) {
      page = pdfDoc.addPage([PAGE_WIDTH, PAGE_HEIGHT]);
      y = PAGE_HEIGHT - MARGIN;
    }
    const labelSpan = COL_NO + COL_CATEGORY + COL_ACCOUNT;
    fillCell(tableX, y, labelSpan, SUMMARY_HEIGHT, SUMMARY_BG);
    fillCell(
      tableX + labelSpan,
      y,
      COL_AMOUNT,
      SUMMARY_HEIGHT,
      SUMMARY_BG
    );
    drawCellText(label, tableX, y, labelSpan, SUMMARY_HEIGHT, BODY_SIZE, "right");
    drawCellText(
      formatKRW(amount),
      tableX + labelSpan,
      y,
      COL_AMOUNT,
      SUMMARY_HEIGHT,
      BODY_SIZE,
      "right"
    );
    y -= SUMMARY_HEIGHT;
  };

  drawSummaryRow(
    isOverseas ? "Subtotal" : "배분 비용 소계",
    data.subtotal
  );

  if (BigInt(data.markupAmount) > 0n) {
    drawSummaryRow("Mark-up (5%)", data.markupAmount);
  }

  drawSummaryRow(isOverseas ? "Total" : "총 청구금액", data.totalAmount);

  y -= 10;
  if (!isOverseas) {
    const footerY = y - FOOTER_SIZE;
    drawText(INVOICE_FOOTER_NOTE, MARGIN, footerY, FOOTER_SIZE);
    y = footerY - 6;
  }

  if (data.invoiceNumber) {
    drawText(
      `${isOverseas ? "Invoice No." : "청구번호"}: ${data.invoiceNumber}`,
      MARGIN,
      y - FOOTER_SIZE,
      FOOTER_SIZE
    );
  }

  return pdfDoc.save();
}
