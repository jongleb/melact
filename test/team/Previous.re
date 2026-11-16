/* The team's whenChanged, named as a plain function: under -typed it gets a hook fact from its body. */

let whenChanged = value => {
  let valueRef = React.useRef(value);
  React.useEffect1(
    () => {
      valueRef.current = value;
      None;
    },
    [|value|],
  );
  valueRef.current;
};
