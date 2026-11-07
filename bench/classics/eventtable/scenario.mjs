export default [
  { name: "expand all", run: () => __h.click("#expand-all") },
  { name: "collapse all", run: () => __h.click("#collapse-all") },
  { name: "toggle 30 rows", run: () => __h.repeat(30, (count) => __h.click(".event-row .toggle", count * 11)) },
  { name: "force rerender x10", run: () => __h.repeat(10, () => __h.click("#force-rerender")) },
  {
    name: "resize table x5",
    run: () =>
      __h.repeat(5, (count) => {
        document.querySelector(".event-table").style.width = `${1180 - count * 90}px`;
      }),
  },
  { name: "sort x3", run: () => __h.repeat(3, (count) => __h.click(".header-cell", [4, 4, 2][count])) },
  {
    name: "filter warn+",
    run: () => {
      const select = document.querySelector(".level-filter");
      select.value = "warn";
      select.dispatchEvent(new Event("input", { bubbles: true }));
      select.dispatchEvent(new Event("change", { bubbles: true }));
    },
  },
  { name: "select ArrowDown x30", run: () => __h.repeat(30, () => __h.key(".event-body", "ArrowDown")) },
  { name: "expand all again", run: () => __h.click("#expand-all") },
  { name: "collapse all again", run: () => __h.click("#collapse-all") },
];
