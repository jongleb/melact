// A library that takes refs as React gives them, like react-dnd's connectors (a ref object, else a DOM node) and
// floating-ui's useMergeRefs (ref objects and functions merged into one function).
export function connect(target) {
  if (target !== null && typeof target === "object" && "current" in target) return target;
  if (typeof target === "function") return target;
  target.addEventListener("dragstart", () => {});
  return target;
}

export function merge(refs) {
  return (node) =>
    refs.forEach((ref) => {
      if (typeof ref === "function") ref(node);
      else if (ref !== null) ref.current = node;
    });
}
