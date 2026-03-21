/**
 * Formats a number as a USD currency string with 2 decimal places.
 * e.g. formatCurrency(1234.5) → '$1,234.50'
 */
export function formatCurrency(amount: number): string {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(amount)
}
