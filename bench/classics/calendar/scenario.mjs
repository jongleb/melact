export default [
  { name: "next month x6", run: () => __h.repeat(6, () => __h.click("#next")) },
  { name: "prev month x6", run: () => __h.repeat(6, () => __h.click("#prev")) },
  { name: "switch to week", run: () => __h.click("#view-week") },
  { name: "next week x10", run: () => __h.repeat(10, () => __h.click("#next")) },
  {
    name: "create 5 events",
    run: () =>
      __h.repeat(5, async (count) => {
        __h.click(".day-column .slot", count * 29 + 9);
        await __h.frame();
        await __h.type(".popover .title-input", `Sync ${count}`);
        const select = document.querySelector(".popover .calendar-select");
        select.value = ["Team", "Family", "Work", "Personal", "Birthdays"][count];
        select.dispatchEvent(new Event("input", { bubbles: true }));
        select.dispatchEvent(new Event("change", { bubbles: true }));
        await __h.frame();
        __h.click(".popover .save");
      }),
  },
  {
    name: "open create popover",
    run: async () => {
      __h.click(".day-column .slot", 6 * 24 + 20);
      await __h.frame();
      await __h.type(".popover .title-input", "Late review");
    },
  },
  { name: "close popover with Escape", run: () => __h.key("body", "Escape") },
  { name: "move 10 events +1h", run: () => __h.repeat(10, (count) => __h.click(".event-block .later", count * 3)) },
  { name: "toggle 4 calendars", run: () => __h.repeat(4, (count) => __h.click(".calendar-toggle input", count)) },
  { name: "switch to day", run: () => __h.click("#view-day") },
  { name: "back to month", run: () => __h.click("#view-month") },
];
