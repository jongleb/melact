/* A route without props behind React.lazy (Routes), with a state of its own. */
[@react.component]
let make = () => {
  let (on, setOn) = React.useState(() => false);
  <button className="route-settings" onClick={_ => setOn(o => !o)}> {React.string(on ? "on" : "off")} </button>;
};
