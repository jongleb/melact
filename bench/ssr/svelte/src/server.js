import { render as renderSvelte } from "svelte/server";
import App from "./App.svelte";

export const prepare = (rows) => ({ rows });
export const render = (props) => renderSvelte(App, { props }).body;
