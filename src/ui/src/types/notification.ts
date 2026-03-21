export type NotificationEventType =
  | 'bid_received'
  | 'bid_accepted'
  | 'bid_rejected'
  | 'bid_withdrawn'
  | 'outbid'
  | 'trade_completed'
  | 'listing_withdrawn'

export interface Notification {
  id: string
  traderId: string
  eventType: NotificationEventType
  petBreed: string
  amount: number
  counterpartyEmail: string
  message: string
  createdAt: string
}
