import { hydrate } from "svelte";
import App from "./App.svelte";

performance.mark("hydrate:start");
const rows = JSON.parse(document.getElementById("model").textContent);
hydrate(App, { target: document.getElementById("main"), props: { rows } });
performance.mark("hydrate:end");
window.__hydrated = true;
