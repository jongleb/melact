export default [
  { name: "scroll down 40 steps", run: () => __h.scrollBy(".viewport", 180, 40) },
  { name: "scroll up 40 steps", run: () => __h.scrollBy(".viewport", -180, 40) },
  {
    name: "jump to index 5000",
    run: async () => {
      await __h.type("#jump-index", "5000");
      __h.click("#jump");
    },
  },
  {
    name: "expand 20 visible rows",
    run: () =>
      __h.repeat(20, async () => {
        const viewport = document.querySelector(".viewport").getBoundingClientRect();
        const visible = () =>
          __h.all(".row:not(.expanded)").find((row) => {
            const box = row.getBoundingClientRect();
            return box.top >= viewport.top + 30 && box.bottom <= viewport.bottom;
          });
        if (!visible()) {
          document.querySelector(".viewport").scrollTop += 300;
          document.querySelector(".viewport").dispatchEvent(new Event("scroll"));
          await __h.frame();
          await __h.frame();
        }
        __h.click(visible().querySelector(".row-toggle"));
      }),
  },
  { name: "scroll more", run: () => __h.scrollBy(".viewport", 240, 25) },
  {
    name: "jump to the end",
    run: async () => {
      __h.input("#jump-index", "9999");
      await __h.frame();
      __h.click("#jump");
    },
  },
  { name: "filter by typing", run: () => __h.type("#filter", "quaint pony") },
];
