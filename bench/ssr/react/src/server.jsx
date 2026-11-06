import { renderToString } from "react-dom/server";
import { App } from "./App.jsx";

export const prepare = (rows) => rows;
export const render = (rows) => renderToString(<App rows={rows} />);
