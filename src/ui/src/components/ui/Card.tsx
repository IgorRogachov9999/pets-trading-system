import type { HTMLAttributes, ReactNode } from 'react'

interface CardProps extends HTMLAttributes<HTMLDivElement> {
  children: ReactNode
}

export function Card({ children, className = '', ...rest }: CardProps) {
  return (
    <div
      className={['bg-white rounded-2xl shadow-md p-6', className].join(' ')}
      {...rest}
    >
      {children}
    </div>
  )
}
