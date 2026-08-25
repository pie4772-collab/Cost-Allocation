/** Excel 「청구서_양식」 기준 청구자(발행) 정보 */
export const INVOICE_BILLER = {
  name: "KBI동양철관 주식회사",
  address: "충청남도 천안시 동남구 풍세면 풍세로 515",
  phone: "02-6903-0236",
} as const;

export const INVOICE_FORM_TITLE = "KBI 그룹 공동비용 청구서";

export const INVOICE_FOOTER_NOTE =
  "※ 상기 금액을 청구하오니 기한 내 입금하여 주시기 바랍니다.";

export type InvoiceFormLine = {
  lineNumber: number;
  category: string;
  accountName: string;
  amount: string;
};

export type InvoiceFormData = {
  id: string;
  invoiceNumber: string | null;
  invoiceType: string;
  status: string;
  title: string;
  biller: typeof INVOICE_BILLER;
  billToName: string;
  billToNameEn: string | null;
  periodDisplay: string;
  issueDateDisplay: string;
  allocationRatePercent: number;
  lines: InvoiceFormLine[];
  subtotal: string;
  markupAmount: string;
  totalAmount: string;
  runId: string;
};
