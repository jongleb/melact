export default [
  { name: "collapse all", run: () => __h.click("#collapse-all") },
  { name: "expand all", run: () => __h.click("#expand-all") },
  {
    name: "collapse 20 subtrees",
    run: () =>
      __h.repeat(20, () => {
        const open = __h.all(".span-toggle:not(.collapsed)");
        __h.click(open[open.length - 1]);
      }),
  },
  { name: "expand them", run: () => __h.repeat(20, () => __h.click(".span-toggle.collapsed", 0)) },
  {
    name: "hover 40 spans",
    run: () =>
      __h.repeat(40, async (count) => {
        const row = document.querySelectorAll(".span-row")[count * 4];
        const outside = document.body;
        row.dispatchEvent(new MouseEvent("mouseover", { bubbles: true, relatedTarget: outside }));
        row.dispatchEvent(new MouseEvent("mouseenter", { bubbles: false, relatedTarget: outside }));
        await __h.frame();
        row.dispatchEvent(new MouseEvent("mouseout", { bubbles: true, relatedTarget: outside }));
        row.dispatchEvent(new MouseEvent("mouseleave", { bubbles: false, relatedTarget: outside }));
      }),
  },
  { name: "select 10 spans", run: () => __h.repeat(10, (count) => __h.click(".span-row .span-name", count * 17 + 3)) },
  { name: "type a search", run: () => __h.type(".trace-search", "payments") },
  { name: "clear the search", run: () => __h.click("#clear-search") },
  {
    name: "resize x5",
    run: () =>
      __h.repeat(5, (count) => {
        document.querySelector(".trace-view").style.width = `${1180 - count * 110}px`;
      }),
  },
];
