// Runs the same app on npm's React 18 and on melact.compat, side by side, and reads what a user sees.

export const tick = () => new Promise((resolve) => setTimeout(resolve, 0));

export function stage(lib) {
  const root = document.body.appendChild(document.createElement("div"));
  const layer = document.body.appendChild(document.createElement("div"));
  root.setAttribute("data-side", lib.name);
  layer.setAttribute("data-layer", lib.name);
  const client = lib.Client.createRoot(root);
  const log = [];
  const settle = async (run) => {
    await lib.React.act(async () => {
      run?.();
      await tick();
      await tick();
    });
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

export async function both(sides, act) {
  for (const side of sides) await side.settle(() => act(side));
}
