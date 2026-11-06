export default [
  { name: "type into 20 blocks", run: () => __h.repeat(20, (count) => __h.type(".block-text", " typed", count * 31 + 2)) },
  {
    name: "enter 20 new blocks",
    run: () =>
      __h.repeat(20, async (count) => {
        const field = __h.one(".block-text", count * 27 + 5);
        field.focus();
        __h.key(field, "Enter");
        await __h.frame();
        await __h.frame();
        await __h.type(document.activeElement, `new ${count}`);
      }),
  },
  {
    name: "slash menu x10",
    run: () =>
      __h.repeat(10, async (count) => {
        const field = __h.one(".block-text", count * 41 + 3);
        field.focus();
        __h.input(field, "/");
        await __h.frame();
        for (let step = 0; step < count % 9; step++) {
          __h.key(field, "ArrowDown");
          await __h.frame();
        }
        __h.key(field, "Enter");
      }),
  },
  { name: "check 30 todos", run: () => __h.repeat(30, (count) => __h.click(".todo-check", count * 2)) },
  { name: "fold 20 toggles", run: () => __h.repeat(20, (count) => __h.click(".fold-button", count)) },
  { name: "unfold 20 toggles", run: () => __h.repeat(20, (count) => __h.click(".fold-button", count)) },
  { name: "drag 15 blocks", run: () => __h.repeat(15, (count) => __h.drag(".drag-handle", ".block", count * 13 + 40, count * 17 + 2)) },
  { name: "click 10 outline entries", run: () => __h.repeat(10, (count) => __h.click(".outline-link", count * 3)) },
  {
    name: "backspace 20 blocks",
    run: () =>
      __h.repeat(20, async (count) => {
        const field = __h.one(".block-text", 100 + count * 3);
        field.focus();
        __h.input(field, "");
        await __h.frame();
        __h.key(field, "Backspace");
        await __h.frame();
        if (document.activeElement && document.activeElement.classList.contains("block-text")) await __h.type(document.activeElement, "!");
      }),
  },
];
