/* Clones of elements written in the same function: a DOM element, a component and both branches of a conditional
   bound by let, a DOM element written in the clone's argument, an element bound by let and given to a component that clones it (Hint), and a prop rebound by a
   switch whose other branch wraps it in a new element. */
type wrapper =
  | NoWrapper
  | Div;

[@react.component]
let make = (~wrapper, ~children) => {
  let (on, setOn) = React.useState(() => false);
  let frame = <iframe title="frame" className="framed-frame" />;
  let tab = <Tabs.Tab name="local" />;
  let mark = on ? <b className="framed-on" /> : <i className="framed-off" />;
  let label = <button className="framed-hint"> {React.string("framed")} </button>;
  let children =
    switch (wrapper) {
    | NoWrapper => children
    | Div => <div className="framed-wrap"> children </div>
    };
  <div className="framed">
    {React.cloneElement(frame, {"loading": "lazy"})}
    {React.cloneElement(tab, {"active": on})}
    {React.cloneElement(mark, {"title": on ? "on" : "off"})}
    {React.cloneElement(<u className="framed-direct" />, {"title": on ? "direct on" : "direct"})}
    <Hint label="framed"> label </Hint>
    {React.cloneElement(children, {"title": on ? "framed on" : "framed off", "onClick": _ => setOn(o => !o)})}
  </div>;
};

/* One branch is a prop, the other an element taken out of an option: the clone stays untraced, since the second
   element's creation site is not known. Not mounted. */
[@alert "-unsupported"]
module Partial = {
  [@react.component]
  let make = (~children, ~fallback) => {
    let shown =
      switch (fallback) {
      | Some(element) => element
      | None => children
      };
    React.cloneElement(shown, {"title": "partial"});
  };
};
