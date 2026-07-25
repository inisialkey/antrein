/** `ANT-YYYYMMDD-NNNN` (ADR 0038 — per-business daily sequence, display only). */
export function formatBookingCode(businessDate: string, sequence: number): string {
  return `ANT-${businessDate.replaceAll('-', '')}-${String(sequence).padStart(4, '0')}`;
}
