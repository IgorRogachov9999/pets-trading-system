export type BadgeStatus = 'active' | 'sold' | 'expired'

interface BadgeProps {
  status: BadgeStatus
}

const statusClasses: Record<BadgeStatus, string> = {
  active: 'bg-green-100 text-green-800',
  sold: 'bg-gray-100 text-gray-600',
  expired: 'bg-red-100 text-red-700',
}

export function Badge({ status }: BadgeProps) {
  return (
    <span
      className={[
        'inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium capitalize',
        statusClasses[status],
      ].join(' ')}
    >
      {status}
    </span>
  )
}
