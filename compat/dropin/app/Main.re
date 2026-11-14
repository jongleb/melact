module App = {
  [@react.component]
  let make = () => {
    let (dark, toggleDark) = Widgets.useToggle(false);
    <div className={dark ? "dark" : "light"}>
      <button className="theme" onClick={_ => toggleDark()}> {React.string("theme")} </button>
      <Widgets.Panel title="first">
        <Widgets.Counter label="add"> {React.string(dark ? "night" : "day")} </Widgets.Counter>
      </Widgets.Panel>
      <Widgets.Panel title="second">
        <Widgets.Counter label="more"> <em> {React.string("inside")} </em> </Widgets.Counter>
      </Widgets.Panel>
    </div>;
  };
};

switch (ReactDOM.querySelector("#root")) {
| Some(root) => ReactDOM.Client.render(ReactDOM.Client.createRoot(root), <App />)
| None => ()
};
