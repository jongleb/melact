export default [
  {
    name: "open/close create modal x5",
    run: () =>
      __h.repeat(5, async () => {
        __h.click("#new-user");
        await __h.frame();
        __h.click(".modal .cancel");
      }),
  },
  {
    name: "submit an invalid form",
    run: async () => {
      __h.click("#new-user");
      await __h.frame();
      __h.click(".modal .submit");
      await __h.frame();
      await __h.type("#user-name", "Al");
      __h.click(".modal .submit");
      await __h.frame();
      await __h.type("#user-email", "amelia.adams1@company.test");
      __h.click(".modal .submit");
      await __h.frame();
      __h.key("#user-email", "Escape");
    },
  },
  {
    name: "create 5 users",
    run: () =>
      __h.repeat(5, async (count) => {
        __h.click("#new-user");
        await __h.frame();
        await __h.type("#user-name", `New Person ${count}`);
        await __h.type("#user-email", `new${count}@example.org`);
        { __h.input("#user-role", count % 2 ? "editor" : "admin"); __h.one("#user-role").dispatchEvent(new Event("change", { bubbles: true })); }
        await __h.frame();
        __h.click(".modal .submit");
      }),
  },
  {
    name: "edit 10 users",
    run: () =>
      __h.repeat(10, async (count) => {
        __h.click(".user-row .edit", count * 4);
        await __h.frame();
        await __h.type("#user-name", " Jr");
        __h.click("#user-enabled");
        await __h.frame();
        __h.click(".modal .submit");
      }),
  },
  {
    name: "delete 10 users",
    run: () =>
      __h.repeat(10, async (count) => {
        __h.click(".user-row .delete", count);
        await __h.frame();
        __h.click(".modal .confirm-delete");
      }),
  },
  { name: "dismiss toasts", run: () => __h.clickEach(".toast .dismiss") },
  { name: "search typing", run: () => __h.type("#search", "ma") },
  { name: "change role filter", run: () => { __h.input("#role-filter", "editor"); __h.one("#role-filter").dispatchEvent(new Event("change", { bubbles: true })); } },
  {
    name: "reset search and filter",
    run: async () => {
      __h.input("#search", "");
      await __h.frame();
      { __h.input("#role-filter", "all"); __h.one("#role-filter").dispatchEvent(new Event("change", { bubbles: true })); }
    },
  },
  { name: "page through 10 pages", run: () => __h.repeat(10, () => __h.click("#next-page")) },
  { name: "toggle show all", run: () => __h.click("#show-all") },
  { name: "toggle paged", run: () => __h.click("#show-all") },
];
