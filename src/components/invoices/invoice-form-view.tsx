import { INVOICE_FOOTER_NOTE, type InvoiceFormData } from "@/lib/invoice-form-config";
import { formatAmount } from "@/lib/utils";

export function InvoiceFormView({ data }: { data: InvoiceFormData }) {
  const isOverseas = data.invoiceType === "OVERSEAS";
  const billTo = isOverseas
    ? data.billToNameEn ?? data.billToName
    : data.billToName;

  return (
    <div className="invoice-form bg-white text-navy-900 text-sm leading-none">
      <h2 className="text-center text-lg font-bold tracking-tight border border-navy-300 py-3.5 mb-4 bg-navy-50 leading-none">
        {data.title}
      </h2>

      <table className="w-full border-collapse mb-4 text-sm">
        <tbody>
          <FormMetaRow
            label={isOverseas ? "From" : "청구자"}
            value={data.biller.name}
          />
          <FormMetaRow
            label={isOverseas ? "Address" : "주  소"}
            value={data.biller.address}
          />
          <FormMetaRow
            label={isOverseas ? "Tel" : "연락처"}
            value={data.biller.phone}
          />
          <tr>
            <td colSpan={2} className="h-2" />
          </tr>
          <FormMetaRow
            label={isOverseas ? "Bill To" : "청구대상"}
            value={billTo}
          />
          <FormMetaRow
            label={isOverseas ? "Period" : "청구기간"}
            value={data.periodDisplay}
          />
          <FormMetaRow
            label={isOverseas ? "Date" : "청구일자"}
            value={data.issueDateDisplay}
          />
          <FormMetaRow
            label={isOverseas ? "Rate" : "배분비율"}
            value={`${data.allocationRatePercent.toFixed(6)}%`}
          />
        </tbody>
      </table>

      <table className="w-full border-collapse border border-navy-400 text-sm">
        <thead>
          <tr className="bg-navy-100">
            <th className="border border-navy-400 px-2 py-2.5 w-12 text-center font-semibold align-middle">
              No.
            </th>
            <th className="border border-navy-400 px-2 py-2.5 w-24 text-center font-semibold align-middle">
              {isOverseas ? "Category" : "구분"}
            </th>
            <th className="border border-navy-400 px-2 py-2.5 text-center font-semibold align-middle">
              {isOverseas ? "Description" : "계정과목"}
            </th>
            <th className="border border-navy-400 px-2 py-2.5 w-32 text-center font-semibold align-middle">
              {isOverseas ? "Amount (KRW)" : "금액(원)"}
            </th>
          </tr>
        </thead>
        <tbody>
          {data.lines.map((line) => (
            <tr key={line.lineNumber} className="hover:bg-navy-50/50">
              <td className="border border-navy-300 px-2 py-2.5 text-center align-middle">
                {line.lineNumber}
              </td>
              <td className="border border-navy-300 px-2 py-2.5 text-center align-middle">
                {line.category}
              </td>
              <td className="border border-navy-300 px-2 py-2.5 align-middle">
                {line.accountName}
              </td>
              <td className="border border-navy-300 px-2 py-2.5 text-right font-mono tabular-nums align-middle">
                {formatAmount(line.amount)}
              </td>
            </tr>
          ))}
          <tr className="bg-navy-50 font-semibold">
            <td colSpan={3} className="border border-navy-400 px-2 py-2.5 text-right align-middle">
              {isOverseas ? "Subtotal" : "배분 비용 소계"}
            </td>
            <td className="border border-navy-400 px-2 py-2.5 text-right font-mono tabular-nums align-middle">
              {formatAmount(data.subtotal)}
            </td>
          </tr>
          {BigInt(data.markupAmount) > 0n && (
            <tr className="bg-navy-50 font-semibold">
              <td colSpan={3} className="border border-navy-400 px-2 py-2.5 text-right align-middle">
                Mark-up (5%)
              </td>
              <td className="border border-navy-400 px-2 py-2.5 text-right font-mono tabular-nums align-middle">
                {formatAmount(data.markupAmount)}
              </td>
            </tr>
          )}
          <tr className="bg-navy-100 font-bold">
            <td colSpan={3} className="border border-navy-400 px-2 py-2.5 text-right align-middle">
              {isOverseas ? "Total" : "총 청구금액"}
            </td>
            <td className="border border-navy-400 px-2 py-2.5 text-right font-mono tabular-nums text-base align-middle">
              {formatAmount(data.totalAmount)}
            </td>
          </tr>
        </tbody>
      </table>

      {!isOverseas && (
        <p className="mt-4 text-xs text-navy-600">{INVOICE_FOOTER_NOTE}</p>
      )}

      {data.invoiceNumber && (
        <p className="mt-2 text-xs text-navy-500 font-mono">
          {isOverseas ? "Invoice No." : "청구번호"}: {data.invoiceNumber}
        </p>
      )}
    </div>
  );
}

function FormMetaRow({ label, value }: { label: string; value: string }) {
  return (
    <tr>
      <th className="border border-navy-300 bg-navy-50 px-3 py-2.5 text-left font-medium w-28 align-middle leading-none">
        {label}
      </th>
      <td className="border border-navy-300 px-3 py-2.5 align-middle leading-none">
        {value}
      </td>
    </tr>
  );
}
