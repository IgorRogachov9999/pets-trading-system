import type { Trade } from '../types'
import { apiFetch } from './client'

export async function getTrades(): Promise<Trade[]> {
  return apiFetch<Trade[]>('/api/trades')
}
