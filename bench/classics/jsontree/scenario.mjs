export default [
  { name: "expand all", run: () => __h.click("#expand-all") },
  { name: "collapse all", run: () => __h.click("#collapse-all") },
  { name: "expand to depth 3", run: () => __h.click("#expand-depth-3") },
  { name: "search typing", run: () => __h.type("#json-search", "pony") },
  { name: "clear search", run: () => __h.click("#clear-search") },
  {
    name: "hover 40 keys",
    run: () =>
      __h.repeat(40, async (count) => {
        const key = document.querySelectorAll(".json-key")[count * 9 + 1];
        const outside = document.body;
        key.dispatchEvent(new MouseEvent("mouseover", { bubbles: true, relatedTarget: outside }));
        key.dispatchEvent(new MouseEvent("mouseenter", { bubbles: false, relatedTarget: outside }));
        await __h.frame();
        key.dispatchEvent(new MouseEvent("mouseout", { bubbles: true, relatedTarget: outside }));
        key.dispatchEvent(new MouseEvent("mouseleave", { bubbles: false, relatedTarget: outside }));
      }),
  },
  { name: "toggle 30 nodes", run: () => __h.repeat(30, (count) => __h.click(".json-toggle", count * 5 + 1)) },
  { name: "copy 5 paths", run: () => __h.repeat(5, (count) => __h.click(".json-copy", count * 11 + 2)) },
];
