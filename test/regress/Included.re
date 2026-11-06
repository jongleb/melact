include React;

let useStateValue = initial => useReducer((_ignored, newState) => newState, initial);

[@react.component]
let make = () => {
  let (n, setN) = useState(() => 0);
  let (label, setLabel) = useStateValue("a");
  <button onClick={_ => {setN(n => n + 1); setLabel("b")}}> {React.string(string_of_int(n) ++ label)} </button>;
};
