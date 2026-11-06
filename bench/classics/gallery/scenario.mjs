export default [
  {
    name: "switch albums x4",
    run: () => __h.repeat(4, (index) => __h.click(".album-tabs .tab", [1, 2, 3, 0][index])),
  },
  { name: "open lightbox", run: () => __h.click(".photo .frame", 5) },
  { name: "next x40 via keyboard", run: () => __h.repeat(40, () => __h.key(window, "ArrowRight")) },
  { name: "zoom in x3", run: () => __h.repeat(3, () => __h.click("#zoom-in")) },
  { name: "close lightbox", run: () => __h.key(window, "Escape") },
  { name: "enter select mode", run: () => __h.click("#select-mode") },
  { name: "select 50", run: () => __h.repeat(50, (index) => __h.click(".photo .pick", index * 3)) },
  { name: "favourite 30", run: () => __h.repeat(30, (index) => __h.click(".photo .heart", index * 5 + 1)) },
  {
    name: "resize container x5",
    run: () =>
      __h.repeat(5, async (index) => {
        document.getElementById("root").style.width = `${[900, 700, 1200, 500, 1100][index]}px`;
        await __h.frame();
      }),
  },
  { name: "delete selected", run: () => __h.click("#delete-picked") },
  { name: "leave select mode", run: () => __h.click("#select-mode") },
];
