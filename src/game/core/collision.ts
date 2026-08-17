import type { GridPoint, Footprint, ProofMap } from './types';

export function intersects(a: Footprint, b: Footprint): boolean {
  // Keep computed edge contacts (for example, 6.82 + 0.18) from becoming
  // microscopic overlaps solely because of floating-point representation.
  const epsilon =
    Number.EPSILON *
    32 *
    Math.max(
      1,
      Math.abs(a.x),
      Math.abs(a.y),
      Math.abs(a.width),
      Math.abs(a.height),
      Math.abs(b.x),
      Math.abs(b.y),
      Math.abs(b.width),
      Math.abs(b.height),
    );
  return (
    a.x < b.x + b.width - epsilon &&
    a.x + a.width > b.x + epsilon &&
    a.y < b.y + b.height - epsilon &&
    a.y + a.height > b.y + epsilon
  );
}

export function playerRect(position: GridPoint, halfExtent = 0.18): Footprint {
  return {
    id: 'player',
    x: position.x - halfExtent,
    y: position.y - halfExtent,
    width: halfExtent * 2,
    height: halfExtent * 2,
  };
}

function clampCenter(value: number, size: number, halfExtent: number): number {
  return Math.min(Math.max(value, halfExtent), size - halfExtent);
}

function resolveAxis(
  position: GridPoint,
  delta: number,
  axis: 'x' | 'y',
  map: ProofMap,
  halfExtent: number,
): GridPoint {
  const size = axis === 'x' ? map.width : map.height;
  const proposed = {
    x: position.x,
    y: position.y,
  };
  proposed[axis] = clampCenter(position[axis] + delta, size, halfExtent);

  const proposedRect = playerRect(proposed, halfExtent);
  let resolved = proposed[axis];
  if (delta > 0) {
    for (const footprint of map.footprints) {
      if (!intersects(proposedRect, footprint)) continue;
      const edge = axis === 'x' ? footprint.x - halfExtent : footprint.y - halfExtent;
      resolved = Math.min(resolved, edge);
    }
  } else if (delta < 0) {
    for (const footprint of map.footprints) {
      if (!intersects(proposedRect, footprint)) continue;
      const edge =
        axis === 'x'
          ? footprint.x + footprint.width + halfExtent
          : footprint.y + footprint.height + halfExtent;
      resolved = Math.max(resolved, edge);
    }
  }

  proposed[axis] = clampCenter(resolved, size, halfExtent);
  return proposed;
}

export function moveWithCollisions(
  position: GridPoint,
  delta: GridPoint,
  map: ProofMap,
  halfExtent = 0.18,
): GridPoint {
  let next = resolveAxis(position, delta.x, 'x', map, halfExtent);
  next = resolveAxis(next, delta.y, 'y', map, halfExtent);
  return next;
}
