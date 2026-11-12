// A page that opens TosT locally around top-level JSX, as the team's TermsOfServiceUSAT does.
let content =
  TosT.(
    <>
      {title("Terms")}
      <a className="tos" href={f("usat")}> {React.string("terms")} </a>
      {note("Read", <b> {React.string("all")} </b>)}
    </>
  );

let block = {
  open TosT;
  <a className="privacy" href={f("privacy")}> {React.string("privacy")} </a>;
};
