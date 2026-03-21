import type { Pet } from './pet'

export interface Listing {
  id: string
  petId: string
  sellerId: string
  askingPrice: number
  isActive: boolean
  pet?: Pet
  recentTradePrice?: number
  createdAt: string
}
