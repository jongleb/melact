/* The team's data hook, in the shape of toolkit's UseRemoteData: flags named like hooks, React's useMemo
   passed in as a parameter, and the effect hook chosen by a flag. */

let use = (~skip=false, ~useLayoutEffect=false, ~useMemo: (unit => 'deps, 'deps) => 'memoDeps, fetch, dependencies) => {
  let (data, setData) = React.useState(() => None);
  let memoDeps = useMemo(() => dependencies, dependencies);
  let useEffect2 = useLayoutEffect ? React.useLayoutEffect2 : React.useEffect2;
  useEffect2(
    () => {
      if (!skip) {
        setData(_ => Some(fetch(memoDeps)));
      };
      None;
    },
    (memoDeps, skip),
  );
  data;
};

let use1 = (~skip=?, ~useLayoutEffect=?, fetch, dependencies) =>
  use(~skip?, ~useLayoutEffect?, ~useMemo=React.useMemo1, fetch, dependencies);
