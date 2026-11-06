export default [
  { name: "append 30 batches", run: () => __h.repeat(30, () => __h.click("#append")) },
  { name: "toggle levels x4", run: () => __h.repeat(4, (index) => __h.click(".level-toggle input", [0, 1, 0, 1][index])) },
  { name: "type a query", run: () => __h.type(".search", "alpha") },
  { name: "clear the query", run: () => __h.erase(".search", 5) },
  { name: "toggle wrap", run: () => __h.click("#wrap") },
  {
    name: "select ranges x10",
    run: () =>
      __h.repeat(10, async (index) => {
        __h.mouse("click", ".log-line", 100 + index * 300);
        await __h.frame();
        __h.mouse("click", ".log-line", 100 + index * 300 + 25, { shiftKey: true });
      }),
  },
  {
    name: "pause follow and scroll",
    run: async () => {
      __h.click("#follow");
      await __h.frame();
      await __h.scrollBy(".log-view", -400, 15);
    },
  },
  {
    name: "live 10 batches then stop",
    run: () =>
      new Promise((done) => {
        const counter = document.querySelector("#batches");
        const target = Number(counter.textContent) + 10;
        const observer = new MutationObserver(() => {
          if (Number(counter.textContent) >= target) {
            observer.disconnect();
            __h.click("#stop");
            done();
          }
        });
        observer.observe(counter, { subtree: true, childList: true, characterData: true });
        __h.click("#live");
      }),
  },
];
