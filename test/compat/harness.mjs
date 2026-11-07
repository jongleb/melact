// Runs the same app on npm's React 18 and on melact.compat, side by side, and reads what a user sees.

// Both sides run as in a browser, not inside act(): act() holds React's renders back until its
// scope ends, which reorders them against the libraries' own timers. Frames are timers here.
globalThis.IS_REACT_ACT_ENVIRONMENT = false;
window.requestAnimationFrame = (callback) => setTimeout(() => callback(performance.now()), 0);

export const tick = () => new Promise((resolve) => setTimeout(resolve, 0));

export function stage(lib) {
  const root = document.body.appendChild(document.createElement("div"));
  const layer = document.body.appendChild(document.createElement("div"));
  root.setAttribute("data-side", lib.name);
  layer.setAttribute("data-layer", lib.name);
  const client = lib.Client.createRoot(root);
  const log = [];
  const settle = async (run) => {
    run?.();
    for (let round = 0; round < 6; round++) await tick();
  };
  return {
    lib,
    root,
    layer,
    log,
    async render(element) {
      await settle(() => client.render(element));
    },
    settle,
    async unmount() {
      await settle(() => client.unmount());
      root.remove();
      layer.remove();
    },
  };
}

const ids = /:[rRm][0-9a-zA-Z]*:|react-select-\d+-/g;

export function shown(side) {
  const names = new Map();
  const rename = (text) =>
    text.replace(ids, (id) => {
      const kind = id.startsWith("react-select") ? "react-select-N-" : ":id";
      const key = kind + id;
      if (!names.has(key)) names.set(key, kind === ":id" ? `:id${names.size}:` : `react-select-${names.size}-`);
      return names.get(key);
    });
  const walk = (node) => {
    if (node.nodeType === 3) return node.data === "" ? "" : JSON.stringify(rename(node.data));
    if (node.nodeType !== 1) return "";
    const attributes = Array.from(node.attributes)
      .map((attribute) => {
        let value = attribute.value;
        if (attribute.name === "style") value = value.split(";").map((part) => part.trim()).filter(Boolean).sort().join("; ");
        return `${attribute.name}=${JSON.stringify(rename(value))}`;
      })
      .sort();
    const children = Array.from(node.childNodes).map(walk).filter(Boolean);
    return `<${node.tagName.toLowerCase()}${attributes.length ? " " + attributes.join(" ") : ""}>${children.join("")}</>`;
  };
  return { root: Array.from(side.root.childNodes).map(walk).join(""), layer: Array.from(side.layer.childNodes).map(walk).join("") };
}

const path = (scope, node) => {
  const steps = [];
  for (let at = node; at && at !== scope; at = at.parentNode) steps.unshift(Array.prototype.indexOf.call(at.parentNode.children, at));
  return steps.join(".");
};

export function focused(side) {
  const active = document.activeElement;
  if (active && side.root.contains(active)) return "root:" + path(side.root, active);
  if (active && side.layer.contains(active)) return "layer:" + path(side.layer, active);
  return "elsewhere";
}

export function seen(side) {
  return { ...shown(side), focus: focused(side), log: side.log.slice() };
}

export async function trace(side, app, actions, perform) {
  const seenAfter = [];
  try {
    await side.render(app(side));
    seenAfter.push(seen(side));
    for (const action of actions) {
      await side.settle(() => perform(side, action));
      seenAfter.push(seen(side));
    }
  } finally {
    await side.unmount();
  }
  return seenAfter;
}

export async function run(sides, app, actions, perform) {
  const [reference, tried] = sides;
  const expected = await trace(reference, app, actions, perform);
  const actual = await trace(tried, app, actions, perform);
  expected.forEach((wanted, index) => {
    const label = index === 0 ? "mount" : `step ${index - 1} ${JSON.stringify(actions[index - 1])} of ${JSON.stringify(actions)}`;
    for (const part of ["root", "layer", "focus", "log"]) {
      if (JSON.stringify(actual[index][part]) !== JSON.stringify(wanted[part]))
        throw new Error(
          `${tried.lib.name} differs from ${reference.lib.name} in ${part} after ${label}\n` +
            `expected ${JSON.stringify(wanted[part])}\n` +
            `actual   ${JSON.stringify(actual[index][part])}`,
        );
    }
  });
}

export const nativeValue = (input, value) => {
  Object.getOwnPropertyDescriptor(Object.getPrototypeOf(input), "value").set.call(input, value);
};

export const fire = (target, type, init = {}) => {
  const Kind = /^key/.test(type)
    ? KeyboardEvent
    : /^(mouse|pointer|click|dblclick|contextmenu)/.test(type)
      ? MouseEvent
      : /^(focus|blur)/.test(type)
        ? FocusEvent
        : Event;
  return target.dispatchEvent(new Kind(type, { bubbles: true, cancelable: true, composed: true, ...init }));
};

globalThis.ResizeObserver ??= class {
  observe() {}
  unobserve() {}
  disconnect() {}
};
