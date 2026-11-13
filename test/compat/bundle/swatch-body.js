import { createElement } from "react";
import { palette } from "./palette.js";

export function Swatch({ colours }) {
  return createElement("span", { className: "swatch" }, colours === palette ? "one palette" : "two palettes");
}
