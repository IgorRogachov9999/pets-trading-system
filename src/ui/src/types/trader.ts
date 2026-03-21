export interface Trader {
  id: string
  email: string
  availableCash: number
  lockedCash: number
  portfolioValue: number
}

export interface TraderPortfolio {
  trader: Trader
  inventoryCount: number
}
