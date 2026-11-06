export default [
  { name: "select 30 cells", run: () => __h.repeat(30, (count) => __h.click(".grid td", (count * 163) % 5000)) },
  {
    name: "edit 10 cells",
    run: () =>
      __h.repeat(10, async (count) => {
        __h.click(".grid td", 1 + count * 251);
        __h.key(".sheet", String(count));
        await __h.frame();
        await __h.type(".cell-editor", "25");
        __h.key(".cell-editor", "Enter");
      }),
  },
  {
    name: "edit A1 five times",
    run: () =>
      __h.repeat(5, async (count) => {
        __h.click(".grid td", 0);
        __h.key(".sheet", String(count + 1));
        await __h.frame();
        await __h.type(".cell-editor", "7");
        __h.key(".cell-editor", "Enter");
      }),
  },
  {
    name: "formula bar edit",
    run: async () => {
      __h.click(".grid td", 5 * 50 + 12);
      await __h.frame();
      __h.input("#formula", "");
      await __h.type("#formula", "=SUM(A1:J10)*2");
      __h.key("#formula", "Enter");
    },
  },
  {
    name: "fill a column",
    run: async () => {
      __h.click(".grid td", 13);
      await __h.frame();
      __h.input("#formula", "=A1+B1*C1");
      await __h.frame();
      __h.key("#formula", "Enter");
      await __h.frame();
      __h.click(".grid td", 13);
      await __h.frame();
      __h.click("#fill-down");
    },
  },
  {
    name: "edit on double click",
    run: async () => {
      __h.dblclick(".grid td", 50 * 3 + 2);
      await __h.frame();
      await __h.erase(".cell-editor", 4);
      await __h.type(".cell-editor", "=B1*3");
      __h.key(".cell-editor", "Enter");
    },
  },
  {
    name: "arrow keys x40",
    run: async () => {
      __h.click(".grid td", 0);
      await __h.frame();
      await __h.repeat(40, (count) => __h.key(".sheet", count % 2 ? "ArrowDown" : "ArrowRight"));
    },
  },
  {
    name: "delete 10 cells",
    run: () =>
      __h.repeat(10, (count) => {
        __h.click(".grid td", 20 + count * 50);
        __h.key(".sheet", "Delete");
      }),
  },
  { name: "undo x10", run: () => __h.repeat(10, () => __h.click("#undo")) },
  { name: "undo the rest", run: () => __h.repeat(12, () => __h.click("#undo")) },
];
