[@react.component]
let make = (~html) => {
  let (count, setCount) = React.useState(() => 0);
  <div onClick={_ => setCount(c => c + 1)}>
    <span dangerouslySetInnerHTML={"__html": html} />
    {React.int(count)}
  </div>;
};
