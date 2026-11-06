export default [
  { name: "switch to split", run: () => __h.click("#layout-split") },
  { name: "switch to unified", run: () => __h.click("#layout-unified") },
  { name: "collapse all", run: () => __h.click("#collapse-all") },
  { name: "expand all", run: () => __h.click("#expand-all") },
  { name: "mark 10 files viewed", run: () => __h.repeat(10, (count) => __h.click(".viewed-toggle", count * 3)) },
  {
    name: "add 10 line comments",
    run: () =>
      __h.repeat(10, async (count) => {
        __h.click(".add-comment", count * 97 + 5);
        await __h.frame();
        await __h.type(".comment-field", `Nit ${count}: rename this`);
        __h.click(".comment-submit");
      }),
  },
  { name: "hide whitespace", run: () => __h.click("#hide-whitespace") },
  { name: "split with comments", run: () => __h.click("#layout-split") },
  { name: "filter file tree", run: () => __h.type("#tree-filter", "comp") },
  { name: "clear file tree filter", run: () => __h.input("#tree-filter", "") },
];
