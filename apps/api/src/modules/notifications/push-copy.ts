export type QueuePushKind = 'checked_in' | 'called';

export interface QueuePushCopy {
  notificationType: string;
  title: string;
  body: string;
}

/**
 * Customer-facing push/in-app copy (Bahasa Indonesia — product language).
 * Pure so the wording is unit-testable without any infrastructure.
 */
export function queuePushCopy(kind: QueuePushKind, displayNumber: string): QueuePushCopy {
  if (kind === 'checked_in') {
    return {
      notificationType: 'queue_checked_in',
      title: 'Check-in berhasil',
      body: `Nomor antrean Anda ${displayNumber}. Pantau giliran Anda di aplikasi.`,
    };
  }
  return {
    notificationType: 'queue_called',
    title: 'Giliran Anda tiba',
    body: `Nomor ${displayNumber} sedang dipanggil. Silakan menuju outlet.`,
  };
}
