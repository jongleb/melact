/* Helpers of another module that return one of their arguments, whose fact melact-ppx records in this .cmi: an
   element or null, one of two elements; and one that wraps its argument in a new element, which has none. */
let renderIfTrue = (flag, element) => flag ? element : React.null;

let either = (flag, yes, no) => flag ? yes : no;

let wrapped = element => <div className="wrapped"> element </div>;
