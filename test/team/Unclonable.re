/* Elements given to a label a component clones: a call's result and an if with a call in a branch are reported
   at build time by the alert unclonable (silenced here, the law reads the compiled calls); JSX, React.null in a
   branch, a clone's result, a literal bound by let, a label passed on, JSX the component's hooks memoize and helpers
   that return one of their arguments, from another module or this one, are not; a helper that wraps its argument in a
   new element is.
   Not mounted. */
[@alert "-unclonable"];

module Floating = {
  [@react.component]
  let make = (~children) => React.cloneElement(children, {"title": "floating"});
};

let wrappedChildren = () => <b className="wrapped" />;

let shown = (flag, element) => flag ? element : React.null;

module Caller = {
  [@react.component]
  let make = (~flag) => {
    let (count, setCount) = React.useState(() => 0);
    let local = <em />;
    <div>
      <Floating> {wrappedChildren()} </Floating>
      <Floating> {flag ? wrappedChildren() : <i />} </Floating>
      <Floating> <u /> </Floating>
      <Floating> {flag ? <s /> : React.null} </Floating>
      <Floating> {React.cloneElement(<small />, {"title": "cloned"})} </Floating>
      <Floating> local </Floating>
      <Floating> {Render.renderIfTrue(flag, <em />)} </Floating>
      <Floating> {Render.either(flag, <em />, local)} </Floating>
      <Floating> {Render.wrapped(<em />)} </Floating>
      <Floating> {shown(flag, <strong />)} </Floating>
      <Floating> <button title={string_of_int(count)} onClick={_ => setCount(c => c + 1)} /> </Floating>
    </div>;
  };
};

module Forwarding = {
  [@react.component]
  let make = (~children) => <section> <Floating> children </Floating> </section>;
};
