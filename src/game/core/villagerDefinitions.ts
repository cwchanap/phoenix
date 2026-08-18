import type { CropKind, RelationshipLevel, VillagerId } from './types';

export interface VillagerDefinition {
  readonly displayName: string;
  readonly favouriteCrop: CropKind;
  readonly dialogue: Readonly<Record<RelationshipLevel, string>>;
  readonly closeFriendDialogue: readonly [string, string];
  readonly normalGift: string;
  readonly favouriteGift: string;
}

export const VILLAGER_IDS = [
  'shopkeeper',
  'farmer',
  'resident',
] as const satisfies readonly VillagerId[];

export const VILLAGER_DEFINITIONS = {
  shopkeeper: {
    displayName: 'Mira',
    favouriteCrop: 'potato',
    dialogue: {
      stranger: 'The seed counter is open whenever you need it.',
      friend: 'Your fields are starting to look dependable.',
      closeFriend: 'You have made this little farm part of the village.',
    },
    closeFriendDialogue: [
      'You kept showing up, even on the slow days.',
      'The harvest market will feel different with you there.',
    ],
    normalGift: 'A useful harvest. Thank you.',
    favouriteGift: 'Potatoes? You remembered.',
  },
  farmer: {
    displayName: 'Rowan',
    favouriteCrop: 'pumpkin',
    dialogue: {
      stranger: 'Watered soil tells you what tomorrow will bring.',
      friend: 'Your rows are getting cleaner every day.',
      closeFriend: 'I would trust you with a field of my own.',
    },
    closeFriendDialogue: [
      'I noticed when the farm stopped looking neglected.',
      'You earned that change one ordinary day at a time.',
    ],
    normalGift: 'Good produce. I can use this.',
    favouriteGift: 'A pumpkin this good is hard to ignore.',
  },
  resident: {
    displayName: 'June',
    favouriteCrop: 'turnip',
    dialogue: {
      stranger: 'It is quieter here than the road makes it look.',
      friend: 'I keep seeing you around. I like that.',
      closeFriend: 'The village feels more like home with you here.',
    },
    closeFriendDialogue: [
      'You came here as the new farmer, but that is not how I think of you now.',
      'You are one of us.',
    ],
    normalGift: 'That is kind of you.',
    favouriteGift: 'Turnips are my favourite. Perfect choice.',
  },
} as const satisfies Readonly<Record<VillagerId, VillagerDefinition>>;

export const RELATIONSHIP_THRESHOLDS = {
  stranger: 0,
  friend: 12,
  closeFriend: 18,
} as const satisfies Readonly<Record<RelationshipLevel, number>>;

export const TALK_POINTS = 1;
export const GIFT_POINTS = 3;
export const FAVOURITE_GIFT_BONUS = 2;

function villagerDefinition(id: VillagerId): VillagerDefinition {
  if (!Object.hasOwn(VILLAGER_DEFINITIONS, id)) {
    throw new RangeError(`unknown villager id: ${id}`);
  }
  return VILLAGER_DEFINITIONS[id];
}

function assertRelationshipLevel(level: RelationshipLevel): void {
  if (!Object.hasOwn(RELATIONSHIP_THRESHOLDS, level)) {
    throw new RangeError(`unknown relationship level: ${level}`);
  }
}

export function relationshipLevel(points: number): RelationshipLevel {
  if (!Number.isSafeInteger(points) || points < 0) {
    throw new RangeError('relationship points must be a nonnegative safe integer');
  }
  if (points >= RELATIONSHIP_THRESHOLDS.closeFriend) return 'closeFriend';
  if (points >= RELATIONSHIP_THRESHOLDS.friend) return 'friend';
  return 'stranger';
}

export function dialogueLines(id: VillagerId, level: RelationshipLevel): string[] {
  assertRelationshipLevel(level);
  return [villagerDefinition(id).dialogue[level]];
}

export function closeFriendDialogueLines(id: VillagerId): string[] {
  return [...villagerDefinition(id).closeFriendDialogue];
}
