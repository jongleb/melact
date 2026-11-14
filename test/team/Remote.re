/* The team's data hook, in the shape of toolkit's UseRemoteData: flags named like hooks, and React's
   useMemo passed in as a parameter. */

let use = (~skip=false, ~useLayoutEffect=false, ~useMemo: (unit => 'deps, 'deps) => 'memoDeps, fetch, dependencies) => {
  let memoDeps = useMemo(() => dependencies, dependencies);
  let (data, setData) = React.useState(() => None);
  React.useEffect2(
    () => {
      if (!skip) {
        setData(_ => Some(fetch(memoDeps)));
      };
      None;
    },
    (memoDeps, useLayoutEffect),
  );
  data;
};

let use1 = (~skip=?, ~useLayoutEffect=?, fetch, dependencies) =>
  use(~skip?, ~useLayoutEffect?, ~useMemo=React.useMemo1, fetch, dependencies);
