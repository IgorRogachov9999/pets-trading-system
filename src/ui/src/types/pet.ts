export interface Pet {
  id: string
  dictionaryId: number
  ownerId: string
  breed: string
  type: 'Dog' | 'Cat' | 'Bird' | 'Fish'
  age: number
  health: number
  desirability: number
  intrinsicValue: number
  isExpired: boolean
  createdAt: string
}

export interface PetDictionary {
  id: number
  type: 'Dog' | 'Cat' | 'Bird' | 'Fish'
  breed: string
  lifespan: number
  desirability: number
  maintenance: number
  basePrice: number
}
