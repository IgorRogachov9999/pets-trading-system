import type { Pet } from '../types'
import { apiFetch } from './client'

export interface SupplyItem {
  dictionaryId: number
  breed: string
  type: 'Dog' | 'Cat' | 'Bird' | 'Fish'
  basePrice: number
  available: number
}

export async function getSupply(): Promise<SupplyItem[]> {
  return apiFetch<SupplyItem[]>('/api/v1/supply')
}

export async function purchasePet(dictionaryId: number): Promise<Pet> {
  return apiFetch<Pet>('/api/v1/supply/purchase', {
    method: 'POST',
    body: JSON.stringify({ dictionaryId }),
  })
}
