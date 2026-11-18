/* A menu that reads each child's props, as libraries read child.props, to keep the focusable items, then clones
   them with isFocused: children through Children.toArray and Belt.Array.keep or Js.Array.filter, the props a
   component literal and a DOM literal were given, and those of a clone. */
let label: React.element => string = [%raw {|function (child) { return child.props.label === undefined ? "?" : child.props.label }|}];
let disabled: React.element => bool = [%raw {|function (child) { return child.props.disabled === true }|}];
let title: React.element => string = [%raw {|function (child) { return child.props.title === undefined ? "?" : child.props.title }|}];

module Item = {
  [@react.component]
  let make = (~label: string, ~disabled=false, ~isFocused=false) =>
    <span className={isFocused ? "picker-item focused" : disabled ? "picker-item disabled" : "picker-item"}>
      {React.string(label)}
    </span>;
};

[@react.component]
let make = (~children) => {
  let (focused, setFocused) = React.useState(() => 0);
  let items = React.Children.toArray(children)->Belt.Array.keep(child => !disabled(child));
  let shown = Belt.Array.mapWithIndex(items, (index, child) => React.cloneElement(child, {"isFocused": index == focused}));
  <div className="picker">
    {React.array(shown)}
    <button className="picker-next" onClick={_ => setFocused(f => (f + 1) mod Array.length(items))}>
      {React.string(label(items[focused mod Array.length(items)]) ++ "/" ++ label(shown[focused mod Array.length(shown)]))}
    </button>
  </div>;
};

module Hosts = {
  [@react.component]
  let make = (~children) => {
    let kept = Js.Array.filter(~f=child => title(child) != "skip", React.Children.toArray(children));
    <div className="picker-hosts">
      {React.array(Belt.Array.map(kept, child => React.cloneElement(child, {"className": "kept " ++ title(child)})))}
    </div>;
  };
};
