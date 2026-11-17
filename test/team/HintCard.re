/* A component that passes its children on to Hint, which clones them: they reach a clone through it. */
[@react.component]
let make = (~children) => <div className="hint-card"> <Hint label="card"> children </Hint> </div>;
