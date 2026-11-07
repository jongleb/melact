// What a user does on the big page: each step changes a part of it whose size does not depend on the page's.
export default [
  { name: "keystroke", run: () => __h.input(".search", "a") },
  { name: "debounce fires", run: () => new Promise((done) => setTimeout(done, 400)) },
  { name: "open a popover", run: () => __h.click(".opener", 7) },
  { name: "close it", run: () => __h.click(".close") },
  { name: "mark the first forty rows", run: () => __h.click(".marker") },
  { name: "unmark them", run: () => __h.click(".marker") },
  { name: "tick a row", run: () => __h.click(".pick input", 11) },
];
