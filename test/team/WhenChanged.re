/* The team's whenChanged: a function that calls useRef and useEffect1. Named without use it is a compile error,
   as a call of it would be cached like a plain function's; named as a hook it runs on every render. */

let useWhenChanged = (value, onChange) => {
  let previous = React.useRef(value);
  React.useEffect1(
    () => {
      if (previous.current != value) {
        previous.current = value;
        onChange(value);
      };
      None;
    },
    [|value|],
  );
};

[@react.component]
let make = (~value: string) => {
  let (changes, setChanges) = React.useState(() => 0);
  useWhenChanged(value, _ => setChanges(count => count + 1));
  <p className="changes"> {React.string(value ++ " changed " ++ string_of_int(changes))} </p>;
};
