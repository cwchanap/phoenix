import { describe, expect, test } from 'bun:test';
import { assertCoverage, summarizeLcov } from '../../tools/check-coverage';

const passingLcov = [
  'TN:',
  'SF:src/game/a.ts',
  'FNF:10',
  'FNH:9',
  'LF:100',
  'LH:90',
  'BRF:0',
  'BRH:0',
  'end_of_record',
].join('\n');

describe('check-coverage', () => {
  test('accepts exactly 90 percent measurable line and function coverage', () => {
    expect(summarizeLcov(passingLcov)).toEqual({
      lines: { covered: 90, total: 100, percentage: 90 },
      functions: { covered: 9, total: 10, percentage: 90 },
    });
    expect(assertCoverage(passingLcov)).toEqual(summarizeLcov(passingLcov));
  });

  test('combines totals across source records before deciding the threshold', () => {
    const report = `${passingLcov}\nSF:src/game/b.ts\nFNF:10\nFNH:9\nLF:100\nLH:90\nend_of_record`;
    expect(summarizeLcov(report).lines).toEqual({ covered: 180, total: 200, percentage: 90 });
    expect(summarizeLcov(report).functions).toEqual({ covered: 18, total: 20, percentage: 90 });
  });

  test('rejects either measurable metric below 90 percent', () => {
    expect(() => assertCoverage(passingLcov.replace('LH:90', 'LH:89'))).toThrow(/line coverage/i);
    expect(() => assertCoverage(passingLcov.replace('FNH:9', 'FNH:8'))).toThrow(
      /function coverage/i,
    );
  });

  test.each([
    ['missing function total', passingLcov.replace('FNF:10\n', '')],
    ['zero line denominator', passingLcov.replace('LF:100', 'LF:0').replace('LH:90', 'LH:0')],
    ['malformed summary', passingLcov.replace('FNH:9', 'FNH:not-a-number')],
    ['covered count above its denominator', passingLcov.replace('FNH:9', 'FNH:11')],
  ])('rejects %s', (_name, report) => {
    expect(() => assertCoverage(report)).toThrow();
  });
});
