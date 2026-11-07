// Injected into every page before the app loads. Scenario steps call these through `__h`; they
// dispatch the same DOM events a user's input would, so React and Melact see the same thing.
(() => {
  const one = (target, index = 0) => {
    if (typeof target !== "string") return target;
    const found = document.querySelectorAll(target)[index];
    if (!found) throw new Error(`no element for ${target} [${index}]`);
    return found;
  };
  const all = (selector) => [...document.querySelectorAll(selector)];
  const frame = () => new Promise((done) => requestAnimationFrame(() => done()));
  const tick = () => new Promise((done) => setTimeout(done, 0));
  const setters = new Map();
  const setValue = (element, value) => {
    const proto = Object.getPrototypeOf(element);
    let setter = setters.get(proto);
    if (!setter) {
      setter = Object.getOwnPropertyDescriptor(proto, "value").set;
      setters.set(proto, setter);
    }
    setter.call(element, value);
  };
  const h = {
    one,
    all,
    frame,
    tick,
    count: (selector) => document.querySelectorAll(selector).length,
    click: (target, index) => one(target, index).click(),
    clickAll: (selector, limit = Infinity) => {
      const found = all(selector).slice(0, limit);
      for (const element of found) element.click();
      return found.length;
    },
    async clickEach(selector, limit = Infinity) {
      const found = all(selector).slice(0, limit);
      for (const element of found) {
        element.click();
        await frame();
      }
      return found.length;
    },
    dblclick: (target, index) =>
      one(target, index).dispatchEvent(new MouseEvent("dblclick", { bubbles: true, cancelable: true, view: window })),
    mouse: (type, target, index, init = {}) =>
      one(target, index).dispatchEvent(new MouseEvent(type, { bubbles: true, cancelable: true, view: window, ...init })),
    pointer: (type, target, index, init = {}) =>
      one(target, index).dispatchEvent(new PointerEvent(type, { bubbles: true, cancelable: true, view: window, ...init })),
    input(target, value, index) {
      const element = one(target, index);
      setValue(element, value);
      element.dispatchEvent(new Event("input", { bubbles: true }));
    },
    change(target, value, index) {
      const element = one(target, index);
      setValue(element, value);
      element.dispatchEvent(new Event("change", { bubbles: true }));
    },
    async type(target, text, index) {
      const element = one(target, index);
      const start = element.value;
      for (let length = 1; length <= text.length; length++) {
        h.input(element, start + text.slice(0, length));
        await frame();
      }
    },
    async erase(target, count, index) {
      const element = one(target, index);
      for (let step = 0; step < count && element.value.length > 0; step++) {
        h.input(element, element.value.slice(0, -1));
        await frame();
      }
    },
    key(target, key, index, init = {}) {
      const element = one(target, index);
      element.dispatchEvent(new KeyboardEvent("keydown", { key, bubbles: true, cancelable: true, ...init }));
      element.dispatchEvent(new KeyboardEvent("keyup", { key, bubbles: true, cancelable: true, ...init }));
    },
    focus: (target, index) => one(target, index).focus(),
    blur: (target, index) => one(target, index).blur(),
    scroll(target, top, index) {
      const element = one(target, index);
      element.scrollTop = top;
      element.dispatchEvent(new Event("scroll", { bubbles: false }));
    },
    async scrollBy(target, step, times, index) {
      const element = one(target, index);
      for (let count = 0; count < times; count++) {
        element.scrollTop += step;
        element.dispatchEvent(new Event("scroll", { bubbles: false }));
        await frame();
      }
    },
    drag(from, to, fromIndex, toIndex) {
      const source = one(from, fromIndex);
      const target = one(to, toIndex);
      const data = new DataTransfer();
      source.dispatchEvent(new DragEvent("dragstart", { bubbles: true, cancelable: true, dataTransfer: data }));
      target.dispatchEvent(new DragEvent("dragenter", { bubbles: true, cancelable: true, dataTransfer: data }));
      target.dispatchEvent(new DragEvent("dragover", { bubbles: true, cancelable: true, dataTransfer: data }));
      target.dispatchEvent(new DragEvent("drop", { bubbles: true, cancelable: true, dataTransfer: data }));
      source.dispatchEvent(new DragEvent("dragend", { bubbles: true, cancelable: true, dataTransfer: data }));
    },
    async repeat(times, run) {
      for (let count = 0; count < times; count++) {
        await run(count);
        await frame();
      }
    },
    async settle(limit = 40) {
      let changed = true;
      let rounds = 0;
      const observer = new MutationObserver(() => {
        changed = true;
      });
      observer.observe(document.body, { subtree: true, childList: true, attributes: true, characterData: true });
      const idle = () => new Promise((done) => requestIdleCallback(() => done(), { timeout: 5000 }));
      while (changed && rounds < limit) {
        changed = false;
        await frame();
        await frame();
        await tick();
        if (!changed) await idle();
        rounds++;
      }
      observer.disconnect();
      return { rounds, settled: !changed };
    },
    snapshot(root) {
      const out = [];
      const walk = (node) => {
        if (node.nodeType === 3) out.push(node.data.replace(/&/g, "&amp;").replace(/</g, "&lt;"));
        else if (node.nodeType === 8) out.push(`<!--${node.data}-->`);
        else if (node.nodeType === 1) {
          const attributes = [...node.attributes].map((attribute) => `${attribute.name}="${attribute.value}"`).sort();
          if (node.tagName === "INPUT" || node.tagName === "TEXTAREA" || node.tagName === "SELECT") {
            attributes.push(`:value="${node.value}"`);
            if (node.type === "checkbox" || node.type === "radio") attributes.push(`:checked="${node.checked}"`);
          }
          const tag = node.tagName.toLowerCase();
          out.push(`<${tag}${attributes.map((attribute) => " " + attribute).join("")}>`);
          for (const child of node.childNodes) walk(child);
          out.push(`</${tag}>`);
        }
      };
      for (const child of root.childNodes) walk(child);
      return out.join("");
    },
    errors: [],
  };
  window.__h = h;
  window.addEventListener("error", (event) => h.errors.push(String(event.error?.stack ?? event.message)));
  window.addEventListener("unhandledrejection", (event) => h.errors.push(String(event.reason?.stack ?? event.reason)));
})();
