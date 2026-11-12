// A component memoized with a comparator over reason-react's props object, rebound after its definition.
[@react.component]
let make = (~data: array(string), ~id: string) =>
  <ul className={"compared " ++ id}> {React.array(Array.map(item => <li key=item> {React.string(item)} </li>, data))} </ul>;

let arePropsEqual = (prev, next) => prev##id == next##id && prev##data == next##data;

let make = React.memoCustomCompareProps(make, arePropsEqual);
