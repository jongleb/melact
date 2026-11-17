/* Routes split by React.lazy as the team's shell writes it: a binding to npm's lazy, a dynamic import of each
   route's make, rendered by React.createElement inside React.Suspense, with a props object or makeProps. */
[@mel.module "react"]
external lazy_: (unit => Js.Promise.t({. "default": React.component('props)})) => React.component('props) = "lazy";

let chunk = load => lazy_(() => load() |> Js.Promise.then_(make => Js.Promise.resolve({"default": make})));

let dashboard = chunk(() => Js.import(RouteDashboard.make));
let settings = chunk(() => Js.import(RouteSettings.make));

module Lazy = {
  [@react.component]
  let make = (~title) => React.createElement(dashboard, RouteDashboard.makeProps(~title, ~note="?", ()));
};

[@react.component]
let make = () => {
  let (route, setRoute) = React.useState(() => `Dashboard);
  let (title, setTitle) = React.useState(() => "Board");
  <div className="routes">
    <button className="route-switch" onClick={_ => setRoute(r => r == `Dashboard ? `Settings : `Dashboard)}>
      {React.string("switch")}
    </button>
    <button className="route-title" onClick={_ => setTitle(t => t ++ "!")}> {React.string("title")} </button>
    <React.Suspense fallback={<span className="route-loading"> {React.string("loading")} </span>}>
      {switch (route) {
       | `Dashboard => React.createElement(dashboard, RouteDashboard.makeProps(~title, ()))
       | `Settings => React.createElement(settings, Obj.magic(Js.Obj.empty()))
       }}
      {React.createElement(dashboard, Obj.magic({"title": title ++ " raw", "note": "?"}))}
      <Lazy title={title ++ " jsx"} />
    </React.Suspense>
  </div>;
};
