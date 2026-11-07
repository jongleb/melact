export default [
  { name: "zoom week", run: () => __h.click("#zoom-week") },
  { name: "zoom month", run: () => __h.click("#zoom-month") },
  { name: "zoom day", run: () => __h.click("#zoom-day") },
  { name: "collapse all groups", run: () => __h.click("#collapse-all") },
  { name: "expand all groups", run: () => __h.click("#expand-all") },
  { name: "shift 30 tasks", run: () => __h.repeat(30, (count) => __h.click(".task-row .shift", (count * 9) % 300)) },
  { name: "extend 20 tasks", run: () => __h.repeat(20, (count) => __h.click(".task-row .extend", (count * 13 + 4) % 300)) },
  { name: "select 20 tasks", run: () => __h.repeat(20, (count) => __h.mouse("click", ".bar", count * 11 + 2, { ctrlKey: count > 0 })) },
  { name: "scroll timeline", run: () => __h.scrollBy(".timeline", 120, 30) },
  { name: "hide task table", run: () => __h.click("#toggle-table") },
  { name: "show task table", run: () => __h.click("#toggle-table") },
];
