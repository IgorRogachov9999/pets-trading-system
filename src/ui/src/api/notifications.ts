import type { Notification } from '../types'
import { apiFetch } from './client'

export async function getNotifications(traderId: string): Promise<Notification[]> {
  return apiFetch<Notification[]>(`/api/v1/traders/${traderId}/notifications`)
}
