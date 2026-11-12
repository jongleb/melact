module Ctx = {
  type value = {
    name: string,
    count: int,
  };
  let current = {name: "x", count: 1};
};

[@react.component]
let make = () => {
  let (clicks, setClicks) = React.useState(() => 0);
  let {name, count}: Ctx.value = Ctx.current;
  <button className="pattern" onClick={_ => setClicks(n => n + 1)}>
    {React.string(name ++ string_of_int(count + clicks))}
  </button>;
};
