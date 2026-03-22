import type { Bid } from '../types'
import { apiFetch } from './client'

export interface PlaceBidRequest {
  listingId: string
  amount: number
}

export async function placeBid(request: PlaceBidRequest): Promise<Bid> {
  return apiFetch<Bid>('/api/v1/bids', {
    method: 'POST',
    body: JSON.stringify(request),
  })
}

export async function withdrawBid(bidId: string): Promise<void> {
  return apiFetch<void>(`/api/v1/bids/${bidId}/withdraw`, {
    method: 'POST',
  })
}
