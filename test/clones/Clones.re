/* Every way an element reaches React.cloneElement, driven by clones.test.mjs: each form clones its element once per
   plan, the clone of the previous clone after the first, so random plans check merging, overriding and clones of
   clones; the element's own props change between renders; some forms show the props a library reads. */
type size =
  | Small
  | Medium
  | Large;

/* A props object written by the test. */
type plan;

/* An element's props as libraries read them, children and functions left out, keys sorted. */
let described: React.element => string = [%raw
  {|function (element) {
      var props = element.props, shown = {};
      Object.keys(props).sort().forEach(function (key) {
        if (key !== "children" && typeof props[key] !== "function") shown[key] = props[key];
      });
      return JSON.stringify(shown);
    }|}
];

module Leaf = {
  [@react.component]
  let make = (~label: string, ~size: size=Small, ~tone: option(string)=?, ~count: int=0) =>
    <span
      className={
        "leaf "
        ++ (
          switch (size) {
          | Small => "s"
          | Medium => "m"
          | Large => "l"
          }
        )
      }
      title=?tone>
      {React.string(label ++ string_of_int(count))}
    </span>;
};

module ByLabel = {
  [@react.component]
  let make = (~plans: array(plan), ~children) => {
    let cloned = Array.fold_left((element, plan) => React.cloneElement(element, plan), children, plans);
    <div className="by-label"> cloned <span className="props"> {React.string(described(children) ++ " " ++ described(cloned))} </span> </div>;
  };
};

module Forward = {
  [@react.component]
  let make = (~plans, ~children) => <section className="forward"> <ByLabel plans> children </ByLabel> </section>;
};

module Mapped = {
  [@react.component]
  let make = (~plans: array(plan), ~children) =>
    <div className="mapped">
      {React.Children.map(children, child => Array.fold_left((element, plan) => React.cloneElement(element, plan), child, plans))}
    </div>;
};

module Only = {
  [@react.component]
  let make = (~plans: array(plan), ~trigger) => {
    let only = React.Children.only(trigger);
    <div className="only"> {Array.fold_left((element, plan) => React.cloneElement(element, plan), only, plans)} </div>;
  };
};

module Local = {
  [@react.component]
  let make = (~plans: array(plan), ~own: string) => {
    let leaf = <Leaf label=own tone=own />;
    let host = <b className="local" title=own> {React.string(own)} </b>;
    <div className="local">
      {Array.fold_left((element, plan) => React.cloneElement(element, plan), leaf, plans)}
      {Array.fold_left((element, plan) => React.cloneElement(element, plan), host, plans)}
      {Array.fold_left((element, plan) => React.cloneElement(element, plan), <u title=own />, plans)}
    </div>;
  };
};

module Branch = {
  [@react.component]
  let make = (~plans: array(plan), ~wrap: int, ~children) => {
    let element =
      switch (wrap mod 3) {
      | 0 => children
      | 1 => <i className="wrap"> children </i>
      | _ => <Leaf label="branch" count=wrap />
      };
    let cloned = Array.fold_left((element, plan) => React.cloneElement(element, plan), element, plans);
    <div className="branch"> cloned <span className="props"> {React.string(described(cloned))} </span> </div>;
  };
};

/* What the test changes between renders. */
type state = {
  .
  "plans": array(plan),
  "own": string,
  "wrap": int,
  "size": int,
};

module App = {
  [@react.component]
  let make = (~state: state) => {
    let plans = state##plans;
    let own = state##own;
    let size =
      switch (state##size mod 3) {
      | 0 => Small
      | 1 => Medium
      | _ => Large
      };
    <div className="clones">
      <ByLabel plans> <Leaf label=own size /> </ByLabel>
      <ByLabel plans> <b className="host" title=own> {React.string(own)} </b> </ByLabel>
      <ByLabel plans> {state##wrap mod 2 == 0 ? <Leaf label=own tone="t" /> : <i title=own />} </ByLabel>
      <Forward plans> <Leaf label=own count={state##wrap} /> </Forward>
      <Mapped plans> <Leaf label=own /> <em title=own /> <Leaf label="second" size /> </Mapped>
      <Only plans trigger={<button className="trigger" title=own> {React.string(own)} </button>} />
      <Local plans own />
      <Branch plans wrap={state##wrap}> <Leaf label=own size /> </Branch>
    </div>;
  };
};

let mount = root => {
  let client = ReactDOM.Client.createRoot(root);
  state => ReactDOM.Client.render(client, <App state />);
};
