// npm's "react/jsx-runtime", implemented on Melact's runtime.
import * as Api from "./api.mjs";

export const Fragment = Api.fragment;
export const jsx = (type, props, key) => Api.jsx(type, props, key);
export const jsxs = jsx;
export const jsxDEV = jsx;
