export type AvatarState =
  | 'sleeping'
  | 'calm'
  | 'happy'
  | 'excited'
  | 'tired'
  | 'anxious'
  | 'hungry'
  | 'frustrated'
  | 'seekingAttention'
  | 'proud'

export interface AvatarStateResult {
  state:              AvatarState
  stateReason:        string
  recommendedCopy:    string
}

export interface DogStateInput {
  energyLevel:      number  // 0–1
  hungerLevel:      number  // 0–1
  satisfaction:     number  // 0–1
  calmness:         number  // 0–1
  focusOnOwner:     number  // 0–1
  recentActivityCompleted:  boolean
  missedActivitiesCount:    number
  recentTrainingSuccess:    boolean | null
  recentBehaviorIssues:     number
  streakActive:             boolean
}

export const AvatarBehaviorService = {

  computeState(input: DogStateInput): AvatarStateResult {
    // Priority-ordered rules — first match wins
    if (input.energyLevel < 0.15) {
      return {
        state: 'sleeping',
        stateReason: 'Very low energy — resting time',
        recommendedCopy: 'Let them rest — sleep is essential for learning.',
      }
    }
    if (input.hungerLevel > 0.8) {
      return {
        state: 'hungry',
        stateReason: 'Meal time missed or overdue',
        recommendedCopy: 'Consistent feeding times build calm food habits.',
      }
    }
    if (input.recentActivityCompleted && input.satisfaction > 0.7) {
      return {
        state: 'proud',
        stateReason: 'Activity just completed successfully',
        recommendedCopy: 'Great session! Celebrate this win with calm praise.',
      }
    }
    if (input.recentTrainingSuccess === true) {
      return {
        state: 'proud',
        stateReason: 'Training session succeeded',
        recommendedCopy: 'Your dog nailed it. Short session → big progress.',
      }
    }
    if (input.calmness < 0.25 || input.recentBehaviorIssues > 2) {
      return {
        state: 'anxious',
        stateReason: 'Low calmness or multiple recent behavior events',
        recommendedCopy: 'Your dog needs to decompress. Try a calm sniff walk.',
      }
    }
    if (input.recentTrainingSuccess === false) {
      return {
        state: 'frustrated',
        stateReason: 'Recent training session failed',
        recommendedCopy: 'Step back and simplify. Short success beats long failure.',
      }
    }
    if (input.missedActivitiesCount >= 2) {
      return {
        state: 'seekingAttention',
        stateReason: 'Multiple activities missed today',
        recommendedCopy: 'Your dog is waiting. Even 10 minutes helps.',
      }
    }
    if (input.energyLevel < 0.3) {
      return {
        state: 'tired',
        stateReason: 'Low energy after activity',
        recommendedCopy: 'A tired dog is a well-exercised dog. Rest now.',
      }
    }
    if (input.energyLevel > 0.75 && input.satisfaction > 0.5) {
      return {
        state: 'excited',
        stateReason: 'High energy and satisfied',
        recommendedCopy: 'Peak energy — great moment for a walk or play session.',
      }
    }
    if (input.satisfaction > 0.65 && input.calmness > 0.5) {
      return {
        state: 'happy',
        stateReason: 'Good satisfaction and calm state',
        recommendedCopy: 'Your dog is balanced. Keep the routine going.',
      }
    }
    if (!input.streakActive || input.focusOnOwner < 0.3) {
      return {
        state: 'seekingAttention',
        stateReason: 'Low engagement or streak broken',
        recommendedCopy: '3 minutes of eye contact training builds focus fast.',
      }
    }
    return {
      state: 'calm',
      stateReason: 'Balanced state',
      recommendedCopy: 'Your dog is balanced and ready to learn.',
    }
  },
}
