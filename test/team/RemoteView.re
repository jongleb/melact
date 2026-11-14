[@react.component]
let make = (~id: string) => {
  let data = Remote.use1(~useLayoutEffect=true, deps => "data " ++ deps[0], [|id|]);
  let (shown, setShown) = React.useState(() => false);
  <p className="remote" onClick={_ => setShown(was => !was)}>
    {React.string(
       switch (data) {
       | Some(text) => text
       | None => "loading"
       },
     )}
    {React.string(shown ? " shown" : " hidden")}
  </p>;
};
