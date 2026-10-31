import { readFileSync } from 'node:fs'

const reportPath = process.argv[2] ?? 'test-results/e2e-report.json'

try {
  const report = JSON.parse(readFileSync(reportPath, 'utf8')) as {
    stats?: { expected?: unknown; unexpected?: unknown; flaky?: unknown; skipped?: unknown }
  }
  const expected = report.stats?.expected
  const unexpected = report.stats?.unexpected
  const flaky = report.stats?.flaky
  const skipped = report.stats?.skipped

  if (typeof expected !== 'number' || !Number.isInteger(expected)
    || typeof unexpected !== 'number' || !Number.isInteger(unexpected)
    || typeof flaky !== 'number' || !Number.isInteger(flaky)
    || typeof skipped !== 'number' || !Number.isInteger(skipped)) {
    throw new Error('the JSON report is missing integer execution stats')
  }

  if (Number(skipped) > 0) {
    throw new Error(`${skipped} browser test(s) were skipped`)
  }

  const executed = expected + unexpected + flaky

  if (executed < 1) {
    throw new Error('no browser tests executed')
  }

  console.log(`Playwright report is valid: ${executed} test(s) executed, none skipped.`)
} catch (error) {
  const message = error instanceof Error ? error.message : 'could not read the Playwright report'
  console.error(`Playwright report check failed: ${message}`)
  process.exitCode = 1
}
