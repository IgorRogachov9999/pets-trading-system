import { useQuery } from '@tanstack/react-query'
import { fetchTest } from '../../api/test'
import type { TestResponse } from '../../api/test'

export function MarketPage() {
  const { data, isLoading, isError, error } = useQuery<TestResponse, Error>({
    queryKey: ['test'],
    queryFn: fetchTest,
  })

  return (
    <section aria-labelledby="market-heading">
      <h1 id="market-heading">Market View</h1>

      {isLoading && (
        <p className="text-gray-500 animate-pulse">Checking API status...</p>
      )}

      {isError && (
        <p className="text-red-600" role="alert">
          Error: {error.message}
        </p>
      )}

      {data && (
        <p className="text-green-700 font-medium" data-testid="api-message">
          {data.message}
        </p>
      )}
    </section>
  )
}
