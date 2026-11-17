/* A tooltip that merges handlers and attributes into whatever element it is given, as floating-ui's
   reference pattern does, with React.cloneElement. */
[@react.component]
let make = (~children, ~label) => {
  let (shown, setShown) = React.useState(() => false);
  <span className="hint">
    {React.cloneElement(
       children,
       {"onClick": _ => setShown(s => !s), "className": shown ? "trigger open" : "trigger", "title": label},
     )}
    {shown ? <span className="hint-label"> {React.string(label)} </span> : React.null}
  </span>;
};
