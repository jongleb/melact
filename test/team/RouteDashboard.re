/* A route behind React.lazy: a component with state and a label, loaded by a dynamic import (Routes). */
[@react.component]
let make = (~title: string, ~note=?) => {
  let (count, setCount) = React.useState(() => 0);
  <section className="route-dashboard">
    <h2> {React.string(title ++ Option.value(note, ~default=""))} </h2>
    <button className="route-count" onClick={_ => setCount(c => c + 1)}> {React.int(count)} </button>
  </section>;
};
