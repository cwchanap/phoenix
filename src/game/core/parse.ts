export function createValueParser(prefix: string) {
  const fail = (reason: string): never => {
    throw new Error(`${prefix}: ${reason}`);
  };

  const record = (value: unknown, context: string): Record<string, unknown> => {
    if (typeof value !== 'object' || value === null || Array.isArray(value)) {
      fail(`${context} must be an object`);
    }
    return value as Record<string, unknown>;
  };

  const array = (value: unknown, context: string): unknown[] => {
    if (!Array.isArray(value)) fail(`${context} must be an array`);
    return value as unknown[];
  };

  const string = (value: unknown, context: string): string => {
    if (typeof value !== 'string') fail(`${context} must be a string`);
    return value as string;
  };

  const number = (value: unknown, context: string): number => {
    if (typeof value !== 'number' || !Number.isFinite(value)) {
      fail(`${context} must be a finite number`);
    }
    return value as number;
  };

  const integer = (value: unknown, context: string): number => {
    const result = number(value, context);
    if (!Number.isInteger(result)) fail(`${context} must be an integer`);
    return result;
  };

  const safeInteger = (value: unknown, context: string): number => {
    const result = number(value, context);
    if (!Number.isSafeInteger(result)) fail(`${context} must be a safe integer`);
    return result;
  };

  const boolean = (value: unknown, context: string): boolean => {
    if (typeof value !== 'boolean') fail(`${context} must be a boolean`);
    return value as boolean;
  };

  const oneOf = <T extends string>(value: unknown, allowed: readonly T[], context: string): T => {
    const result = string(value, context);
    if (!allowed.includes(result as T)) {
      fail(`${context} must be one of ${allowed.join(', ')}`);
    }
    return result as T;
  };

  return { fail, record, array, string, number, integer, safeInteger, boolean, oneOf };
}
