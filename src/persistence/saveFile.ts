import { createValueParser } from '../game/core/parse';
import { CROP_KINDS } from '../game/core/cropDefinitions';
import { VILLAGER_IDS } from '../game/core/villagerDefinitions';
import type {
  CropCounts,
  CropKind,
  DaySummary,
  FarmTileSnapshot,
  FarmingAction,
  GameState,
  GridCell,
  InventorySnapshot,
  RelationshipState,
  ShipmentLine,
  VillagerId,
  Weather,
} from '../game/core/types';

export const SAVE_SCHEMA_VERSION = 1 as const;

export interface SaveFileV1 {
  schemaVersion: 1;
  state: GameState;
}

const FARMING_ACTIONS = ['hoe', 'seeds', 'wateringCan', 'hands'] as const;
const WEATHER_VALUES = ['sunny', 'rainy'] as const;
const SOIL_VALUES = ['untilled', 'tilled'] as const;

const { record, array, safeInteger, boolean, oneOf } = createValueParser('Invalid save');

export function createSaveFile(state: GameState): SaveFileV1 {
  return { schemaVersion: SAVE_SCHEMA_VERSION, state: structuredClone(state) };
}

export function parseSaveFile(value: unknown): SaveFileV1 {
  const file = record(value, 'save');
  const schemaVersion = safeInteger(file.schemaVersion, 'schemaVersion');
  if (schemaVersion !== SAVE_SCHEMA_VERSION) {
    throw new Error(`Invalid save: schemaVersion must be ${SAVE_SCHEMA_VERSION}`);
  }
  return { schemaVersion: SAVE_SCHEMA_VERSION, state: parseGameState(file.state) };
}

function parseGameState(value: unknown): GameState {
  const state = record(value, 'state');
  return {
    day: safeInteger(state.day, 'state.day'),
    timeMinutes: safeInteger(state.timeMinutes, 'state.timeMinutes'),
    stamina: safeInteger(state.stamina, 'state.stamina'),
    weather: oneOf(state.weather, WEATHER_VALUES, 'state.weather') as Weather,
    pendingDaySummary: parseDaySummary(state.pendingDaySummary),
    selectedAction: oneOf(
      state.selectedAction,
      FARMING_ACTIONS,
      'state.selectedAction',
    ) as FarmingAction,
    selectedSeed: oneOf(state.selectedSeed, CROP_KINDS, 'state.selectedSeed') as CropKind,
    money: safeInteger(state.money, 'state.money'),
    inventory: parseInventory(state.inventory),
    pendingShipment: parseCropCounts(state.pendingShipment, 'state.pendingShipment'),
    farmTiles: parseFarmTiles(state.farmTiles),
    relationships: parseRelationships(state.relationships),
  };
}

function parseDaySummary(value: unknown): DaySummary | null {
  if (value === null) return null;
  const summary = record(value, 'state.pendingDaySummary');
  return {
    completedDay: safeInteger(summary.completedDay, 'state.pendingDaySummary.completedDay'),
    nextDay: safeInteger(summary.nextDay, 'state.pendingDaySummary.nextDay'),
    cropsAdvanced: safeInteger(summary.cropsAdvanced, 'state.pendingDaySummary.cropsAdvanced'),
    nextWeather: oneOf(
      summary.nextWeather,
      WEATHER_VALUES,
      'state.pendingDaySummary.nextWeather',
    ) as Weather,
    staminaRestored: safeInteger(
      summary.staminaRestored,
      'state.pendingDaySummary.staminaRestored',
    ),
    shipments: parseShipmentLines(summary.shipments),
    shippingIncome: safeInteger(summary.shippingIncome, 'state.pendingDaySummary.shippingIncome'),
    moneyAfterShipping: safeInteger(
      summary.moneyAfterShipping,
      'state.pendingDaySummary.moneyAfterShipping',
    ),
  };
}

function parseShipmentLines(value: unknown): ShipmentLine[] {
  return array(value, 'state.pendingDaySummary.shipments').map((line, index) => {
    const shipment = record(line, `state.pendingDaySummary.shipments[${index}]`);
    return {
      crop: oneOf(
        shipment.crop,
        CROP_KINDS,
        `state.pendingDaySummary.shipments[${index}].crop`,
      ) as CropKind,
      quantity: safeInteger(
        shipment.quantity,
        `state.pendingDaySummary.shipments[${index}].quantity`,
      ),
      unitValue: safeInteger(
        shipment.unitValue,
        `state.pendingDaySummary.shipments[${index}].unitValue`,
      ),
      lineTotal: safeInteger(
        shipment.lineTotal,
        `state.pendingDaySummary.shipments[${index}].lineTotal`,
      ),
    };
  });
}

function parseInventory(value: unknown): InventorySnapshot {
  const inventory = record(value, 'state.inventory');
  return {
    seeds: parseCropCounts(inventory.seeds, 'state.inventory.seeds'),
    crops: parseCropCounts(inventory.crops, 'state.inventory.crops'),
  };
}

function parseCropCounts(value: unknown, context: string): CropCounts {
  const counts = record(value, context);
  const parsed = {} as CropCounts;
  for (const key of Object.keys(counts)) {
    const kind = oneOf(key, CROP_KINDS, `${context} crop`) as CropKind;
    parsed[kind] = safeInteger(counts[key], `${context}.${kind}`);
  }
  for (const kind of CROP_KINDS) {
    if (!Object.hasOwn(parsed, kind)) {
      throw new Error(`Invalid save: ${context}.${kind} is required`);
    }
  }
  return parsed;
}

function parseFarmTiles(value: unknown): FarmTileSnapshot[] {
  return array(value, 'state.farmTiles').map((value, index) => {
    const tile = record(value, `state.farmTiles[${index}]`);
    return {
      position: parseGridCell(tile.position, `state.farmTiles[${index}].position`),
      soil: oneOf(
        tile.soil,
        SOIL_VALUES,
        `state.farmTiles[${index}].soil`,
      ) as FarmTileSnapshot['soil'],
      crop: tile.crop === null ? null : parseCropSnapshot(tile.crop, index),
    };
  });
}

function parseGridCell(value: unknown, context: string): GridCell {
  const position = record(value, context);
  return {
    x: safeInteger(position.x, `${context}.x`),
    y: safeInteger(position.y, `${context}.y`),
  };
}

function parseCropSnapshot(
  value: unknown,
  tileIndex: number,
): NonNullable<FarmTileSnapshot['crop']> {
  const crop = record(value, `state.farmTiles[${tileIndex}].crop`);
  return {
    kind: oneOf(crop.kind, CROP_KINDS, `state.farmTiles[${tileIndex}].crop.kind`) as CropKind,
    growth: safeInteger(crop.growth, `state.farmTiles[${tileIndex}].crop.growth`),
    wateredToday: boolean(crop.wateredToday, `state.farmTiles[${tileIndex}].crop.wateredToday`),
  };
}

function parseRelationships(value: unknown): Record<VillagerId, RelationshipState> {
  const relationships = record(value, 'state.relationships');
  const parsed = {} as Record<VillagerId, RelationshipState>;
  for (const key of Object.keys(relationships)) {
    const id = oneOf(key, VILLAGER_IDS, 'state.relationships villager') as VillagerId;
    parsed[id] = parseRelationship(relationships[id], `state.relationships.${id}`);
  }
  for (const id of VILLAGER_IDS) {
    if (!Object.hasOwn(parsed, id)) {
      throw new Error(`Invalid save: state.relationships.${id} is required`);
    }
  }
  return parsed;
}

function parseRelationship(value: unknown, context: string): RelationshipState {
  const relationship = record(value, context);
  return {
    points: safeInteger(relationship.points, `${context}.points`),
    talkedToday: boolean(relationship.talkedToday, `${context}.talkedToday`),
    giftedToday: boolean(relationship.giftedToday, `${context}.giftedToday`),
    closeFriendDialogueSeen: boolean(
      relationship.closeFriendDialogueSeen,
      `${context}.closeFriendDialogueSeen`,
    ),
  };
}
