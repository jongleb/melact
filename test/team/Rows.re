[@react.component]
let make = (~items: array(Item.t)) =>
  <div className="rows">
    {items->Belt.Array.map(({name, value}) => <span key=name> {React.string(value)} </span>)->React.array}
    {items->Belt.Array.map(({name, value}) => <i> {React.string(name ++ value)} </i>)->React.array}
  </div>;
