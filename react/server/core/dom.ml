type switch = On | Off

type prop =
  | Attribute of string * string
  | Present of string
  | Number of string * int
  | Value of string
  | Default_value of string
  | Checked of switch
  | Default_checked of switch
  | Selected of switch
  | Style of (string * string) list
  | Inner_html of string

(** What an element's props leave for after its attributes. *)
type later = {
  value : string option;
  default_value : string option;
  checked : switch option;
  default_checked : switch option;
  selected : Melhole_server.marked;
  html : string option;
}

let element tag props children =
  Melhole_server.element (fun writer ->
      Melhole_server.markup writer ("<" ^ tag);
      let later =
        List.fold_left
          (fun later prop ->
            match (prop, tag) with
            | Attribute (name, value), _ ->
                Melhole_server.attribute writer name (Some value);
                later
            | Present name, _ ->
                Melhole_server.attribute writer name (Some "");
                later
            | Number (("cols" | "rows" | "size" | "span"), number), _ when number < 1 -> later
            | Number (name, number), _ ->
                Melhole_server.attribute writer name (Some (string_of_int number));
                later
            | Value value, ("input" | "textarea" | "select") -> { later with value = Some value }
            | Value value, "option" ->
                Melhole_server.attribute writer "value" (Some value);
                { later with value = Some value }
            | Value value, _ ->
                Melhole_server.attribute writer "value" (Some value);
                later
            | Default_value value, _ -> { later with default_value = Some value }
            | Checked checked, "input" -> { later with checked = Some checked }
            | Checked On, _ ->
                Melhole_server.attribute writer "checked" (Some "");
                later
            | Checked Off, _ -> later
            | Default_checked checked, _ -> { later with default_checked = Some checked }
            | Selected On, "option" -> { later with selected = Melhole_server.Marked }
            | Selected Off, "option" -> { later with selected = Melhole_server.Unmarked }
            | Selected On, _ ->
                Melhole_server.attribute writer "selected" (Some "");
                later
            | Selected Off, _ -> later
            | Style declarations, _ ->
                Melhole_server.style writer declarations;
                later
            | Inner_html html, _ -> { later with html = Some html })
          { value = None; default_value = None; checked = None; default_checked = None; selected = Unmarked; html = None }
          props
      in
      let given = match later.value with Some _ -> later.value | None -> later.default_value in
      (match tag with
      | "input" ->
          Option.iter
            (fun checked -> match checked with On -> Melhole_server.attribute writer "checked" (Some "") | Off -> ())
            (match later.checked with Some _ -> later.checked | None -> later.default_checked);
          Melhole_server.attribute writer "value" given
      | "option" ->
          Melhole_server.option_selected writer
            (Option.value ~default:(Melhole_server.texts children) later.value)
            later.selected
      | _ -> ());
      match tag with
      | "area" | "base" | "br" | "col" | "embed" | "hr" | "img" | "input" | "keygen" | "link" | "meta" | "param"
      | "source" | "track" | "wbr" ->
          Melhole_server.markup writer "/>"
      | _ ->
          Melhole_server.markup writer ">";
          (match (tag, later.html, given) with
          | ("pre" | "listing"), Some html, _ ->
              Melhole_server.leading_newline writer html;
              Melhole_server.raw writer html
          | _, Some html, _ -> Melhole_server.raw writer html
          | "textarea", None, Some text ->
              Melhole_server.leading_newline writer text;
              Melhole_server.dynamic_text writer text
          | "select", None, _ ->
              let around = Melhole_server.choose writer given in
              Melhole_server.write writer children;
              Melhole_server.chosen writer around
          | _, None, _ -> Melhole_server.write writer children);
          Melhole_server.markup writer ("</" ^ tag ^ ">"))
