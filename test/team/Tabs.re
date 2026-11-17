/* Clones of a label other than children (trigger, through React.Children.only) and of children through
   React.Children.toArray and Array.mapi, given literals in both branches of a conditional. */
module Tab = {
  [@react.component]
  let make = (~name, ~active=false) => <span className={active ? "tab active" : "tab"}> {React.string(name)} </span>;
};

[@react.component]
let make = (~trigger, ~children) => {
  let (active, setActive) = React.useState(() => 0);
  let only = React.Children.only(trigger);
  <div className="tabs">
    {React.cloneElement(only, {"onClick": _ => setActive(a => a + 1)})}
    {React.array(
       Array.mapi(
         (index, tab) => React.cloneElement(tab, {"active": index == active mod 3, "name": "tab" ++ string_of_int(index)}),
         React.Children.toArray(children),
       ),
     )}
  </div>;
};



