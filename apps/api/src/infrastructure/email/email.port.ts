export interface PasswordResetEmailInput {
  to: string;
  name: string;
  token: string;
  expiresInMinutes: number;
}

export interface PasswordChangedEmailInput {
  to: string;
  name: string;
}

/** Provider port (ADR 0037) — SMTP/Mailpit locally, real ESP later. */
export abstract class EmailPort {
  abstract sendPasswordReset(input: PasswordResetEmailInput): Promise<void>;
  abstract sendPasswordChanged(input: PasswordChangedEmailInput): Promise<void>;
}
