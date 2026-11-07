// Melact against an earlier Melact: every app of the corpus, built at a base commit and at the
// working tree, run app by app in turn. A step is flagged when Melact does more layouts or style
// recalculations than before, or when its time against React (the control) grew by more than the
// threshold. Exits with 1 when anything is flagged.
//
//   node bench/classics/versus.mjs --base=db61335 [--apps=eventtable,trace] [--runs=5] [--cpu=1] [--threshold=1.15]
import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, readdirSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const repo = resolve(here, "../..");
const args = Object.fromEntries(
  process.argv.slice(2).map((arg) => {
    const [, key, value] = arg.match(/^--([^=]+)(?:=(.*))?$/s);
    return [key, value ?? "true"];
  }),
);
if (!args.base) {
  process.stderr.write("usage: node bench/classics/versus.mjs --base=<commit> [--apps=a,b] [--runs=5] [--cpu=1] [--threshold=1.15]\n");
  process.exit(2);
}
const runs = args.runs ?? "5";
const cpu = args.cpu ?? "1";
const threshold = Number(args.threshold ?? 1.15);
const apps = args.apps
  ? args.apps.split(",")
  : readdirSync(here, { withFileTypes: true })
      .filter((entry) => entry.isDirectory() && existsSync(join(here, entry.name, "scenario.mjs")))
      .map((entry) => entry.name);
const log = (...parts) => process.stderr.write(parts.join(" ") + "\n");
const run = (command, options) => {
  const done = spawnSync(command[0], command.slice(1), { stdio: ["ignore", "pipe", "inherit"], encoding: "utf8", ...options });
  if (done.status !== 0) throw new Error(`${command.join(" ")} failed`);
  return done.stdout;
};

const out = join(tmpdir(), `melact-versus-${process.pid}`);
const base = join(out, "base");
mkdirSync(out, { recursive: true });
const commit = run(["git", "rev-parse", "--short", args.base], { cwd: repo }).trim();
log(`base ${commit} in ${base}`);
run(["git", "worktree", "add", "--detach", base, commit], { cwd: repo });
try {
  for (const shared of ["_opam", "node_modules"]) symlinkSync(join(repo, shared), join(base, shared));
  rmSync(join(base, "bench/classics"), { recursive: true, force: true });
  run(["rsync", "-a", "--exclude", "_dist", "--exclude", "results*", "--exclude", "RESULTS.md", here + "/", join(base, "bench/classics") + "/"]);
  const measure = (tree, app) => {
    const file = join(out, `${app}-${tree === repo ? "head" : "base"}.json`);
    run(["node", join(tree, "bench/classics/run.mjs"), `--apps=${app}`, `--cpu=${cpu}`, `--runs=${runs}`, `--out=${file}`], { cwd: tree });
    return JSON.parse(readFileSync(file, "utf8"))[app].rates[cpu].rows;
  };
  const flagged = [];
  const table = [];
  for (const app of apps) {
    log(`${app}: base`);
    const before = measure(base, app);
    log(`${app}: head`);
    const after = measure(repo, app);
    for (const row of after) {
      const old = before.find((candidate) => candidate.step === row.step);
      if (!old) continue;
      const ratio = (measured) => measured.melact.task / Math.max(measured.react.task, 0.1);
      const drift = ratio(row) / Math.max(ratio(old), 0.01);
      const reasons = [];
      if (row.melact.layouts > old.melact.layouts) reasons.push(`layouts ${old.melact.layouts}→${row.melact.layouts}`);
      if (row.melact.styles > old.melact.styles) reasons.push(`styles ${old.melact.styles}→${row.melact.styles}`);
      if (drift > threshold && row.melact.task - old.melact.task > 1) reasons.push(`time vs React ×${drift.toFixed(2)}`);
      const line = { app, step: row.step, base: old.melact.task, head: row.melact.task, react: row.react.task, drift, reasons };
      table.push(line);
      if (reasons.length) flagged.push(line);
    }
  }
  writeFileSync(join(out, "versus.json"), JSON.stringify({ base: commit, cpu, runs, table }, null, 1));
  const ms = (value) => value.toFixed(1).padStart(7);
  console.log(`Melact at ${commit} → working tree, ${cpu}x CPU, ${runs} runs; main-thread ms`);
  console.log(`${"app".padEnd(14)}${"step".padEnd(30)}${"base".padStart(7)}${"head".padStart(7)}${"react".padStart(7)}  drift`);
  for (const line of table)
    console.log(
      `${line.app.padEnd(14)}${line.step.slice(0, 29).padEnd(30)}${ms(line.base)}${ms(line.head)}${ms(line.react)}  ×${line.drift.toFixed(2)}${line.reasons.length ? "  ⚠ " + line.reasons.join(", ") : ""}`,
    );
  console.log(flagged.length ? `\n${flagged.length} steps got worse` : "\nno step got worse");
  process.exitCode = flagged.length ? 1 : 0;
} finally {
  run(["git", "worktree", "remove", "--force", base], { cwd: repo });
}
