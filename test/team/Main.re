module App = {
  [@react.component]
  let make = () => {
  let (message, setMessage) = React.useState(() => "hi");
  let (double, setDouble) = React.useState(() => false);
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
    <button className="double" onClick={_ => setDouble(d => !d)}> {React.string("double")} </button>
    <Axis double />
    <LocalGadt selection={double ? Selection.Custom(["a", "b", "c"]) : Selection.Top5} />
    <ClientLinks.shown />
    <Preset />
    <Shadowed a={String.length(message)} />
    <LocalGadt.Whole selection={double ? Selection.Custom(["a", "b"]) : Selection.Top5} />
    <Routes />
    <Spread />
    <Hint label="tip"> <button className="hint-trigger"> {React.string("hint")} </button> </Hint>
    <HintCard> <button className="card-trigger"> {React.string("card")} </button> </HintCard>
    <Tabs trigger={<button className="tabs-next"> {React.string("next")} </button>}>
      {double ? <Tabs.Tab name="a" /> : <Tabs.Tab name="b" />}
      <Tabs.Tab name="c" active=true />
    </Tabs>
    <Framed wrapper=Framed.NoWrapper> <button className="framed-plain"> {React.string("plain")} </button> </Framed>
    <Framed wrapper=Framed.Div> <span className="framed-inner"> {React.string("inner")} </span> </Framed>
    <Menu> <Menu.Item label="first" /> <Menu.Item label="second" /> <Menu.Item label="third" /> </Menu>
    <Shared flag=true seed={Obj.magic("seed")} />
    <Looping start={"label": "start", "next": Js.Nullable.null} />
    <Wide p0={message ++ "0"} p1="1" p2="2" p3={message ++ "3"} p4="4" p5="5" p6={message ++ "6"} p7="7" p8="8" p9={message ++ "9"} p10="10" p11="11" p12={message ++ "12"} p13="13" p14="14" p15={message ++ "15"} p16="16" p17="17" p18={message ++ "18"} p19="19" p20="20" p21={message ++ "21"} p22="22" p23="23" p24={message ++ "24"} p25="25" p26="26" p27={message ++ "27"} p28="28" p29="29" />
  </div>;
  };
};

let mount = root => ReactDOM.Client.render(ReactDOM.Client.createRoot(root), <App />);

