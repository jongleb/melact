export default [
  {
    name: "play 40 moves by clicking",
    run: () =>
      __h.repeat(40, async () => {
        const hint = document.getElementById("hint").textContent;
        if (hint.length !== 4) return;
        __h.click(`#sq-${hint.slice(0, 2)}`);
        await __h.frame();
        __h.click(`#sq-${hint.slice(2, 4)}`);
      }),
  },
  { name: "jump to move 10", run: () => __h.click(".move-list .ply", 18) },
  { name: "ArrowRight x30", run: () => __h.repeat(30, () => __h.key("body", "ArrowRight")) },
  { name: "ArrowLeft x20", run: () => __h.repeat(20, () => __h.key("body", "ArrowLeft")) },
  { name: "flip board x5", run: () => __h.repeat(5, () => __h.click("#flip")) },
  { name: "circle 10 squares", run: () => __h.repeat(10, (count) => __h.mouse("contextmenu", ".square", (count * 7 + 3) % 64)) },
  { name: "toggle coordinates x2", run: () => __h.repeat(2, () => __h.click("#coordinates")) },
  { name: "back to start", run: () => __h.click("#first") },
  { name: "next x80", run: () => __h.repeat(80, () => __h.click("#next")) },
];
