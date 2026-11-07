// npm's "react-dom/client", implemented on Melact's runtime.
import * as Dom from "./react_dom.mjs";

export const createRoot = (container, options) => Dom.createRoot(container, options);
export const hydrateRoot = (container, element) => {
  const root = Dom.createRoot(container);
  container.textContent = "";
  root.render(element);
  return root;
};
export default { createRoot, hydrateRoot };
