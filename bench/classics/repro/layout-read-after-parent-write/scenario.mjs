export default [
  { name: "select next x20, context only", run: () => __h.repeat(20, () => __h.click("#next")) },
  { name: "echo the selection in the parent", run: () => __h.click("#echo") },
  { name: "select next x20, context + text", run: () => __h.repeat(20, () => __h.click("#next")) },
];
