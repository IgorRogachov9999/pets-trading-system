import { apiFetch } from './client'

export interface TestResponse {
  message: string;
}

export async function fetchTest(): Promise<TestResponse> {
  return apiFetch<TestResponse>('/api/v1/test')
}
