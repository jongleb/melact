import { useLayoutEffect } from "react";
import { hydrateRoot } from "react-dom/client";
import { App } from "./App.jsx";

const Hydrated = ({ children }) => {
  useLayoutEffect(() => {
    performance.mark("hydrate:end");
    window.__hydrated = true;
  }, []);
  return children;
};

performance.mark("hydrate:start");
const rows = JSON.parse(document.getElementById("model").textContent);
hydrateRoot(
  document.getElementById("main"),
  <Hydrated>
    <App rows={rows} />
  </Hydrated>,
);
