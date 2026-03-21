import { NavLink } from 'react-router-dom'

const navLinks = [
  { to: '/market', label: 'Market' },
  { to: '/portfolio', label: 'Portfolio' },
  { to: '/analysis', label: 'Analysis' },
  { to: '/leaderboard', label: 'Leaderboard' },
]

export function Header() {
  return (
    <header className="bg-white border-b border-gray-200 shadow-sm">
      <div className="mx-auto flex max-w-7xl items-center justify-between px-4 py-3">
        <span className="text-xl font-bold text-brand-700">Pets Trading</span>
        <nav className="flex gap-6" aria-label="Main navigation">
          {navLinks.map(({ to, label }) => (
            <NavLink
              key={to}
              to={to}
              className={({ isActive }) =>
                [
                  'text-sm font-medium transition-colors',
                  isActive
                    ? 'text-brand-700 underline underline-offset-4'
                    : 'text-gray-600 hover:text-brand-700',
                ].join(' ')
              }
            >
              {label}
            </NavLink>
          ))}
        </nav>
      </div>
    </header>
  )
}
