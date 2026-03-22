import { apiFetch } from './client'

export interface HealthResponse {
  message: string;
}

export async function fetchHealth(): Promise<HealthResponse> {
  return apiFetch<HealthResponse>('/api/v1/health')
}
