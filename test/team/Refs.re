/* Refs given to a JavaScript library bound on ReactDOM.domRef, as the team binds react-dnd's connectors and
   floating-ui's useMergeRefs: the library must get a ref object or a function, as from React. */
[@mel.module "./connector.js"] external connect: ReactDOM.domRef => ReactDOM.domRef = "connect";
[@mel.module "./connector.js"] external merge: array(ReactDOM.domRef) => ReactDOM.domRef = "merge";

[@react.component]
let make = () => {
  let held = React.useRef(Js.Nullable.null);
  let merged = React.useRef(Js.Nullable.null);
  let called = React.useRef("none");
  let (seen, setSeen) = React.useState(() => "before");
  React.useEffect0(() => {
    let present = reference => Js.Nullable.isNullable(reference) ? "empty" : "set";
    setSeen(_ => present(held.current) ++ " " ++ present(merged.current) ++ " " ++ called.current);
    None;
  });
  <div className="refs">
    <div className="refs-connected" ref={held->ReactDOM.Ref.domRef->connect} />
    <span
      className="refs-merged"
      ref={merge([|ReactDOM.Ref.domRef(merged), ReactDOM.Ref.callbackDomRef(_ => called.current = "called")|])}
    />
    <b className="refs-seen"> {React.string(seen)} </b>
  </div>;
};
