/* Calls Previous.whenChanged, a hook by its fact from Previous.cmi, directly in its render. */

[@react.component]
let make = (~isOpen) => {
  let wasOpen = Previous.whenChanged(isOpen);
  <div className="modal"> {React.string((isOpen ? "open" : "closed") ++ (wasOpen ? " was open" : " was closed"))} </div>;
};
