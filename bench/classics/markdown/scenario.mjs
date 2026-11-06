export default [
  { name: "type 60 chars at end", run: () => __h.type("#editor", " and some more words typed at the very end of the document!!") },
  {
    name: "type 30 chars at start",
    run: () =>
      __h.repeat(30, (count) => {
        const editor = document.querySelector("#editor");
        __h.input(editor, "abcdefghijklmnopqrstuvwxyz0123"[count] + editor.value);
      }),
  },
  {
    name: "toolbar 10 times",
    run: () =>
      __h.repeat(10, (count) => {
        const editor = document.querySelector("#editor");
        const start = 200 + count * 450;
        editor.setSelectionRange(start, start + 6);
        __h.click(["#tool-bold", "#tool-italic", "#tool-heading", "#tool-code", "#tool-link"][count % 5]);
      }),
  },
  { name: "preview only", run: () => __h.click("#mode-preview") },
  { name: "editor only", run: () => __h.click("#mode-editor") },
  { name: "split", run: () => __h.click("#mode-split") },
  { name: "scroll editor", run: () => __h.scrollBy("#editor", 400, 15) },
  { name: "click 10 toc entries", run: () => __h.repeat(10, (count) => __h.click(".toc-entry a", count * 5 + 3)) },
  {
    name: "paste 200 lines",
    run: () => {
      const editor = document.querySelector("#editor");
      window.__beforePaste = editor.value;
      const lines = [];
      for (let line = 0; line < 200; line++)
        lines.push(
          line % 20 === 0
            ? `## Pasted section ${line / 20}`
            : line % 7 === 0
              ? `- pasted **item** ${line}`
              : `Pasted line ${line} with *some* \`code\` and [a link](https://example.com/${line}).`,
        );
      __h.input(editor, editor.value + "\n\n" + lines.join("\n"));
    },
  },
  { name: "delete pasted block", run: () => __h.input("#editor", window.__beforePaste) },
];
