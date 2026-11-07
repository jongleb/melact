// What a user does on the served page once it is hydrated: the mount step is the hydration.
export default [
  { name: "increment x3", run: () => __h.repeat(3, () => __h.click("#increment")) },
  { name: "select a row", run: () => __h.click(".col-md-4 a", 5) },
  { name: "remove a row", run: () => __h.click(".glyphicon-remove", 7) },
  { name: "decrement", run: () => __h.click("#decrement") },
];
