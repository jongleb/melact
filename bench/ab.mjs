// The working tree against a base commit on js-framework-benchmark's operations, in turns: base,
// head, base, head… so that a loaded machine weighs on both alike. Vanilla runs in every turn as the
// control. A framework's operation fails when the median of its script medians grew by more than the
// threshold over the base's, beyond what vanilla moved. Exits with 1 on any failure.
//
//   node bench/ab.mjs --base=<commit> [--frameworks=meltea,melact] [--ops=...] [--rounds=3] [--runs=8] [--threshold=1.08]
import { spawnSync } from "node:child_process";
import { copyFileSync, existsSync, mkdtempSync, readFileSync, rmSync, symlinkSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const repo = resolve(here, "..");
const args = Object.fromEntries(
  process.argv.slice(2).map((arg) => {
    const [, key, value] = arg.match(/^--([^=]+)(?:=(.*))?$/s);
    return [key, value ?? "true"];
  }),
);
if (!args.base) {
  process.stderr.write("usage: node bench/ab.mjs --base=<commit> [--frameworks=meltea,melact] [--ops=a,b] [--rounds=3] [--runs=8] [--threshold=1.08]\n");
  process.exit(2);
}
const frameworks = (args.frameworks ?? "meltea,melact").split(",");
const ops = args.ops ?? "create rows,replace all rows,partial update,select row,swap rows,remove row,create many rows,append rows,clear rows";
const rounds = Number(args.rounds ?? 3);
const runs = args.runs ?? "8";
const threshold = Number(args.threshold ?? 1.08);
const log = (...parts) => process.stderr.write(parts.join(" ") + "\n");
const run = (command, cwd) => {
  const done = spawnSync(command[0], command.slice(1), { cwd, stdio: ["ignore", "ignore", "inherit"] });
  if (done.status !== 0) throw new Error(`${command.join(" ")} failed in ${cwd}`);
};

const out = mkdtempSync(join(tmpdir(), "melact-ab-"));
const base = join(out, "base");
const commit = spawnSync("git", ["rev-parse", "--short", args.base], { cwd: repo, encoding: "utf8" }).stdout.trim();
run(["git", "worktree", "add", "--detach", base, commit], repo);
try {
  for (const shared of ["_opam", "node_modules"]) symlinkSync(join(repo, shared), join(base, shared));
  // The working tree's harness measures both trees, so that both run the same operations the same way.
  copyFileSync(join(repo, "bench/run.mjs"), join(base, "bench/run.mjs"));
  for (const app of ["vanilla", ...frameworks])
    if (existsSync(join(repo, "bench", app, "node_modules")) && !existsSync(join(base, "bench", app, "node_modules")))
      symlinkSync(join(repo, "bench", app, "node_modules"), join(base, "bench", app, "node_modules"));
  const results = { base: [], head: [] };
  for (let round = 1; round <= rounds; round++)
    for (const [side, tree] of [["base", base], ["head", repo]]) {
      const file = join(out, `${side}-${round}.json`);
      log(`round ${round}/${rounds}: ${side}`);
      run(["node", join(tree, "bench/run.mjs"), `--frameworks=vanilla,${frameworks.join(",")}`, `--runs=${runs}`, `--ops=${ops}`, `--out=${file}`], tree);
      results[side].push(JSON.parse(readFileSync(file, "utf8")).cpu);
    }
  const median = (values) => [...values].sort((a, b) => a - b)[values.length >> 1];
  const script = (side, op, framework) => median(results[side].map((cpu) => cpu[op][framework].script));
  const failed = [];
  console.log(`script ms, median of ${rounds} turns × ${runs} runs; base ${commit} → working tree`);
  for (const op of ops.split(",")) {
    const control = script("head", op, "vanilla") / Math.max(script("base", op, "vanilla"), 0.01);
    for (const framework of frameworks) {
      const before = script("base", op, framework);
      const after = script("head", op, framework);
      const ratio = after / Math.max(before, 0.01) / control;
      const flag = ratio > threshold && after - before > 0.05 ? "  ⚠ slower" : "";
      if (flag) failed.push(`${op} / ${framework}`);
      console.log(`${op.padEnd(18)} ${framework.padEnd(8)} ${before.toFixed(2).padStart(7)} → ${after.toFixed(2).padStart(7)}  ×${ratio.toFixed(2)} (vanilla ×${control.toFixed(2)})${flag}`);
    }
  }
  console.log(failed.length ? `\n${failed.length} slower: ${failed.join(", ")}` : "\nnothing slower");
  process.exitCode = failed.length ? 1 : 0;
} finally {
  run(["git", "worktree", "remove", "--force", base], repo);
  rmSync(out, { recursive: true, force: true });
}
