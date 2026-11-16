let context = React.createContext(0);
module Tip = {
  [@react.component]
  let make = (~renderTooltip: (Js.t({..}), React.element) => React.element) =>
    renderTooltip({"label": "1"}, React.null);
};
[@react.component]
let make = () => {
  let base = React.useContext(context);
  let label = j => string_of_int(j + base);
  <Tip renderTooltip={(props, _default) => React.string(label(int_of_string(props##label)))} />;
};

module Provider = {
  let makeProps = (~value, ~children, ()) => {"value": value, "children": children};
  let make = React.Context.provider(context);
};
