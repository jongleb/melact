// Types into controlled inputs with real key events in headless Chrome, for Melact and Meltea.
// jsdom's dispatchEvent runs no microtasks between listeners; a trusted event does, which is
// where a controlled input can lose what was typed. Run: node test/browser/typing.mjs
import { spawn, spawnSync } from "node:child_process";
import { createServer } from "node:http";
import { existsSync, mkdtempSync, readFileSync, rmSync, statSync } from "node:fs";
import { tmpdir } from "node:os";
import { extname, join } from "node:path";

const repo = join(import.meta.dirname, "../..");
const chromePath = process.env.CHROME ?? "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const dist = mkdtempSync(join(tmpdir(), "melact-typing-"));

const built = spawnSync("opam", ["exec", "--", "dune", "build", "@test/browser/melact/browser", "@test/browser/meltea/browser"], { cwd: repo, stdio: "inherit" });
if (built.status !== 0) process.exit(1);
const { build } = await import(join(repo, "node_modules/vite/dist/node/index.js"));
for (const name of ["melact", "meltea"])
  await build({
    configFile: join(repo, "vite.config.js"),
    root: repo,
    base: "./",
    logLevel: "silent",
    build: { outDir: join(dist, name), emptyOutDir: true, rollupOptions: { input: join(repo, "test/browser", `${name}.html`) } },
  });

const server = await new Promise((done) => {
  const served = createServer((request, response) => {
    const path = join(dist, decodeURIComponent(new URL(request.url, "http://x").pathname));
    if (!path.startsWith(dist) || !existsSync(path) || !statSync(path).isFile()) return response.writeHead(404).end();
    const types = { ".html": "text/html", ".js": "text/javascript" };
    response.writeHead(200, { "content-type": types[extname(path)] ?? "application/octet-stream" }).end(readFileSync(path));
  });
  served.listen(0, "127.0.0.1", () => done(served));
});

const profile = mkdtempSync(join(tmpdir(), "melact-chrome-"));
const chrome = spawn(chromePath, ["--headless=new", "--remote-debugging-port=0", `--user-data-dir=${profile}`, "--no-first-run", "about:blank"], { stdio: ["ignore", "ignore", "pipe"] });
const endpoint = await new Promise((done, fail) => {
  let text = "";
  chrome.stderr.on("data", (chunk) => {
    text += chunk;
    const found = text.match(/DevTools listening on (ws:\/\/\S+)/);
    if (found) done(found[1]);
  });
  chrome.on("exit", () => fail(new Error("chrome exited: " + text)));
});
const socket = new WebSocket(endpoint);
await new Promise((done) => socket.addEventListener("open", done, { once: true }));
let counter = 0;
const pending = new Map();
socket.addEventListener("message", ({ data }) => {
  const message = JSON.parse(data);
  if (message.id === undefined) return;
  const { done, fail } = pending.get(message.id);
  pending.delete(message.id);
  if (message.error) fail(new Error(JSON.stringify(message.error)));
  else done(message.result);
});
const send = (method, params = {}, sessionId) =>
  new Promise((done, fail) => {
    const id = ++counter;
    pending.set(id, { done, fail });
    socket.send(JSON.stringify({ id, method, params, sessionId }));
  });

const failures = [];
const expected = { plain: "hello", upper: "HELLO", short: "hel" };
for (const name of ["melact", "meltea"]) {
  const { targetId } = await send("Target.createTarget", { url: "about:blank" });
  const { sessionId } = await send("Target.attachToTarget", { targetId, flatten: true });
  const page = (method, params) => send(method, params, sessionId);
  await page("Page.enable");
  await page("Page.navigate", { url: `http://127.0.0.1:${server.address().port}/${name}/test/browser/${name}.html` });
  const evaluate = async (expression) => (await page("Runtime.evaluate", { expression, awaitPromise: true, returnByValue: true })).result.value;
  for (let tries = 0; !(await evaluate(`document.getElementById("short") !== null`)); tries++)
    if (tries > 200) throw new Error(`${name}: the page did not render`);
    else await new Promise((done) => setTimeout(done, 25));
  for (const id of Object.keys(expected)) {
    await evaluate(`document.getElementById(${JSON.stringify(id)}).focus()`);
    for (const key of "hello") {
      await page("Input.dispatchKeyEvent", { type: "keyDown", key, text: key, unmodifiedText: key });
      await page("Input.dispatchKeyEvent", { type: "keyUp", key });
    }
    await evaluate(`new Promise((done) => setTimeout(done, 50))`);
    const shown = await evaluate(`document.getElementById(${JSON.stringify(id)}).value`);
    const verdict = shown === expected[id] ? "ok  " : "FAIL";
    if (shown !== expected[id]) failures.push(`${name} #${id}`);
    console.log(`${verdict} ${name} #${id}: typed "hello", shows ${JSON.stringify(shown)}, expected ${JSON.stringify(expected[id])}`);
  }
}
socket.close();
chrome.kill();
server.close();
rmSync(profile, { recursive: true, force: true });
rmSync(dist, { recursive: true, force: true });
process.exit(failures.length === 0 ? 0 : 1);
