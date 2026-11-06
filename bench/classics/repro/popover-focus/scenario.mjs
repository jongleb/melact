export default [
  { name: "open+close x20 plain", run: () => __h.repeat(20, async () => { __h.click("#plain"); await __h.frame(); __h.click(".close"); }) },
  { name: "open+close x20 measure", run: () => __h.repeat(20, async () => { __h.click("#measure"); await __h.frame(); __h.click(".close"); }) },
  { name: "open+close x20 focus", run: () => __h.repeat(20, async () => { __h.click("#focus"); await __h.frame(); __h.click(".close"); }) },
  { name: "open+close x20 both", run: () => __h.repeat(20, async () => { __h.click("#both"); await __h.frame(); __h.click(".close"); }) },
  { name: "open both", run: () => __h.click("#both") },
];
