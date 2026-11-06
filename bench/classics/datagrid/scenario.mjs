export default [
  { name: "sort by name", run: () => __h.click(".data-grid th.sortable", 1) },
  { name: "sort by amount", run: () => __h.click(".data-grid th.sortable", 5) },
  { name: "sort by joined", run: () => __h.click(".data-grid th.sortable", 6) },
  { name: "reverse sort", run: () => __h.click(".data-grid th.sortable", 6) },
  { name: "type into a filter", run: () => __h.type(".filter-country", "an") },
  { name: "clear the filter", run: () => __h.erase(".filter-country", 2) },
  { name: "select 50 rows", run: () => __h.repeat(50, (count) => __h.click(".row-select", (count * 19) % 1000)) },
  { name: "select all", run: () => __h.click("#select-all") },
  { name: "deselect all", run: () => __h.click("#select-all") },
  { name: "open detail of 10 rows", run: () => __h.repeat(10, (count) => __h.click(".open-detail", count * 37)) },
  { name: "next page x5", run: () => __h.repeat(5, () => __h.click("#next-page")) },
  { name: "close detail", run: () => __h.click("#close-drawer") },
];
