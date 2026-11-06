export default [
  {
    name: "scroll to bottom 5 times",
    run: async () => {
      const box = __h.one(".feed-scroll");
      for (let round = 0; round < 5; round++) {
        const before = __h.count(".post");
        box.scrollTop = box.scrollHeight;
        for (let wait = 0; wait < 120 && __h.count(".post") === before; wait++) await __h.frame();
        await __h.frame();
      }
    },
  },
  { name: "like 30 posts", run: () => __h.repeat(30, (count) => __h.click(".like-button", count * 23)) },
  { name: "unlike 10 posts", run: () => __h.repeat(10, () => __h.click(".like-button.liked", 0)) },
  {
    name: "hide 20 posts",
    run: () =>
      __h.repeat(20, async (count) => {
        __h.click(".post-menu-button", count * 17);
        await __h.frame();
        await __h.frame();
        __h.click("#portal .menu-hide");
      }),
  },
  {
    name: "open menu, click outside x10",
    run: () =>
      __h.repeat(10, async (count) => {
        __h.click(".post-menu-button", count * 7);
        await __h.frame();
        await __h.frame();
        __h.mouse("mousedown", ".stories");
      }),
  },
  { name: "undo 5 hides", run: () => __h.repeat(5, () => __h.click(".undo", 0)) },
  { name: "scroll through the feed", run: () => __h.scrollBy(".feed-scroll", 900, 30) },
  { name: "scroll back to top", run: () => __h.click("#back-to-top") },
  { name: "write a post", run: async () => { await __h.type(".composer-input", "Lovely weather in Lisbon today!"); __h.key(".composer-input", "Enter"); } },
];
