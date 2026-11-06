export default [
  { name: "add 10 todos", run: () => __h.repeat(10, async (count) => { await __h.type(".new-todo", `task ${count}`); __h.key(".new-todo", "Enter"); }) },
  { name: "toggle 20 todos", run: () => __h.repeat(20, (count) => __h.click(".todo-list .toggle", count * 7)) },
  { name: "filter active", run: () => __h.click(".filters a", 1) },
  { name: "filter completed", run: () => __h.click(".filters a", 2) },
  { name: "filter all", run: () => __h.click(".filters a", 0) },
  { name: "edit one todo", run: async () => { __h.dblclick(".todo-list label", 12); await __h.frame(); await __h.type(".todo-list .edit", " edited"); __h.key(".todo-list .edit", "Enter"); } },
  { name: "toggle all", run: () => __h.click("#toggle-all") },
  { name: "toggle all back", run: () => __h.click("#toggle-all") },
  { name: "delete 20 todos", run: () => __h.repeat(20, () => __h.click(".todo-list .destroy", 3)) },
  { name: "toggle all again", run: () => __h.click("#toggle-all") },
  { name: "clear completed", run: () => __h.click(".clear-completed") },
];
