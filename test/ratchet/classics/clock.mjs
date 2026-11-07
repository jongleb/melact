// Virtual time for the ratchet: timeouts, intervals, animation frames, idle callbacks and
// setImmediate wait in one queue and run only when a driver runs them, so no callback fires at a
// moment that depends on how fast the machine is. The counters still count every call.
const state = globalThis.__ratchet;
if (!state) throw new Error("load the counters before the clock");

export const real = { setImmediate: state.clock.setImmediate, now: performance.now.bind(performance) };
export const yielded = () => new Promise((done) => real.setImmediate(done));

export const clock = { now: 0, order: 0, queue: [], frames: [], handles: 0, failures: [] };
export const failed = (error) => clock.failures.push(String((error && error.stack) || error).split("\n").slice(0, 6).join("\n"));
export const later = (at, entry) => {
  entry.at = at;
  entry.order = ++clock.order;
  let low = 0;
  let high = clock.queue.length;
  while (low < high) {
    const middle = (low + high) >> 1;
    const other = clock.queue[middle];
    if (other.at < at || (other.at === at && other.order < entry.order)) low = middle + 1;
    else high = middle;
  }
  clock.queue.splice(low, 0, entry);
  return entry.handle;
};
const timed = (callback, delay, args, period) =>
  later(clock.now + Math.max(0, Number(delay) || 0), { handle: ++clock.handles, callback, args, period });
const cleared = (handle) => {
  const at = clock.queue.findIndex((entry) => entry.handle === handle);
  if (at >= 0) clock.queue.splice(at, 1);
  const framed = clock.frames.findIndex((entry) => entry.handle === handle);
  if (framed >= 0) clock.frames.splice(framed, 1);
};
export const fired = (entry, argument) => {
  try {
    if (typeof entry.callback === "function") entry.callback(...(argument === undefined ? entry.args || [] : [argument]));
  } catch (error) {
    failed(error);
  }
};

Object.assign(state.clock, {
  setTimeout: (callback, delay, ...args) => timed(callback, delay, args),
  setInterval: (callback, delay, ...args) => timed(callback, delay, args, Math.max(1, Number(delay) || 0)),
  setImmediate: (callback, ...args) => timed(callback, 0, args),
  clearTimeout: cleared,
  clearInterval: cleared,
  clearImmediate: cleared,
  requestAnimationFrame: (callback) => {
    const handle = ++clock.handles;
    clock.frames.push({ handle, callback });
    return handle;
  },
  cancelAnimationFrame: cleared,
  requestIdleCallback: (callback) => timed(() => callback({ didTimeout: false, timeRemaining: () => 0 }), 1, []),
  cancelIdleCallback: cleared,
});
