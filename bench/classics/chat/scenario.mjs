export default [
  {
    name: "type and send 5 messages",
    run: () =>
      __h.repeat(5, async (count) => {
        await __h.type(".channel .composer textarea", `Shipping the release candidate now ${count}..`);
        __h.key(".channel .composer textarea", "Enter");
      }),
  },
  { name: "switch channel x5", run: () => __h.repeat(5, (count) => __h.click(".channel-name", count + 1)) },
  { name: "add reactions to 30 messages", run: () => __h.repeat(30, (count) => __h.click(".add-reaction", count * 37)) },
  { name: "toggle 10 reaction pills", run: () => __h.repeat(10, (count) => __h.click(".reaction", count * 5)) },
  { name: "open thread", run: () => __h.click(".reply-count", 10) },
  {
    name: "reply in thread",
    run: async () => {
      await __h.type(".thread-panel textarea", "Agreed, let us do that after the standup");
      __h.key(".thread-panel textarea", "Enter");
    },
  },
  { name: "close thread", run: () => __h.click(".close-thread") },
  { name: "search messages by typing", run: () => __h.type(".search", "alpha bravo") },
  { name: "clear search", run: () => __h.erase(".search", 11) },
  { name: "back to first channel", run: () => __h.click(".channel-name", 0) },
];
