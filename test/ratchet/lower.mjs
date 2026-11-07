// Runs the ratchet suite and rewrites test/ratchet/baseline.json to what it measured, only downwards:
// if a counter went up or a recorded run is gone, it changes nothing. New runs are added; each test
// file writes the runs it owns into RATCHET_OUT. Usage: node test/ratchet/lower.mjs [--no-build]
// [--admit=<counter>]: a counter that is new to the suite is recorded as measured, once, the first time.
// It runs the slow parts of bench/classics too (RATCHET_SLOW), so that every recorded run is measured.
import { execFileSync } from "node:child_process";
import { existsSync, mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const baselinePath = "test/ratchet/baseline.json";
const admitted = process.argv.filter((arg) => arg.startsWith("--admit=")).map((arg) => arg.slice("--admit=".length));
const measuredDirectory = mkdtempSync(join(tmpdir(), "ratchet-"));

if (!process.argv.includes("--no-build")) {
  execFileSync("opam", ["exec", "--", "dune", "build", "--root", ".", "@runtest-js"], { stdio: "inherit" });
}
try {
  execFileSync("npx", ["vitest", "run", "_build/default/test/ratchet/"], {
    stdio: "inherit",
    env: { ...process.env, RATCHET_OUT: measuredDirectory, RATCHET_SLOW: "1" },
  });
} catch {}
const parts = [
  "programs.json",
  "table.json",
  "meltea.json",
  "bigpage.json",
  "served.json",
  ...[1, 2, 3, 4].map((part) => `classics quick ${part}.json`),
  ...[1, 2, 3, 4, 5, 6, 7, 8].map((part) => `classics slow ${part}.json`),
];
const missing = parts.filter((part) => !existsSync(join(measuredDirectory, part)));
if (missing.length > 0) {
  console.error(`The ratchet suite did not report ${missing.join(", ")}; is it built?`);
  process.exit(1);
}
const measured = Object.assign(
  {},
  ...readdirSync(measuredDirectory).map((part) => JSON.parse(readFileSync(join(measuredDirectory, part), "utf8"))),
);
rmSync(measuredDirectory, { recursive: true });
const baseline = existsSync(baselinePath) ? JSON.parse(readFileSync(baselinePath, "utf8")) : {};

const raised = [];
const lowered = [];
const added = [];
const dropped = Object.keys(baseline).filter((run) => !(run in measured));
for (const [run, counts] of Object.entries(measured)) {
  if (!(run in baseline)) {
    added.push(run);
    continue;
  }
  const recorded = baseline[run];
  for (const kind of new Set([...Object.keys(recorded), ...Object.keys(counts)])) {
    if (admitted.includes(kind) && Object.values(baseline).every((counted) => !(kind in counted))) continue;
    const was = recorded[kind] ?? 0;
    const now = counts[kind] ?? 0;
    if (now > was) raised.push(`  ↑ ${run} · ${kind}: ${was} → ${now}`);
    if (now < was) lowered.push(`  ↓ ${run} · ${kind}: ${was} → ${now} (−${was - now}, −${Math.round((100 * (was - now)) / was)}%)`);
  }
}

if (raised.length > 0 || dropped.length > 0) {
  console.error("\nRefusing to change the baseline: it only goes down.");
  if (raised.length > 0) console.error(["Counters above the baseline:", ...raised].join("\n"));
  if (dropped.length > 0) console.error(["Runs in the baseline that no longer run:", ...dropped.map((run) => `  - ${run}`)].join("\n"));
  process.exit(1);
}

writeFileSync(baselinePath, JSON.stringify(measured, null, 2) + "\n");
console.log("");
if (lowered.length > 0) console.log(["Lowered:", ...lowered].join("\n"));
if (added.length > 0) console.log(["Added:", ...added.map((run) => `  + ${run}`)].join("\n"));
if (lowered.length === 0 && added.length === 0) console.log("Nothing got better; the baseline is unchanged.");
