/**
 * ROUNDDOWN toward zero (Excel-compatible).
 * - unit=1: truncate to whole KRW
 * - unit=10: truncate to 10 KRW
 */
export function roundDown(value: number | bigint, unit: number = 1): bigint {
  const n = typeof value === "bigint" ? Number(value) : value;
  if (unit <= 0) throw new Error("unit must be positive");
  const sign = n < 0 ? -1 : 1;
  const abs = Math.abs(n);
  const truncated = Math.floor(abs / unit) * unit;
  return BigInt(sign * truncated);
}

export function roundDownDecimal(value: number, unit: number = 1): number {
  const sign = value < 0 ? -1 : 1;
  const abs = Math.abs(value);
  return sign * Math.floor(abs / unit) * unit;
}

export const RATE_PRECISION = 12;
export const RATE_TOTAL_TARGET = 100;
export const RATE_TOLERANCE = 0.000001; // 6 decimal places
/** 100% 초과 시 허용하는 최대 초과 비율(%) */
export const RATE_OVER_TOLERANCE = 0.01;

export function isRateTotalValid(total: number): boolean {
  return Math.abs(total - RATE_TOTAL_TARGET) < RATE_TOLERANCE;
}

/** 100%를 초과하되 초과분이 0.01% 이하인 경우 */
export function isRateOverExcessAcceptable(total: number): boolean {
  const excess = total - RATE_TOTAL_TARGET;
  return excess > RATE_TOLERANCE && excess <= RATE_OVER_TOLERANCE + 1e-12;
}

/** 엄격 검증(반기 등)에서 확정·배분 허용 여부 */
export function isRateTotalAcceptable(total: number): boolean {
  return isRateTotalValid(total) || isRateOverExcessAcceptable(total);
}

export function formatKRW(amount: bigint | number): string {
  const n = typeof amount === "bigint" ? Number(amount) : amount;
  return n.toLocaleString("ko-KR");
}

export function formatRate(rate: number | string): string {
  const n = typeof rate === "string" ? parseFloat(rate) : rate;
  return (n * 100).toFixed(6) + "%";
}

export function parseRatePercent(percent: number): number {
  return percent / 100;
}

export function sumBigInt(values: bigint[]): bigint {
  return values.reduce((a, b) => a + b, 0n);
}

export function toNumberSafe(value: bigint): number {
  return Number(value);
}

export function decimalToNumber(value: { toString(): string } | number | string): number {
  if (typeof value === "number") return value;
  return parseFloat(value.toString());
}

export function createChecksum(data: unknown): string {
  const str = JSON.stringify(data, (_, v) =>
    typeof v === "bigint" ? v.toString() : v
  );
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    const char = str.charCodeAt(i);
    hash = (hash << 5) - hash + char;
    hash |= 0;
  }
  return Math.abs(hash).toString(16).padStart(8, "0");
}
