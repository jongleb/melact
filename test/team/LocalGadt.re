[@react.component]
let make = (~selection: Selection.selected(string)) => {
  let (count, setCount) = React.useState(() => 0);
  let toOpt: type a. Selection.selected(a) => option(list(a)) =
    fun
    | Top5 => None
    | Custom(values) => Some(values);
  let size: type a. Selection.selected(a) => int =
    selected =>
      switch (selected) {
      | Selection.Top5 => 5
      | Custom(values) => List.length(values)
      };
  let both: 'b. Selection.selected('b) => int = selected => size(selected) * 2;
  <button className="gadt" onClick={_ => setCount(n => n + 1)}>
    {React.int(count + Belt.Option.mapWithDefault(toOpt(selection), 0, List.length) + size(Selection.Custom([1, 2])) + both(Selection.Top5))}
  </button>;
};

module Whole = {
  [@react.component]
  let make = (~selection: Selection.selected(string)) => {
    let (count, setCount) = React.useState(() => 0);
    module Base = {
      let start = 10;
    };
    let toOpt: type a. Selection.selected(a) => option(list(a)) =
      fun
      | Top5 => None
      | Custom(values) => Some(values);
    let label = string_of_int(Base.start + count + Belt.Option.mapWithDefault(toOpt(selection), 0, List.length));
    <button className="gadt-whole" onClick={_ => setCount(n => n + 1)}> {React.string(label)} </button>;
  };
};
