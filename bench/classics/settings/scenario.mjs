export default [
  { name: "switch through 12 tabs", run: () => __h.clickEach(".tab") },
  { name: "expand all in a tab", run: () => __h.click(".tab-panel:not([hidden]) .expand-all") },
  { name: "collapse all in a tab", run: () => __h.click(".tab-panel:not([hidden]) .collapse-all") },
  { name: "expand all again", run: () => __h.click(".tab-panel:not([hidden]) .expand-all") },
  { name: "toggle 50 settings", run: () => __h.repeat(50, (count) => __h.click(".tab-panel:not([hidden]) .toggle-input", count)) },
  { name: "type a search query", run: () => __h.type("#search", "mouse") },
  { name: "clear the search", run: () => __h.click("#clear-search") },
  {
    name: "reset 5 sections",
    run: () => __h.repeat(5, () => __h.click(".tab-panel:not([hidden]) .reset-section:not([disabled])", 0)),
  },
  {
    name: "change 20 selects",
    run: () =>
      __h.repeat(20, (count) => {
        const select = __h.one(".tab-panel:not([hidden]) .choice-input", count);
        const value = select.options[(select.selectedIndex + 1) % select.options.length].value;
        __h.input(select, value);
        select.dispatchEvent(new Event("change", { bubbles: true }));
      }),
  },
  { name: "back to the first tab", run: () => __h.click(".tab", 0) },
];
