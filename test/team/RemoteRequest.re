/* The team's unit-call-in-fetch: the closure a data hook only calls in its effect calls a getter with (), as
   their fetches build a request. The component stays pure as with a call that takes an argument; a closure a
   hook calls while it renders keeps the component whole. */

module ViaUse1 = {
  [@react.component]
  let make = (~id: string) => {
    let data = Remote.use1(~useLayoutEffect=true, deps => Other.request() ++ deps[0], [|id|]);
    <p className="request"> {React.string(Option.value(data, ~default="loading"))} </p>;
  };
};

module ViaUse = {
  [@react.component]
  let make = (~id: string) => {
    let data = Remote.use(~useMemo=React.useMemo1, deps => Other.request() ++ Other.describe(deps[0]), [|id|]);
    <p className="request"> {React.string(Option.value(data, ~default="loading"))} </p>;
  };
};

module CalledNow = {
  [@react.component]
  let make = (~id: string) => {
    let label = Remote.useNow(() => Other.request() ++ id);
    <p className="request"> {React.string(label)} </p>;
  };
};
