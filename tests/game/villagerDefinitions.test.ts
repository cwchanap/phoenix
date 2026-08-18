import { describe, expect, test } from 'bun:test';
import {
  FAVOURITE_GIFT_BONUS,
  GIFT_POINTS,
  RELATIONSHIP_THRESHOLDS,
  TALK_POINTS,
  VILLAGER_DEFINITIONS,
  VILLAGER_IDS,
  closeFriendDialogueLines,
  dialogueLines,
  relationshipLevel,
} from '../../src/game/core/villagerDefinitions';
import type { RelationshipLevel, VillagerId } from '../../src/game/core/types';

const levels: RelationshipLevel[] = ['stranger', 'friend', 'closeFriend'];

const expectedVillagers = {
  shopkeeper: { displayName: 'Mira', favouriteCrop: 'potato' },
  farmer: { displayName: 'Rowan', favouriteCrop: 'pumpkin' },
  resident: { displayName: 'June', favouriteCrop: 'turnip' },
} as const satisfies Record<VillagerId, { displayName: string; favouriteCrop: string }>;

const expectedDialogue = {
  shopkeeper: {
    stranger: 'The seed counter is open whenever you need it.',
    friend: 'Your fields are starting to look dependable.',
    closeFriend: 'You have made this little farm part of the village.',
  },
  farmer: {
    stranger: 'Watered soil tells you what tomorrow will bring.',
    friend: 'Your rows are getting cleaner every day.',
    closeFriend: 'I would trust you with a field of my own.',
  },
  resident: {
    stranger: 'It is quieter here than the road makes it look.',
    friend: 'I keep seeing you around. I like that.',
    closeFriend: 'The village feels more like home with you here.',
  },
} as const satisfies Record<VillagerId, Record<RelationshipLevel, string>>;

const expectedCloseFriendSequences = {
  shopkeeper: [
    'You kept showing up, even on the slow days.',
    'The harvest market will feel different with you there.',
  ],
  farmer: [
    'I noticed when the farm stopped looking neglected.',
    'You earned that change one ordinary day at a time.',
  ],
  resident: [
    'You came here as the new farmer, but that is not how I think of you now.',
    'You are one of us.',
  ],
} as const satisfies Record<VillagerId, readonly [string, string]>;

const expectedGiftDialogue = {
  shopkeeper: {
    normal: 'A useful harvest. Thank you.',
    favourite: 'Potatoes? You remembered.',
  },
  farmer: {
    normal: 'Good produce. I can use this.',
    favourite: 'A pumpkin this good is hard to ignore.',
  },
  resident: {
    normal: 'That is kind of you.',
    favourite: 'Turnips are my favourite. Perfect choice.',
  },
} as const satisfies Record<VillagerId, { normal: string; favourite: string }>;

describe('villager definitions', () => {
  test('keeps the exact villager order', () => {
    expect(VILLAGER_IDS).toEqual(['shopkeeper', 'farmer', 'resident']);
  });

  test('contains the exact names and favourite crops', () => {
    for (const id of VILLAGER_IDS) {
      expect(VILLAGER_DEFINITIONS[id].displayName).toBe(expectedVillagers[id].displayName);
      expect(VILLAGER_DEFINITIONS[id].favouriteCrop).toBe(expectedVillagers[id].favouriteCrop);
    }
  });

  test('uses the exact relationship gains and thresholds', () => {
    expect(TALK_POINTS).toBe(1);
    expect(GIFT_POINTS).toBe(3);
    expect(FAVOURITE_GIFT_BONUS).toBe(2);
    expect(RELATIONSHIP_THRESHOLDS).toEqual({ stranger: 0, friend: 12, closeFriend: 18 });
  });

  test.each([
    [0, 'stranger'],
    [11, 'stranger'],
    [12, 'friend'],
    [17, 'friend'],
    [18, 'closeFriend'],
    [Number.MAX_SAFE_INTEGER, 'closeFriend'],
  ] as const)('maps %i relationship points to %s', (points, level) => {
    expect(relationshipLevel(points)).toBe(level);
  });

  test.each([-1, 1.5, Number.NaN, Number.POSITIVE_INFINITY, Number.MAX_SAFE_INTEGER + 1])(
    'rejects invalid relationship points %p',
    (points) => {
      expect(() => relationshipLevel(points)).toThrow();
    },
  );

  test('returns the exact normal dialogue for every villager and level', () => {
    for (const id of VILLAGER_IDS) {
      for (const level of levels) {
        expect(dialogueLines(id, level)).toEqual([expectedDialogue[id][level]]);
      }
    }
  });

  test('returns the exact two-line Close Friend sequence for every villager', () => {
    for (const id of VILLAGER_IDS) {
      expect(closeFriendDialogueLines(id)).toEqual([...expectedCloseFriendSequences[id]]);
    }
  });

  test('contains the exact normal and favourite gift responses', () => {
    for (const id of VILLAGER_IDS) {
      expect(VILLAGER_DEFINITIONS[id].normalGift).toBe(expectedGiftDialogue[id].normal);
      expect(VILLAGER_DEFINITIONS[id].favouriteGift).toBe(expectedGiftDialogue[id].favourite);
    }
  });

  test('returns fresh dialogue arrays', () => {
    const firstNormal = dialogueLines('shopkeeper', 'stranger');
    firstNormal[0] = 'changed';
    expect(dialogueLines('shopkeeper', 'stranger')).toEqual([expectedDialogue.shopkeeper.stranger]);

    const firstSequence = closeFriendDialogueLines('resident');
    firstSequence.pop();
    expect(closeFriendDialogueLines('resident')).toEqual([
      ...expectedCloseFriendSequences.resident,
    ]);
  });

  test('rejects invalid helper identifiers', () => {
    expect(() => dialogueLines('unknown' as VillagerId, 'stranger')).toThrow();
    expect(() => closeFriendDialogueLines('unknown' as VillagerId)).toThrow();
  });
});
