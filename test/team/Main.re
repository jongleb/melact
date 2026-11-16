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
    <RemoteRequest.ViaUse1 id=message />
    <RemoteRequest.ViaUse id=message />
    <RemoteRequest.CalledNow id=message />
    <WhenChanged value=message />
    <Modal isOpen={String.length(message) mod 2 == 0} />
    <Chained label=message />
    <Bare />
    <Bare.Inner />
    <Tooltip.Provider value=3> <Tooltip /> </Tooltip.Provider>
    <Interpolated id=message />
    <Rows items=[|{Item.name: message, value: "v1"}, {Item.name: "n2", value: message}|] />
    <Notify label=message />
    <Shared flag=true seed={Obj.magic("seed")} />
    <Looping start={"label": "start", "next": Js.Nullable.null} />
    <Wide p0={message ++ "0"} p1="1" p2="2" p3={message ++ "3"} p4="4" p5="5" p6={message ++ "6"} p7="7" p8="8" p9={message ++ "9"} p10="10" p11="11" p12={message ++ "12"} p13="13" p14="14" p15={message ++ "15"} p16="16" p17="17" p18={message ++ "18"} p19="19" p20="20" p21={message ++ "21"} p22="22" p23="23" p24={message ++ "24"} p25="25" p26="26" p27={message ++ "27"} p28="28" p29="29" />
  </div>;
  };
};

let mount = root => ReactDOM.Client.render(ReactDOM.Client.createRoot(root), <App />);
