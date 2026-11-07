export default [
  { name: "plain rows: filter to 1/9", run: () => __h.click("#filter") },
  { name: "plain rows: back to all", run: () => __h.click("#filter") },
  { name: "switch to effect rows", run: () => __h.click("#effect") },
  { name: "effect rows: filter to 1/9", run: () => __h.click("#filter") },
  { name: "effect rows: back to all", run: () => __h.click("#filter") },
];
