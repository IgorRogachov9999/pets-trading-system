import { createBrowserRouter, Navigate } from 'react-router-dom'
import { AppShell } from '../components/layout'
import { LoginPage, RegisterPage } from '../features/auth'
import { MarketPage } from '../features/market'
import { PortfolioPage } from '../features/portfolio'
import { AnalysisPage } from '../features/analysis'
import { LeaderboardPage } from '../features/leaderboard'

export const router = createBrowserRouter([
  {
    path: '/',
    element: <AppShell />,
    children: [
      { index: true, element: <Navigate to="/market" replace /> },
      { path: 'market', element: <MarketPage /> },
      { path: 'portfolio', element: <PortfolioPage /> },
      { path: 'analysis', element: <AnalysisPage /> },
      { path: 'leaderboard', element: <LeaderboardPage /> },
    ],
  },
  { path: '/login', element: <LoginPage /> },
  { path: '/register', element: <RegisterPage /> },
])
