module App = {
  [@react.component]
  let make = () => {
  let (message, setMessage) = React.useState(() => "hi");
  <div>
    <button className="say" onClick={_ => setMessage(m => m ++ "!")}> {React.string("say")} </button>
    <CtorAnnot isActive=true />
    <CtorAnnot isActive=false />
    <Notif message />
    <PatternAnnot />
    <Compared data=[|message, "terms"|] id="c" />
    TosUsat.content
    TosUsat.block
    <Fragile cls={"f-" ++ message} title=message />
    <Styled.Link href="/a" activeStyle=Styled.highlighted label={Styled.twice(message)} />
    <Styled.Link href="/b" label="plain" />
    {Styled.bound(~href="/c", ~activeStyle=Styled.highlighted, ())}
    <RemoteView id=message />
  </div>;
  };
};

let mount = root => ReactDOM.Client.render(ReactDOM.Client.createRoot(root), <App />);
