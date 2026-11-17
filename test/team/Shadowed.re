// A module named by -hook-modules that includes React and binds npm's useEffect6 itself (Shadow), called from here.
[@react.component]
let make = (~a: int) => {
  let (seen, setSeen) = React.useState(() => 0);
  Shadow.useEffect6(
    () => {
      setSeen(_ => a + 1 + 2 + 3 + 4 + 5);
      None;
    },
    (a, 1, 2, 3, 4, 5),
  );
  let (more, setMore) = Shadow.useState(() => 0);
  <button className="shadowed" onClick={_ => setMore(n => n + 1)}> {React.int(seen + more)} </button>;
};
