type kind =
  | Info
  | Error;

[@react.component]
let make = (~label) => {
  let (count, setCount) = React.useState(() => 0);
  let create = (~content, ~kind=Info, ~autoClose) =>
    setCount(n =>
      n
      + String.length(content)
      + (
        switch (kind) {
        | Info => 0
        | Error => 1
        }
      )
      + autoClose
    );
  <button className="notify" onClick={_ => create(~content=label, ~kind=Error, ~autoClose=1)}>
    {React.int(count)}
  </button>;
};
