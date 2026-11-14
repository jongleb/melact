let useToggle = initial => {
  let (on, setOn) = React.useState(() => initial);
  (on, () => setOn(value => !value));
};

module Counter = {
  [@react.component]
  let make = (~label, ~children) => {
    let (count, setCount) = React.useState(() => 0);
    let doubled = React.useMemo1(() => count * 2, [|count|]);
    <div className="counter">
      <button onClick={_ => setCount(count => count + 1)}> {React.string(label)} </button>
      <span> {React.string(Printf.sprintf("%d / %d", count, doubled))} </span>
      children
    </div>;
  };
};

module Panel = {
  [@react.component]
  let make = (~title, ~children) => {
    let (shown, toggle) = useToggle(true);
    <section>
      <button className="panel" onClick={_ => toggle()}> {React.string(title)} </button>
      {shown ? children : React.null}
    </section>;
  };
};
