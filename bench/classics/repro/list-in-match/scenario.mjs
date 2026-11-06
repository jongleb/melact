export default [
  { name: "select 30 times, list in the hole", run: () => __h.repeat(30, () => __h.click("#direct")) },
  { name: "select 30 times, list in a match", run: () => __h.repeat(30, () => __h.click("#in-match")) },
];
