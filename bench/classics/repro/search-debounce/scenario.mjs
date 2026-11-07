export default [
  { name: "keystroke", run: () => __h.input(".search", "a") },
  { name: "debounce fires", run: () => new Promise((done) => setTimeout(done, 600)) },
  { name: "second keystroke", run: () => __h.input(".search", "al") },
  { name: "debounce fires again", run: () => new Promise((done) => setTimeout(done, 600)) },
  { name: "clear", run: () => __h.input(".search", "") },
  { name: "debounce fires to clear", run: () => new Promise((done) => setTimeout(done, 600)) },
  { name: "open a popover", run: () => __h.click(".span-button", 5) },
  { name: "move it x10", run: () => __h.repeat(10, async (index) => { __h.click(".span-button", 10 + index); await __h.frame(); }) },
  { name: "close it", run: () => __h.click(".close") },
];
