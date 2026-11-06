export default [
  { name: "move 30 cards by buttons", run: () => __h.repeat(30, (count) => __h.click(".card .move-next", (count * 41) % 1400)) },
  { name: "drag 20 cards", run: () => __h.repeat(20, (count) => __h.drag(".card", ".column-body", (count * 53 + 7) % 1400, (count * 3 + 1) % 8)) },
  {
    name: "edit 10 cards in modal",
    run: () =>
      __h.repeat(10, async (count) => {
        __h.click(".card .card-title", count * 97 + 3);
        await __h.frame();
        await __h.type(".modal .title-field", " v2");
        __h.click(".modal .label-toggle", count % 6);
        await __h.frame();
        await __h.type(".modal .description-field", " **ok**");
        __h.click(".modal .save");
      }),
  },
  {
    name: "open a card and edit",
    run: async () => {
      __h.click(".card .card-title", 500);
      await __h.frame();
      await __h.type(".modal .description-field", " **draft** <b>x</b>");
      __h.click(".modal .label-toggle", 2);
    },
  },
  { name: "close card with Escape", run: () => __h.key("body", "Escape") },
  {
    name: "add 10 cards",
    run: () =>
      __h.repeat(10, async (count) => {
        __h.click(".add-card", count % 8);
        await __h.frame();
        await __h.type(".composer textarea", `new card ${count}`);
        __h.key(".composer textarea", "Enter");
      }),
  },
  { name: "filter by label", run: () => __h.click(".label-filter button", 0) },
  { name: "clear filter", run: () => __h.click("#clear-filter") },
  { name: "collapse 4 columns", run: () => __h.repeat(4, (count) => __h.click(".column .fold", count * 2)) },
  { name: "expand 4 columns", run: () => __h.repeat(4, (count) => __h.click(".column .fold", count * 2)) },
];
