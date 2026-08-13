export type GameLike = {
  destroy(removeCanvas: boolean): void;
};

export type GameFactory<T> = (parent: HTMLElement, dependencies: T) => GameLike;

export class GameLifecycle<T> {
  private game: GameLike | null = null;

  constructor(private readonly factory: GameFactory<T>) {}

  start(parent: HTMLElement, dependencies: T): void {
    this.stop();
    this.game = this.factory(parent, dependencies);
  }

  stop(): void {
    const game = this.game;
    this.game = null;
    game?.destroy(true);
  }
}
