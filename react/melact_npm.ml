external dom_props : 'props -> ReactDOM.domProps = "%identity"
external field : 'props -> string -> 'value Js.undefined = "" [@@mel.get_index]

let present : 'props -> 'props = [%mel.raw {|function (props) { return props == null ? {} : props; }|}]

let tag_of : 'kind -> string Js.undefined =
  [%mel.raw {|function (kind) { return typeof kind === "string" ? kind : undefined; }|}]

let listed : 'value -> React.element array Js.undefined =
  [%mel.raw {|function (value) { return Array.isArray(value) ? value : undefined; }|}]

let called : 'kind -> 'props -> React.element Js.undefined -> React.element =
  [%mel.raw
    {|function (kind, props, children) {
  if (children === undefined) return kind(props);
  return kind(Object.assign({}, props, { children: children }));
}|}]

let keyed element key =
  Option.fold ~none:element
    ~some:(fun key -> React.of_child (Melhole.View.with_key key (React.to_child element)))
    key

let created kind props children =
  let props = present props in
  match Js.Undefined.toOption (tag_of kind) with
  | Some tag ->
      let given =
        match (children, Option.bind (Js.Undefined.toOption (field props "children")) (fun children -> Js.Undefined.toOption (listed children))) with
        | [||], Some inner -> inner
        | given, _ -> given
      in
      ReactDOM.createElement tag ~props:(dom_props props) given
  | None ->
      keyed
        (called kind props
           (match children with
           | [||] -> Js.undefined
           | [| only |] -> Js.Undefined.return only
           | many -> Js.Undefined.return (React.array many)))
        (Js.Undefined.toOption (field props "key"))

let fragment props =
  let children = props##children in
  Option.fold ~none:children ~some:React.array (Js.Undefined.toOption (listed children))
