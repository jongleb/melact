/* The team's data hook, in the shape of toolkit's UseRemoteData (and its WithAbort): flags named like hooks,
   React's useMemo passed in as a parameter, the effect hook chosen by a flag, and a ref made by a call on
   every render, of which only the first is kept. */

let makeController = () => ref(false);

let use = (~skip=false, ~useLayoutEffect=false, ~useMemo: (unit => 'deps, 'deps) => 'memoDeps, fetch, dependencies) => {
  let (data, setData) = React.useState(() => None);
  let memoDeps = useMemo(() => dependencies, dependencies);
  let controller = React.useRef(makeController());
  let useEffect2 = useLayoutEffect ? React.useLayoutEffect2 : React.useEffect2;
  useEffect2(
    () => {
      if (!skip) {
        setData(_ => Some(fetch(memoDeps)));
      };
      Some(
        () => {
          controller.current := true;
          controller.current = makeController();
        },
      );
    },
    (memoDeps, skip),
  );
  data;
};

let use1 = (~skip=?, ~useLayoutEffect=?, fetch, dependencies) =>
  use(~skip?, ~useLayoutEffect?, ~useMemo=React.useMemo1, fetch, dependencies);
