import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, waitFor } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter, Routes, Route } from 'react-router-dom'
import { MarketPage } from './MarketPage'

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function createTestQueryClient() {
  return new QueryClient({
    defaultOptions: {
      queries: {
        retry: false,
        staleTime: Infinity,
      },
    },
  })
}

interface RenderOptions {
  initialPath?: string
}

function renderMarketPage({ initialPath = '/market' }: RenderOptions = {}) {
  const queryClient = createTestQueryClient()
  return render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter initialEntries={[initialPath]}>
        <Routes>
          <Route path="/market" element={<MarketPage />} />
        </Routes>
      </MemoryRouter>
    </QueryClientProvider>,
  )
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('MarketPage', () => {
  beforeEach(() => {
    vi.restoreAllMocks()
  })

  it('shows a loading indicator while the health request is in flight', () => {
    vi.spyOn(globalThis, 'fetch').mockReturnValue(new Promise(() => undefined))

    renderMarketPage()

    expect(screen.getByText(/checking api status/i)).toBeInTheDocument()
  })

  it('renders the API message from the health endpoint', async () => {
    const message = 'Pets Trading System API is running'

    vi.spyOn(globalThis, 'fetch').mockResolvedValueOnce(
      new Response(JSON.stringify({ message }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }),
    )

    renderMarketPage()

    await waitFor(() => {
      expect(screen.getByTestId('api-message')).toHaveTextContent(message)
    })
  })

  it('shows an error message when the health endpoint returns a non-OK status', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValueOnce(
      new Response(null, { status: 503, statusText: 'Service Unavailable' }),
    )

    renderMarketPage()

    await waitFor(() => {
      expect(screen.getByRole('alert')).toHaveTextContent(/health check failed/i)
    })
  })

  it('renders MarketPage at /market route', () => {
    vi.spyOn(globalThis, 'fetch').mockReturnValue(new Promise(() => undefined))

    renderMarketPage({ initialPath: '/market' })

    expect(screen.getByRole('heading', { name: /market view/i })).toBeInTheDocument()
  })
})
