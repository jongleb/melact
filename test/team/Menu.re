/* A menu that injects props into each item element it is given: React.Children.mapWithIndex and
   React.cloneElement, with a label of the item component the item element did not set. */
module Item = {
  [@react.component]
  let make = (~label, ~isFocused=false, ~onPick=?) =>
    <button
      className={isFocused ? "menu-item focused" : "menu-item"}
      onClick={_ => Option.iter(pick => pick(label), onPick)}>
      {React.string(label)}
    </button>;
};

[@react.component]
let make = (~children) => {
  let (focused, setFocused) = React.useState(() => 0);
  let (picked, setPicked) = React.useState(() => "none");
  <div className="menu">
    {children->React.Children.mapWithIndex((child, index) =>
       React.cloneElement(
         child,
         {"isFocused": index == focused, "onPick": label => {setPicked(_ => label); setFocused(f => f + 1)}},
       )
     )}
    <span className="menu-picked"> {React.string(picked)} </span>
  </div>;
};
