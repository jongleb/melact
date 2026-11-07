export default [
  {
    name: "fill account (5 fields)",
    run: async () => {
      const fill = async (name, text) => {
        __h.focus(`#field-${name}`);
        await __h.type(`#field-${name}`, text);
        __h.blur(`#field-${name}`);
        await __h.frame();
      };
      await fill("username", "gleb");
      await fill("email", "gleb@example.com");
      await fill("password", "secret12");
      await fill("password_confirm", "secret1");
      await fill("referral", "a friend");
    },
  },
  { name: "next with errors", run: () => __h.click("#next") },
  {
    name: "fix errors, next",
    run: async () => {
      __h.focus("#field-password_confirm");
      await __h.type("#field-password_confirm", "2");
      __h.blur("#field-password_confirm");
      { __h.input("#field-question", "Birth city"); __h.one("#field-question").dispatchEvent(new Event("change", { bubbles: true })); }
      await __h.frame();
      __h.focus("#field-answer");
      await __h.type("#field-answer", "Berlin");
      __h.blur("#field-answer");
      await __h.frame();
      __h.click("#next");
    },
  },
  {
    name: "fill profile, next",
    run: async () => {
      const fill = async (name, text) => {
        __h.focus(`#field-${name}`);
        await __h.type(`#field-${name}`, text);
        __h.blur(`#field-${name}`);
        await __h.frame();
      };
      await fill("first_name", "Gleb");
      await fill("last_name", "Example");
      await fill("display_name", "gleb");
      await fill("birth_year", "1990");
      await fill("phone", "0123456789");
      await fill("company", "Melact");
      await fill("job_title", "Engineer");
      await fill("bio", "Writes compilers.");
      __h.click('input[name="pronouns"]', 0);
      { __h.input("#field-timezone", "CET"); __h.one("#field-timezone").dispatchEvent(new Event("change", { bubbles: true })); }
      await __h.frame();
      __h.click("#next");
    },
  },
  {
    name: "fill address, next",
    run: async () => {
      const fill = async (name, text) => {
        __h.focus(`#field-${name}`);
        await __h.type(`#field-${name}`, text);
        __h.blur(`#field-${name}`);
        await __h.frame();
      };
      await fill("billing_street", "Main street 1");
      await fill("billing_city", "Berlin");
      await fill("billing_postal", "10115");
      { __h.input("#field-billing_country", "Germany"); __h.one("#field-billing_country").dispatchEvent(new Event("change", { bubbles: true })); }
      __h.click("#field-ship_same");
      await __h.frame();
      await fill("shipping_street", "Side street 2");
      await fill("shipping_city", "Hamburg");
      await fill("shipping_postal", "20095");
      { __h.input("#field-shipping_country", "Germany"); __h.one("#field-shipping_country").dispatchEvent(new Event("change", { bubbles: true })); }
      __h.click("#field-gift");
      await __h.frame();
      await fill("gift_message", "Enjoy!");
      __h.click("#next");
    },
  },
  { name: "toggle 100 checkboxes", run: () => __h.repeat(100, (count) => __h.click(".pref-grid .check-input", count * 2)) },
  { name: "select all in a group", run: () => __h.click(".select-all", 3) },
  {
    name: "display prefs, next",
    run: async () => {
      { __h.input("#field-theme", "Dark"); __h.one("#field-theme").dispatchEvent(new Event("change", { bubbles: true })); }
      await __h.frame();
      { __h.input("#field-digest", "Weekly"); __h.one("#field-digest").dispatchEvent(new Event("change", { bubbles: true })); }
      await __h.frame();
      __h.click("#next");
    },
  },
  {
    name: "fill payment, review",
    run: async () => {
      const fill = async (name, text) => {
        __h.focus(`#field-${name}`);
        await __h.type(`#field-${name}`, text);
        __h.blur(`#field-${name}`);
        await __h.frame();
      };
      await fill("card_name", "Gleb Example");
      await fill("card_number", "4242424242424242");
      { __h.input("#field-card_month", "7"); __h.one("#field-card_month").dispatchEvent(new Event("change", { bubbles: true })); }
      { __h.input("#field-card_year", "2029"); __h.one("#field-card_year").dispatchEvent(new Event("change", { bubbles: true })); }
      await fill("card_cvc", "123");
      __h.click("#field-terms");
      await __h.frame();
      __h.click("#next");
    },
  },
  {
    name: "back to step 1, edit",
    run: async () => {
      __h.click(".pill-button", 0);
      await __h.frame();
      __h.focus("#field-username");
      await __h.type("#field-username", "_k");
      __h.blur("#field-username");
    },
  },
  { name: "jump to review", run: () => __h.click(".pill-button", 5) },
  { name: "submit", run: () => __h.click("#submit") },
];
