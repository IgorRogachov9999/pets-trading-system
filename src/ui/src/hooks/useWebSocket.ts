/**
 * Stub WebSocket hook — returns null for now.
 * Real implementation will connect to the API Gateway WebSocket endpoint,
 * apply exponential backoff reconnection, and call queryClient.invalidateQueries()
 * on each of the 6 trade event types.
 */
export function useWebSocket(): null {
  return null
}
