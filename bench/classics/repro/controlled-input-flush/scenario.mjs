export default [
  { name: "input then Enter in one task", run: () => { __h.input("#field", "hello"); __h.key("#field", "Enter"); } },
  { name: "input, frame, Enter", run: async () => { __h.input("#field", "world"); await __h.frame(); __h.key("#field", "Enter"); } },
];
