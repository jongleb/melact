export default [
  { name: "open x20 portal", run: () => __h.repeat(20, (count) => __h.click(".portal .open", count)) },
  { name: "close x20 portal", run: () => __h.repeat(20, () => __h.click(".menu-close", 0)) },
  { name: "open x20 inline", run: () => __h.repeat(20, (count) => __h.click(".inline .open", count)) },
  { name: "close x20 inline", run: () => __h.repeat(20, () => __h.click(".menu-close", 0)) },
];
