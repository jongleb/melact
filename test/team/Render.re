/* Helpers of another module that return one of their arguments or what a function given to them returns, whose fact
   melact-ppx records in this .cmi: an element or null, one of two elements, a render function's result or null, the
   same through another helper; and one that wraps its argument in a new element, which has none. */
let renderIfTrue = (flag, element) => flag ? element : React.null;

let either = (flag, yes, no) => flag ? yes : no;

let renderDefaultNull = (option, render) =>
  switch (option) {
  | Some(value) => render(value)
  | None => React.null
  };

let renderSome = (option, render) => renderDefaultNull(option, render);

let wrapped = element => <div className="wrapped"> element </div>;
