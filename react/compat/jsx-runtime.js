// npm's "react/jsx-runtime", implemented on Melact's runtime.
import * as Element from "./element.mjs";

export const Fragment = Element.Mark.fragment;
export const jsx = (type, props, key) => Element.jsx(type, props, key);
export const jsxs = jsx;
export const jsxDEV = jsx;
