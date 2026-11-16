[@react.component]
let make = () => <div className="bare"> {React.string("bare")} </div>;

module Inner = {
  [@react.component]
  let make = () => <span className="bare-inner" />;
};
