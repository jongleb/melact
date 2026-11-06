open React;

module Opened = {
  [@react.component]
  let make = () => {
    let (n, setN) = useState(() => 0);
    <button onClick={_ => setN(n => n + 1)}> {React.string(string_of_int(n))} </button>;
  };
};

module Hooks = {
  include React;
};

module Wrapped = {
  [@react.component]
  let make = () => {
    let (n, setN) = Hooks.useState(() => 10);
    let (m, setM) = MyHooks.useState(() => 20);
    let (k, setK) = React.(useState(() => 30));
    <button onClick={_ => {setN(n => n + 1); setM(m => m + 1); setK(k => k + 1)}}>
      {React.string(Printf.sprintf("%d %d %d", n, m, k))}
    </button>;
  };
};

let usePrevious = value => {
  let valueRef = React.useRef(value);
  React.useEffect1(() => {valueRef.current = value; None}, [|value|]);
  valueRef.current;
};

module Previous = {
  [@react.component]
  let make = (~count: int, ~label: string) => {
    let lastCount = usePrevious(count);
    let lastLabel = usePrevious(label);
    <p> {React.string(string_of_int(lastCount) ++ lastLabel)} </p>;
  };
};

module Inner = {
  [@react.component]
  let make = (~text: string) => <div dangerouslySetInnerHTML={"__html": text} />;
};

type props = {a: int};

module Own = {
  [@react.component]
  let make = (~x: int) => <div> {React.string(string_of_int(x))} </div>;
};

type domRef = ReactDOM.Ref.currentDomRef;

let seen = ref("");

module Referred = {
  [@react.component]
  let make = () => {
    let input: domRef = React.useRef(Js.Nullable.null);
    React.useEffect0(() => {
      seen := Js.Nullable.toOption(input.current)->Option.fold(~none="none", ~some=_ => "input");
      None;
    });
    <input ref={ReactDOM.Ref.domRef(input)} />;
  };
};
