export default [
  { name: "upvote 30 stories", run: () => __h.repeat(30, (count) => __h.click(".votearrow", count * 9)) },
  { name: "open a story", run: () => __h.click(".comments-link", 2) },
  { name: "collapse 50 comments", run: () => __h.repeat(50, (count) => __h.click(".togg", count * 7)) },
  { name: "expand them back", run: () => __h.repeat(50, () => { if (__h.count(".togg.collapsed") > 0) __h.click(".togg.collapsed", 0); }) },
  { name: "collapse all top-level", run: () => __h.click("#collapse-top") },
  { name: "expand all top-level", run: () => __h.click("#expand-top") },
  { name: "reply to a comment", run: async () => { __h.click(".reply-link", 5); await __h.frame(); await __h.type(".comtr .reply-input", "I think this is right, and here is why."); __h.click(".comtr .reply-submit"); } },
  { name: "back to front page", run: () => __h.click(".hn-home") },
  { name: "more", run: () => __h.click(".morelink") },
  { name: "more again", run: () => __h.click(".morelink") },
  { name: "hide 10 stories", run: () => __h.repeat(10, (count) => __h.click(".hide-link", count * 3)) },
  { name: "unvote 10", run: () => __h.repeat(10, () => __h.click(".unvote", 0)) },
];
