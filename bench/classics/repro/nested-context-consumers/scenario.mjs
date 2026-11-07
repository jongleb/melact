export default [
  { name: "bump context of 19,531 nested consumers x3", run: () => __h.repeat(3, () => __h.click("#nested")) },
  { name: "bump context of 19,531 flat consumers x3", run: () => __h.repeat(3, () => __h.click("#flat")) },
];
