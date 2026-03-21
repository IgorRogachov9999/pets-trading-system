export type BidStatus = 'active' | 'accepted' | 'rejected' | 'withdrawn' | 'outbid'

export interface Bid {
  id: string
  listingId: string
  bidderId: string
  amount: number
  status: BidStatus
  createdAt: string
}
