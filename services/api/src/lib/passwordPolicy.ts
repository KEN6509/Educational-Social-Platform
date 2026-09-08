export const PASSWORD_POLICY_MESSAGE =
  'Use at least 12 characters with uppercase, lowercase, a number, and a symbol such as . or _.';

export function isStrongPassword(password: string): boolean {
  return (
    password.length >= 12 &&
    /[A-Z]/.test(password) &&
    /[a-z]/.test(password) &&
    /[0-9]/.test(password) &&
    /[^A-Za-z0-9\s]/.test(password)
  );
}
