export default [
  { name: "step 30 ticks", run: () => __h.repeat(30, () => __h.click("#step")) },
  {
    name: "live 10 ticks then pause",
    run: () =>
      new Promise((done) => {
        const counter = document.querySelector("#tick-count");
        const target = Number(counter.textContent) + 10;
        const observer = new MutationObserver(() => {
          if (Number(counter.textContent) >= target) {
            observer.disconnect();
            __h.click("#pause");
            done();
          }
        });
        observer.observe(counter, { subtree: true, childList: true, characterData: true });
        __h.click("#live");
      }),
  },
  { name: "range 1h", run: () => __h.click(".range button", 0) },
  { name: "range 6h", run: () => __h.click(".range button", 1) },
  { name: "range 24h", run: () => __h.click(".range button", 2) },
  { name: "toggle 10 legend items", run: () => __h.repeat(10, (index) => __h.click(".legend-item", index)) },
  {
    name: "hover 40 positions",
    run: async () => {
      const svg = document.querySelectorAll(".line-chart svg")[3];
      const box = svg.getBoundingClientRect();
      await __h.repeat(40, (index) =>
        __h.mouse("mousemove", svg, 0, { clientX: box.left + (box.width * (index + 0.5)) / 40, clientY: box.top + box.height / 2 }),
      );
      svg.dispatchEvent(new MouseEvent("mouseout", { bubbles: true, cancelable: true, view: window, relatedTarget: document.body }));
      svg.dispatchEvent(new MouseEvent("mouseleave", { bubbles: false, cancelable: false, view: window, relatedTarget: document.body }));
    },
  },
  { name: "switch theme", run: () => __h.click("#theme") },
  { name: "switch theme back", run: () => __h.click("#theme") },
];
