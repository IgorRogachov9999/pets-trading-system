import type { Trader } from '../types'
import { apiFetch } from './client'

export interface LeaderboardEntry {
  rank: number
  trader: Trader
}

export async function getLeaderboard(): Promise<LeaderboardEntry[]> {
  return apiFetch<LeaderboardEntry[]>('/api/leaderboard')
}
