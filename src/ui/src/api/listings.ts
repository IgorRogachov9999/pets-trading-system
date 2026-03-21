import type { Listing } from '../types'
import { apiFetch } from './client'

export async function getListings(): Promise<Listing[]> {
  return apiFetch<Listing[]>('/api/v1/listings')
}

export async function getListing(id: string): Promise<Listing> {
  return apiFetch<Listing>(`/api/v1/listings/${id}`)
}
