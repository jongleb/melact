// What every Svelte build of a classic app shares: the Mount and Unmount buttons, and the same
// deterministic data as the OCaml builds' Classic module (Melange's 32-bit integers included).
import { mount, unmount } from "svelte";

export const start = (App) => {
  const root = document.getElementById("root");
  let app = null;
  document.getElementById("mount").addEventListener("click", () => {
    if (app === null) app = mount(App, { target: root });
  });
  document.getElementById("unmount").addEventListener("click", () => {
    if (app !== null) {
      unmount(app);
      app = null;
    }
  });
};

export const seed = (state) => ({ state });

export const next = (seed, bound) => {
  seed.state = (Math.imul(seed.state, 1103515245) + 12345) & 2147483647;
  return seed.state % bound;
};

export const words = [
  "alpha", "bravo", "charlie", "delta", "echo", "foxtrot", "golf", "hotel", "india", "juliet", "kilo",
  "lima", "mike", "november", "oscar", "papa", "quebec", "romeo", "sierra", "tango", "uniform",
  "victor", "whiskey", "xray", "yankee", "zulu", "pretty", "large", "small", "quaint", "elegant",
  "angry", "helpful", "odd", "table", "chair", "house", "desk", "pony", "cookie", "keyboard", "mouse",
];

export const pick = (seed, choices) => choices[next(seed, choices.length)];

export const sentence = (seed, count) => Array.from({ length: count }, () => pick(seed, words)).join(" ");
