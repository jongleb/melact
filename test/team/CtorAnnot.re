[@react.component]
let make = (~isActive: bool) => {
  let (count, setCount) = React.useState(() => 0);
  let color: Color.t = if (isActive) {Selected} else {Default};
  <button onClick={_ => setCount(n => n + 1)}>
    {React.string(Color.name(color) ++ string_of_int(count))}
  </button>;
};
