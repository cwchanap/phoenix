export interface StageFit {
  scale: number;
  width: number;
  height: number;
  left: number;
  top: number;
}

export function fitStage(viewportWidth: number, viewportHeight: number): StageFit {
  const scale = Math.max(1, Math.floor(Math.min(viewportWidth / 640, viewportHeight / 360)));
  const width = 640 * scale;
  const height = 360 * scale;

  return {
    scale,
    width,
    height,
    left: Math.floor((viewportWidth - width) / 2),
    top: Math.floor((viewportHeight - height) / 2),
  };
}
