import { describe, it, expect } from 'vitest'
import { formatCurrency } from './formatCurrency'

describe('formatCurrency', () => {
  it('formats a decimal amount with thousands separator and 2 decimal places', () => {
    expect(formatCurrency(1234.5)).toBe('$1,234.50')
  })

  it('formats zero as $0.00', () => {
    expect(formatCurrency(0)).toBe('$0.00')
  })

  it('formats a whole number with .00 suffix', () => {
    expect(formatCurrency(100)).toBe('$100.00')
  })

  it('formats a large amount with comma separators', () => {
    expect(formatCurrency(1000000)).toBe('$1,000,000.00')
  })
})
