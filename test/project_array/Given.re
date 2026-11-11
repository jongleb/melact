[@react.component]
let make = (~items: array(string), ~row: string => React.element) => <ul> {items->Array.map(row)->React.array} </ul>;
