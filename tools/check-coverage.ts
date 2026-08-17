import { join } from 'node:path';

export interface CoverageMetric {
  covered: number;
  total: number;
  percentage: number;
}

export interface CoverageSummary {
  lines: CoverageMetric;
  functions: CoverageMetric;
}

function parseNonnegativeInteger(field: string, value: string): number {
  if (!/^\d+$/.test(value)) throw new Error(`Invalid ${field} value: ${value}`);
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed)) throw new Error(`Invalid ${field} value: ${value}`);
  return parsed;
}

function summarizeMetric(
  lcov: string,
  name: 'line' | 'function',
  coveredField: string,
  totalField: string,
): CoverageMetric {
  let covered = 0;
  let total = 0;
  let coveredSeen = false;
  let totalSeen = false;

  for (const line of lcov.split(/\r?\n/)) {
    if (line.startsWith(`${coveredField}:`)) {
      covered += parseNonnegativeInteger(coveredField, line.slice(coveredField.length + 1));
      coveredSeen = true;
    }
    if (line.startsWith(`${totalField}:`)) {
      total += parseNonnegativeInteger(totalField, line.slice(totalField.length + 1));
      totalSeen = true;
    }
  }

  if (!coveredSeen || !totalSeen || total === 0 || covered > total) {
    throw new Error(`LCOV has no measurable ${name} coverage`);
  }

  return { covered, total, percentage: (covered / total) * 100 };
}

export function summarizeLcov(lcov: string): CoverageSummary {
  return {
    lines: summarizeMetric(lcov, 'line', 'LH', 'LF'),
    functions: summarizeMetric(lcov, 'function', 'FNH', 'FNF'),
  };
}

export function assertCoverage(lcov: string, threshold = 90): CoverageSummary {
  const summary = summarizeLcov(lcov);
  for (const [name, metric] of Object.entries(summary)) {
    if (metric.percentage < threshold) {
      throw new Error(
        `${name.slice(0, -1)} coverage ${metric.percentage.toFixed(2)}% is below required ${threshold.toFixed(2)}%`,
      );
    }
  }
  return summary;
}

if (import.meta.main) {
  const coveragePath = join(process.cwd(), 'coverage', 'lcov.info');
  const report = Bun.file(coveragePath);
  if (!(await report.exists())) throw new Error(`Coverage report not found: ${coveragePath}`);
  const summary = assertCoverage(await report.text());
  console.log(
    `Coverage gate passed: lines ${summary.lines.percentage.toFixed(2)}%, functions ${summary.functions.percentage.toFixed(2)}%`,
  );
}
