import type { Trader, Pet } from '../types'
import { apiFetch } from './client'

export async function getPortfolio(traderId: string): Promise<Trader> {
  return apiFetch<Trader>(`/api/v1/traders/${traderId}/portfolio`)
}

export async function getInventory(traderId: string): Promise<Pet[]> {
  return apiFetch<Pet[]>(`/api/v1/traders/${traderId}/inventory`)
}
