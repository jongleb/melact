/* The first link of a chain of plain-named hooks across files: Leaf.value, Middle.value, Chained.make. */

let value = initial => {
  let (shown, _) = React.useState(() => initial);
  shown;
};
