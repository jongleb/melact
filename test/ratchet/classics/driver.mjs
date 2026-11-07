// Runs a page of bench/classics (or any page that mounts on a click of #mount) in jsdom through its
// scenario, the way bench/classics/run.mjs runs it in Chromium, and returns what each step counted.
// Time is virtual: timeouts, intervals, animation frames, idle callbacks and setImmediate wait in one
// queue that the driver runs in order, so a run counts the same every time. After the last step the
// page is unmounted, collected, and checked for what it left behind. RATCHET_KEPT=1 prints the
// subtrees kept after the unmount; RATCHET_SNAPSHOT=<file> also writes a heap snapshot in which the
// first of them holds a LeakMarker, to find what keeps it.
import { readFileSync } from "node:fs";
import { clock, failed, fired, later, real, yielded } from "./clock.mjs";

process.env.NODE_ENV = "production";
const state = globalThis.__ratchet;
if (!state) throw new Error("load the counters before the driver");
const frame = 16;
const horizon = 1000;

const epoch = 1_700_000_000_000;
performance.now = () => clock.now;
Date.now = () => epoch + clock.now;
let seed = 1;
Math.random = () => {
  seed = (seed * 1103515245 + 12345) & 0x7fffffff;
  return seed / 0x80000000;
};
globalThis.IS_REACT_ACT_ENVIRONMENT = false;

const scrolled = new WeakMap();
const sizes = { clientWidth: 1000, offsetWidth: 1000, scrollWidth: 1000, clientHeight: 600, offsetHeight: 20 };
const height = (element) => Math.max(600, 20 * element.childElementCount);
const offsets = (element) => {
  let kept = scrolled.get(element);
  if (!kept) scrolled.set(element, (kept = { scrollTop: 0, scrollLeft: 0 }));
  return kept;
};
state.layout = {
  get: (element, name) =>
    name === "scrollTop" || name === "scrollLeft" ? offsets(element)[name] : name === "scrollHeight" ? height(element) : sizes[name] ?? 0,
  set: (element, name, value) => {
    const limit = name === "scrollTop" ? height(element) - 600 : 0;
    offsets(element)[name] = Math.max(0, Math.min(limit, Number(value) || 0));
  },
  rect: () => ({ x: 0, y: 0, top: 0, left: 0, right: 1000, bottom: 20, width: 1000, height: 20, toJSON() { return this; } }),
};

const observed = (entries) =>
  class {
    constructor(callback) {
      this.callback = callback;
    }
    observe(target) {
      state.clock.requestAnimationFrame(() => this.callback([entries(target)], this));
    }
    unobserve() {}
    disconnect() {}
    takeRecords() {
      return [];
    }
  };
const box = { x: 0, y: 0, top: 0, left: 0, right: 1000, bottom: 600, width: 1000, height: 600 };
globalThis.ResizeObserver = observed((target) => ({ target, contentRect: box, borderBoxSize: [{ inlineSize: 1000, blockSize: 600 }] }));
globalThis.IntersectionObserver = observed((target) => ({
  target,
  isIntersecting: false,
  intersectionRatio: 0,
  boundingClientRect: box,
  intersectionRect: box,
  rootBounds: box,
  time: clock.now,
}));
for (const name of ["scrollIntoView", "setPointerCapture", "releasePointerCapture"]) Element.prototype[name] ??= function () {};
Element.prototype.hasPointerCapture ??= () => false;
Element.prototype.scrollTo ??= function (x, y) {
  const top = typeof x === "object" ? x.top : y;
  if (top !== undefined) this.scrollTop = top;
};
window.scrollTo = () => {};
window.scrollBy = () => {};
globalThis.PointerEvent ??= class extends MouseEvent {
  constructor(type, init = {}) {
    super(type, init);
    this.pointerId = init.pointerId ?? 1;
    this.pointerType = init.pointerType ?? "mouse";
  }
};
globalThis.DataTransfer ??= class {
  constructor() {
    this.data = new Map();
    this.dropEffect = "none";
    this.effectAllowed = "all";
  }
  get types() {
    return [...this.data.keys()];
  }
  setData(type, value) {
    this.data.set(type, String(value));
  }
  getData(type) {
    return this.data.get(type) ?? "";
  }
  clearData() {
    this.data.clear();
  }
  setDragImage() {}
};
globalThis.DragEvent ??= class extends MouseEvent {
  constructor(type, init = {}) {
    super(type, init);
    this.dataTransfer = init.dataTransfer ?? null;
  }
};
for (const name of ["UIEvent", "MouseEvent", "PointerEvent", "DragEvent", "WheelEvent", "KeyboardEvent", "FocusEvent", "InputEvent"]) {
  const made = globalThis[name];
  if (!made) continue;
  globalThis[name] = class extends made {
    constructor(type, init) {
      super(type, init && init.view ? { ...init, view: null } : init);
    }
  };
}
if (!navigator.clipboard) Object.defineProperty(navigator, "clipboard", { value: { writeText: () => Promise.resolve(), readText: () => Promise.resolve("") } });

const painted = () => {
  if (state.dirty) {
    state.bump("frame layouts", 1);
    state.dirty = false;
  }
};
const advanced = async (to) => {
  for (let boundary = (Math.floor(clock.now / frame) + 1) * frame; boundary <= to; boundary += frame) {
    clock.now = boundary;
    const due = clock.frames.splice(0);
    for (const entry of due) {
      fired(entry, boundary);
      await yielded();
    }
    painted();
  }
  clock.now = Math.max(clock.now, to);
};
const next = () => {
  const boundary = (Math.floor(clock.now / frame) + 1) * frame;
  const queued = clock.queue.length > 0 ? clock.queue[0].at : Infinity;
  return clock.frames.length > 0 ? Math.min(boundary, queued) : queued;
};
const settled = async (finished, until = Infinity) => {
  let ended;
  for (let guard = 0; guard < 200_000; guard++) {
    await yielded();
    if (ended === undefined && finished()) ended = clock.now;
    const at = next();
    if (at === Infinity) {
      if (ended !== undefined) return;
      throw new Error("the step waits for something that never comes");
    }
    if (ended !== undefined && at > Math.min(until, ended + horizon)) return;
    if (at >= (Math.floor(clock.now / frame) + 1) * frame) await advanced(at);
    if (clock.queue.length > 0 && clock.queue[0].at <= clock.now) {
      const entry = clock.queue.shift();
      if (entry.period !== undefined) later(clock.now + entry.period, entry);
      fired(entry);
    }
  }
  throw new Error("the step never settles");
};
const stepped = async (run) => {
  let finished = false;
  (async () => {
    try {
      await run();
    } catch (error) {
      failed(error);
    } finally {
      finished = true;
    }
  })();
  await settled(() => finished);
};

const helpers = readFileSync("bench/classics/helpers.js", "utf8");
const quietly = (run) => {
  state.quiet++;
  try {
    return run();
  } finally {
    state.quiet--;
  }
};
quietly(() => {
  (0, eval)(helpers);
  document.querySelector("*");
  document.documentElement.matches("*");
});

const own = () => new Set([...Object.getOwnPropertyNames(window), ...Object.getOwnPropertyNames(document)]);
const shown = () => {
  const root = document.getElementById("root");
  const portal = document.getElementById("portal");
  return (root ? root.textContent : "") + "\n" + (portal ? portal.textContent : "");
};

// Runs one page. `load` imports the build, `start` is called with the module once it is loaded, `steps`
// are the scenario's. Returns { outcome: [counts per step, pages],
// names, failures, elements }: `elements` is the most elements the page had after a step.
export const run = async ({ load, start, steps }) => {
  clock.queue.length = 0;
  clock.frames.length = 0;
  clock.failures.length = 0;
  seed = 1;
  const page = quietly(() => {
    document.body.replaceChildren();
    const controls = document.createElement("div");
    controls.id = "bench-controls";
    for (const id of ["mount", "unmount"]) {
      const button = document.createElement("button");
      button.id = id;
      controls.append(button);
    }
    const root = document.createElement("div");
    root.id = "root";
    const portal = document.createElement("div");
    portal.id = "portal";
    document.body.append(controls, root, portal);
    return [controls, root, portal];
  });
  const loaded = await load();
  start(loaded);
  await settled(() => true);
  state.take();
  const globals = own();
  state.made = [];
  state.generation++;
  const counts = [];
  const pages = [];
  const names = [];
  let elements = 0;
  const all = [{ name: "mount", run: () => __h.click("#mount") }, ...steps];
  for (const step of all) {
    await stepped(step.run);
    counts.push(state.take());
    pages.push(shown());
    names.push(step.name);
    elements = Math.max(elements, document.querySelectorAll("#root *, #portal *").length);
  }
  await stepped(() => __h.click("#unmount"));
  counts.push(state.take());
  names.push("unmount");
  for (let round = 0; round < 64 && clock.queue.some((entry) => entry.period === undefined); round++)
    await settled(() => true, clock.now + 60_000);
  const timers = clock.queue.length + clock.frames.length;
  clock.queue.length = 0;
  clock.frames.length = 0;
  quietly(() => {
    if (document.activeElement && document.activeElement !== document.body) document.activeElement.blur();
    page.splice(0).forEach((element) => element.remove());
  });
  state.take();
  const made = state.made;
  state.made = null;
  if (typeof globalThis.gc !== "function") throw new Error("the leak check needs --expose-gc");
  const implementation = document[Object.getOwnPropertySymbols(document).find((symbol) => symbol.description === "impl")];
  quietly(() => document.dispatchEvent(new MouseEvent("mouseout")));
  for (const engine of [implementation._nwsapi, implementation._nwsapiDontThrow]) if (engine) engine.configure({}, true);
  for (let round = 0; round < 3; round++) {
    await yielded();
    globalThis.gc();
  }
  await yielded();
  const nodes = made.filter((held) => {
    const node = held.deref();
    return node && !node.isConnected && node.ownerDocument === document && node.nodeName !== "TEMPLATE";
  }).length;
  if (process.env.RATCHET_KEPT) {
    const tops = new Map();
    for (const held of made) {
      const node = held.deref();
      if (!node || node.isConnected || node.ownerDocument !== document || node.nodeName === "TEMPLATE") continue;
      let top = node;
      while (top.parentNode) top = top.parentNode;
      tops.set(top, (tops.get(top) || 0) + 1);
    }
    for (const [top, count] of tops) console.log("kept", count, top.nodeName, top.className, String(top.outerHTML || top.textContent).slice(0, 160));
    if (process.env.RATCHET_SNAPSHOT && tops.size > 0) {
      class LeakMarker {}
      [...tops.keys()][0].__marker = new LeakMarker();
      const v8 = await import("node:v8");
      console.log("snapshot", v8.writeHeapSnapshot(process.env.RATCHET_SNAPSHOT));
    }
  }
  const added = [...own()].filter((name) => !globals.has(name)).length;
  state.bump("nodes kept", nodes);
  state.bump("listeners kept", state.listening());
  state.bump("timers kept", timers);
  state.bump("globals kept", added);
  counts.push(state.take());
  names.push("after unmount");
  return { outcome: [counts, pages.join("\n----\n")], names, failures: clock.failures.slice(), elements };
};

export const scenario = async (path) => (await import(/* @vite-ignore */ process.cwd() + "/" + path)).default;
export const elapsed = () => real.now();
