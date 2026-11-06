export default [
  { name: "expand all", run: () => __h.click("#expand-all") },
  { name: "collapse all", run: () => __h.click("#collapse-all") },
  {
    name: "expand 30 folders",
    run: () =>
      __h.repeat(30, (count) => {
        const closed = __h.all(".tree-row.folder:not(.open)");
        __h.click(closed[(count * 7) % closed.length]);
      }),
  },
  {
    name: "keyboard navigate 50",
    run: () =>
      __h.repeat(50, (count) =>
        __h.key(".tree-view", ["ArrowDown", "ArrowDown", "ArrowRight", "ArrowDown", "ArrowDown", "ArrowLeft", "ArrowDown"][count % 7]),
      ),
  },
  {
    name: "rename 5 files",
    run: () =>
      __h.repeat(5, async (count) => {
        __h.dblclick(".tree-row.file", count * 5);
        await __h.frame();
        __h.input(".rename", `renamed_${count}.ml`);
        await __h.frame();
        __h.key(".rename", "Enter");
      }),
  },
  { name: "filter by name typing", run: () => __h.type("#tree-filter", "pony_") },
  {
    name: "clear filter, expand all again",
    run: async () => {
      __h.click("#clear-filter");
      await __h.frame();
      __h.click("#expand-all");
    },
  },
];
