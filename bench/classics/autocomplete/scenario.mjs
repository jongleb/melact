export default [
  { name: "type a query char by char", run: () => __h.type("#search", "pretty pon") },
  { name: "erase it", run: () => __h.erase("#search", 10) },
  { name: "type another", run: () => __h.type("#search", "keyb") },
  { name: "arrow down 50 times", run: () => __h.repeat(50, () => __h.key("#search", "ArrowDown")) },
  { name: "arrow up 10 times", run: () => __h.repeat(10, () => __h.key("#search", "ArrowUp")) },
  {
    name: "choose 10 items",
    run: () =>
      __h.repeat(10, async (count) => {
        __h.input("#search", "");
        await __h.frame();
        await __h.type("#search", ["mo", "ch", "de", "ta", "li"][count % 5]);
        __h.key("#search", "ArrowDown");
        await __h.frame();
        __h.key("#search", "ArrowDown");
        await __h.frame();
        __h.key("#search", "Enter");
      }),
  },
  { name: "pick a recent search", run: () => __h.click(".recent-search", 1) },
  { name: "remove 5 chips", run: () => __h.repeat(5, () => __h.click(".chip .remove", 0)) },
  { name: "escape closes", run: () => __h.key("#search", "Escape") },
  {
    name: "query with no results",
    run: async () => {
      __h.input("#search", "");
      await __h.frame();
      await __h.type("#search", "zzqx");
    },
  },
];
