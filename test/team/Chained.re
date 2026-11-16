[@react.component]
let make = (~label) => {
  let first = Middle.value(label);
  <p className="chained"> {React.string(first ++ " now " ++ label)} </p>;
};
