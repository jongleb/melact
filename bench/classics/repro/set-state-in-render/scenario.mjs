export default [
  { name: "up", run: () => __h.click("#up") },
  { name: "down twice", run: async () => { __h.click("#down"); await __h.frame(); __h.click("#down"); } },
];
