import { createElement as h, memo, useReducer } from "react";
import { createRoot } from "react-dom/client";

const adjectives = ["pretty", "large", "big", "small", "tall", "short", "long", "handsome", "plain", "quaint", "clean", "elegant", "easy", "angry", "crazy", "helpful", "mushy", "odd", "unsightly", "adorable", "important", "inexpensive", "cheap", "expensive", "fancy"];
const colours = ["red", "yellow", "blue", "green", "pink", "brown", "purple", "brown", "white", "black", "orange"];
const nouns = ["table", "chair", "house", "bbq", "desk", "car", "pony", "cookie", "sandwich", "burger", "pizza", "mouse", "keyboard"];

const random = (max) => Math.round(Math.random() * 1000) % max;

let nextId = 1;
const buildData = (count) => {
  const data = new Array(count);
  for (let i = 0; i < count; i++)
    data[i] = { id: nextId++, label: `${adjectives[random(adjectives.length)]} ${colours[random(colours.length)]} ${nouns[random(nouns.length)]}` };
  return data;
};

const initialState = { data: [], selected: 0 };

const listReducer = (state, action) => {
  const { data, selected } = state;
  switch (action.type) {
    case "RUN":
      return { data: buildData(1000), selected: 0 };
    case "RUN_LOTS":
      return { data: buildData(10000), selected: 0 };
    case "ADD":
      return { data: data.concat(buildData(1000)), selected };
    case "UPDATE": {
      const newData = data.slice(0);
      for (let i = 0; i < newData.length; i += 10) {
        const r = newData[i];
        newData[i] = { id: r.id, label: r.label + " !!!" };
      }
      return { data: newData, selected };
    }
    case "CLEAR":
      return { data: [], selected: 0 };
    case "SWAP_ROWS": {
      const newdata = [...data];
      if (data.length > 998) {
        const d1 = newdata[1];
        newdata[1] = newdata[998];
        newdata[998] = d1;
      }
      return { data: newdata, selected };
    }
    case "REMOVE": {
      const idx = data.findIndex((d) => d.id === action.id);
      return { data: [...data.slice(0, idx), ...data.slice(idx + 1)], selected };
    }
    case "SELECT":
      return { data, selected: action.id };
    default:
      return state;
  }
};

const Row = memo(
  ({ selected, item, dispatch }) =>
    h("tr", { className: selected ? "danger" : "" },
      h("td", { className: "col-md-1" }, item.id),
      h("td", { className: "col-md-4" }, h("a", { onClick: () => dispatch({ type: "SELECT", id: item.id }) }, item.label)),
      h("td", { className: "col-md-1" },
        h("a", { onClick: () => dispatch({ type: "REMOVE", id: item.id }) },
          h("span", { className: "glyphicon glyphicon-remove", "aria-hidden": "true" }))),
      h("td", { className: "col-md-6" })),
  (prev, next) => prev.selected === next.selected && prev.item === next.item,
);

const Button = ({ id, cb, title }) =>
  h("div", { className: "col-sm-6 smallpad" },
    h("button", { type: "button", className: "btn btn-primary btn-block", id, onClick: cb }, title));

const Jumbotron = memo(
  ({ dispatch }) =>
    h("div", { className: "jumbotron" },
      h("div", { className: "row" },
        h("div", { className: "col-md-6" }, h("h1", null, "React 18 hooks keyed")),
        h("div", { className: "col-md-6" },
          h("div", { className: "row" },
            h(Button, { id: "run", title: "Create 1,000 rows", cb: () => dispatch({ type: "RUN" }) }),
            h(Button, { id: "runlots", title: "Create 10,000 rows", cb: () => dispatch({ type: "RUN_LOTS" }) }),
            h(Button, { id: "add", title: "Append 1,000 rows", cb: () => dispatch({ type: "ADD" }) }),
            h(Button, { id: "update", title: "Update every 10th row", cb: () => dispatch({ type: "UPDATE" }) }),
            h(Button, { id: "clear", title: "Clear", cb: () => dispatch({ type: "CLEAR" }) }),
            h(Button, { id: "swaprows", title: "Swap Rows", cb: () => dispatch({ type: "SWAP_ROWS" }) }))))),
  () => true,
);

const Main = () => {
  const [{ data, selected }, dispatch] = useReducer(listReducer, initialState);
  return h("div", { className: "container" },
    h(Jumbotron, { dispatch }),
    h("table", { className: "table table-hover table-striped test-data" },
      h("tbody", null, data.map((item) => h(Row, { key: item.id, item, selected: selected === item.id, dispatch })))),
    h("span", { className: "preloadicon glyphicon glyphicon-remove", "aria-hidden": "true" }));
};

createRoot(document.getElementById("main")).render(h(Main));
