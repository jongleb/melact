// tiptap as the team binds it: EditorContent in one file (tiptap.mlx, as toolkit's Tiptap.re), useEditor in
// the file that calls it (widget.mlx, as DaTextWidget.re). Under -foreign-engine island the editor view goes to
// an island and useEditor runs on melact.compat, so the editor useEditor makes crosses engines, and
// @tiptap/react is bundled in both colours. Bundled by esbuild as an app is, both builds get the same random
// clicks on commands that change the document and must show the same DOM as reason-react on React 18.
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import fc from "fast-check";
import { tick } from "./harness.mjs";

execFileSync("node", ["test/compat/tiptap/build.mjs"], { stdio: "inherit" });
globalThis.ClipboardEvent ??= class ClipboardEvent extends Event {};
globalThis.DragEvent ??= class DragEvent extends Event {};
Range.prototype.getClientRects ??= () => [];
Range.prototype.getBoundingClientRect ??= () => ({ top: 0, left: 0, right: 0, bottom: 0, width: 0, height: 0 });
document.elementFromPoint ??= () => null;
const output = (side) => `_build/default/test/compat/tiptap/${side}/output`;
const loaded = (side) => new Function(`${readFileSync(`${output(side)}/bundle.js`, "utf8")}; return App;`)();
const Reason = loaded("react");
const Melact = loaded("melact");
const duplicates = JSON.parse(readFileSync(`${output("melact")}/duplicates.json`, "utf8"));

const settle = async () => {
  for (let round = 0; round < 20; round++) await tick();
};
const canonical = (root) => {
  const walk = (node) => {
    if (node.nodeType === 3) return JSON.stringify(node.data);
    if (node.nodeType !== 1) return "";
    const children = Array.from(node.childNodes).map(walk).join("");
    if (node.tagName === "MELACT-ISLAND" || node.tagName === "MELACT-SLOT") return children;
    const attributes = Array.from(node.attributes)
      .filter((attribute) => attribute.name !== "class" || !node.isContentEditable)
      .map((attribute) => `${attribute.name}=${JSON.stringify(attribute.value)}`)
      .sort()
      .join(" ");
    return `<${node.tagName.toLowerCase()} ${attributes}>${children}</>`;
  };
  return Array.from(root.childNodes).map(walk).join("");
};

test("an editor made by useEditor on melact.compat and shown by EditorContent on an island edits as under React 18", async () => {
  await fc.assert(
    fc.asyncProperty(fc.array(fc.constantFrom("replace", "bold", "insert"), { maxLength: 8 }), async (clicks) => {
      const traces = [];
      for (const build of [Reason, Melact]) {
        const root = document.body.appendChild(document.createElement("div"));
        build.mount(root);
        await settle();
        const trace = [canonical(root)];
        for (const click of clicks) {
          root.querySelector(`.${click}`).click();
          await settle();
          trace.push(canonical(root));
        }
        traces.push(trace);
        root.remove();
      }
      expect(traces[1]).toEqual(traces[0]);
      expect(traces[0][0]).toContain('"hello"');
    }),
    { numRuns: 12 },
  );
  expect(duplicates.map((path) => path.replace(/.*node_modules\//, ""))).toEqual(["@tiptap/react/dist/index.js"]);
});
