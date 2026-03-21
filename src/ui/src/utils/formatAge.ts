/**
 * Formats a pet's age (in fractional years) as a human-readable string.
 * e.g. formatAge(0.5) → '6 months'
 *      formatAge(1)   → '1 year'
 *      formatAge(2.5) → '2.5 years'
 */
export function formatAge(ageYears: number): string {
  if (ageYears < 1) {
    const months = Math.round(ageYears * 12)
    return `${months} ${months === 1 ? 'month' : 'months'}`
  }
  const rounded = Math.round(ageYears * 10) / 10
  return `${rounded} ${rounded === 1 ? 'year' : 'years'}`
}
