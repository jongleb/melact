[@react.component]
let make = (~items: array(string)) =>
  <ul> {items->Array.map(item => <li key=item> {React.string(item)} </li>)->React.array} </ul>;
