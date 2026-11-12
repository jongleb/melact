[@react.component]
let make = (~message: string) => <p> {React.string(message)} </p>;

let make = React.memo(make);
