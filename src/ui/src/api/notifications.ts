import type { Notification } from '../types'
import { apiFetch } from './client'

export async function getNotifications(traderId: string): Promise<Notification[]> {
  return apiFetch<Notification[]>(`/api/traders/${traderId}/notifications`)
}
