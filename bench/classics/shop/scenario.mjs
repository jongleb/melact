export default [
  { name: "toggle 5 category filters", run: () => __h.repeat(5, (count) => __h.click(".category-filter", count * 2)) },
  {
    name: "set price range",
    run: async () => {
      await __h.type("#price-min", "50");
      await __h.type("#price-max", "400");
    },
  },
  { name: "rating 3+", run: () => __h.click(".rating-option", 2) },
  {
    name: "sort by price asc and desc",
    run: async () => {
      for (const value of ["price-asc", "price-desc"]) {
        __h.input("#sort", value);
        __h.one("#sort").dispatchEvent(new Event("change", { bubbles: true }));
        await __h.frame();
      }
    },
  },
  { name: "toggle 3 brand filters", run: () => __h.repeat(3, (count) => __h.click(".brand-filter", count * 4 + 1)) },
  { name: "add 30 products to cart", run: () => __h.repeat(30, (count) => __h.click(".add-to-cart", (count * 7) % 40)) },
  { name: "open cart", run: () => __h.click("#open-cart") },
  {
    name: "change quantities 20 times",
    run: () => __h.repeat(20, (count) => __h.click(count % 3 ? ".cart .qty-inc" : ".cart .qty-dec", count % 8)),
  },
  { name: "remove 10 lines", run: () => __h.repeat(10, () => __h.click(".cart .remove", 0)) },
  { name: "close cart", run: () => __h.click("#close-cart") },
  { name: "clear filters", run: () => __h.click("#clear-filters") },
  { name: "add 10 more from the full catalog", run: () => __h.repeat(10, (count) => __h.click(".add-to-cart", count * 101)) },
];
