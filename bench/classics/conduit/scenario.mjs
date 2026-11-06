export default [
  { name: "favorite 20 articles", run: () => __h.repeat(20, (count) => __h.click(".article-preview .btn-favorite", count * 11)) },
  { name: "filter by tag", run: () => __h.click(".tag-list-popular .tag-pill", 3) },
  { name: "switch to your feed", run: () => __h.click(".feed-toggle .nav-link", 0) },
  { name: "switch to global feed", run: () => __h.click(".feed-toggle .nav-link", 1) },
  { name: "open article", run: () => __h.click(".article-preview .preview-link", 4) },
  { name: "add 5 comments", run: () => __h.repeat(5, async (count) => { await __h.type(".comment-input", `Great read, thanks for writing it up ${count}`); __h.click(".btn-post"); }) },
  { name: "favorite and follow", run: async () => { __h.click(".article-page .btn-favorite"); await __h.frame(); __h.click(".btn-follow"); } },
  { name: "delete 20 comments", run: () => __h.repeat(20, () => __h.click(".comment-delete", 0)) },
  { name: "back to feed", run: () => __h.click(".nav-home") },
  { name: "next page", run: () => __h.click(".pagination .page-link", 1) },
  { name: "last page", run: () => __h.click(".pagination .page-link", 2) },
  { name: "your feed after follow", run: () => __h.click(".feed-toggle .nav-link", 0) },
];
