// npm's "react-dom", implemented on Melact's runtime.
import * as Api from "./api.mjs";
import * as Dom from "./react_dom.mjs";

export const version = Api.version;
export const createPortal = (children, container, key) => Dom.createPortal(children, container, key);
export const flushSync = (run) => Dom.flushSync(run);
export const unstable_batchedUpdates = (run, argument) => run(argument);
export const render = (element, container, callback) => Dom.render(element, container, callback);
export const unmountComponentAtNode = (container) => Dom.unmountComponentAtNode(container);
export const findDOMNode = (value) => Dom.findDOMNode(value);

const ReactDOM = { version, createPortal, flushSync, unstable_batchedUpdates, render, unmountComponentAtNode, findDOMNode };
export default ReactDOM;
