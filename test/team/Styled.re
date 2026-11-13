/* reason-react's ReactDOM.style and React.callback, as npm bindings type their props. */

let highlighted: ReactDOM.style = ReactDOM.Style.make(~color="red", ());

let twice: React.callback(string, string) = text => text ++ text;

module Link = {
  [@react.component]
  let make = (~href: string, ~activeStyle: option(ReactDOM.style)=?, ~label: string) =>
    switch (activeStyle) {
    | Some(style) => <a className="active" href style> {React.string(label)} </a>
    | None => <a className="plain" href> {React.string(label)} </a>
    };
};

type bound = (~href: string, ~activeStyle: ReactDOM.style=?, unit) => React.element;

let bound: bound = (~href, ~activeStyle=?, ()) => <Link href ?activeStyle label="bound" />;
