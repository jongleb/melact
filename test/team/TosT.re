// Terms of service shared by several pages: top-level JSX of its own, read by TosUsat through a local open.
let f = path => "/legal/" ++ path;
let title = name => <h2> {React.string(name)} </h2>;
let note = (text, child) => <p className="note"> {React.string(text)} child </p>;
