// What server-reason-react's ppx writes on the Melange side for [@react.client.component]: a make_client that
// hands the component a props object of its own through React.createElement, three times in one file.
module Link = {
  [@react.component]
  let make = (~url: string, ~label: option(string)=?) =>
    <a className="client-link" href=url> {React.string(Option.value(label, ~default=url))} </a>;

  let make_client = props => React.createElement(make, {"url": "/rsc" ++ props##url, "label": props##label});
};

module Badge = {
  [@react.component]
  let make = (~count: int) => {
    let (shown, setShown) = React.useState(() => count);
    <button className="client-badge" onClick={_ => setShown(n => n + 1)}> {React.int(shown)} </button>;
  };

  let make_client = props => React.createElement(make, {"count": props##count * 10});
};

[@react.component]
let make = (~title: string) => <h3 className="client-title"> {React.string(title)} </h3>;

let make_client = props => React.createElement(make, {"title": String.uppercase_ascii(props##title)});

[@react.component]
let shown = () =>
  <div className="clients">
    {Link.make_client({"url": "/a", "label": Some("A")})}
    {Link.make_client({"url": "/b", "label": None})}
    {Badge.make_client({"count": 4})}
    {make_client({"title": "clients"})}
  </div>;
