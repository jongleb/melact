export default [
  { name: "play track", run: () => __h.dblclick(".track", 4) },
  { name: "tick progress 30 times", run: () => __h.repeat(30, () => __h.click("#tick")) },
  { name: "drag-reorder 20 tracks", run: () => __h.repeat(20, (count) => __h.drag(".track", ".track", count * 61 + 10, count * 37 + 3)) },
  { name: "like 30 tracks", run: () => __h.repeat(30, (count) => __h.click(".track .like", count * 53 + 1)) },
  {
    name: "sort by title, artist, duration",
    run: async () => {
      __h.click(".sort-header", 0);
      await __h.frame();
      __h.click(".sort-header", 1);
      await __h.frame();
      __h.click(".sort-header", 3);
    },
  },
  { name: "shuffle", run: () => __h.click("#shuffle") },
  {
    name: "select range",
    run: async () => {
      __h.click(".track", 100);
      await __h.frame();
      __h.mouse("click", ".track", 160, { shiftKey: true });
      await __h.frame();
      __h.mouse("click", ".track", 300, { ctrlKey: true });
    },
  },
  { name: "remove selected", run: () => __h.click("#remove-selected") },
  { name: "next track x20", run: () => __h.repeat(20, () => __h.click("#next")) },
  { name: "search 'ro'", run: () => __h.type("#search", "ro") },
  { name: "clear search", run: () => __h.erase("#search", 2) },
];
