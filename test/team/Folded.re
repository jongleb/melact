/* A menu that folds its children into a list of variants and clones each item later with isFocused: the variant
   holds a function that clones the child, written where the child still comes from children, not the element. */
type entry =
  | Item({render: bool => React.element})
  | Separator;

module Row = {
  [@react.component]
  let make = (~label: string, ~isFocused=false) =>
    <li className={isFocused ? "folded-row focused" : "folded-row"}> {React.string(label)} </li>;
};

[@react.component]
let make = (~children) => {
  let (focused, setFocused) = React.useState(() => 0);
  let entries =
    Array.fold_left(
      (entries, child) =>
        [Item({render: isFocused => React.cloneElement(child, {"isFocused": isFocused})}), Separator, ...entries],
      [],
      React.Children.toArray(children),
    )
    |> List.rev;
  let items = List.filter(entry => switch (entry) { | Item(_) => true | Separator => false }, entries);
  <ul className="folded">
    {React.array(
       Array.of_list(
         List.mapi(
           (index, entry) =>
             switch (entry) {
             | Item({render}) => render(index == focused)
             | Separator => React.null
             },
           items,
         ),
       ),
     )}
    <button className="folded-next" onClick={_ => setFocused(f => (f + 1) mod List.length(items))}> {React.string("next")} </button>
  </ul>;
};
