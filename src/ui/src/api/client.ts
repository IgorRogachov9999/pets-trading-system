const BASE_URL = import.meta.env.VITE_API_BASE_URL ?? ''

export class ApiError extends Error {
  constructor(
    public readonly status: number,
    message: string,
  ) {
    super(message)
    this.name = 'ApiError'
  }
}

export interface ApiFetchOptions extends Omit<RequestInit, 'headers'> {
  /** Optional Cognito ID token — attached as `Authorization: Bearer <token>`. */
  token?: string
  headers?: HeadersInit
}

/**
 * Base fetch wrapper. Prepends VITE_API_BASE_URL, attaches an optional Bearer
 * token, and throws ApiError on non-2xx responses.
 */
export async function apiFetch<T>(
  path: string,
  options: ApiFetchOptions = {},
): Promise<T> {
  const { token, headers: extraHeaders, ...fetchOptions } = options

  const headers = new Headers(extraHeaders)
  headers.set('Content-Type', 'application/json')
  if (token !== undefined) {
    headers.set('Authorization', `Bearer ${token}`)
  }

  const res = await fetch(`${BASE_URL}${path}`, {
    ...fetchOptions,
    headers,
  })

  if (!res.ok) {
    throw new ApiError(res.status, `${res.status} ${res.statusText}`)
  }

  // 204 No Content — return undefined cast to T
  if (res.status === 204) {
    return undefined as unknown as T
  }

  return res.json() as Promise<T>
}
