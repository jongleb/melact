let family event =
  match event with
  | "copy" | "cut" | "paste" -> "Clipboard"
  | "compositionend" | "compositionstart" | "compositionupdate" -> "Composition"
  | "keydown" | "keypress" | "keyup" -> "Keyboard"
  | "focusin" | "focusout" -> "Focus"
  | "input" | "submit" | "invalid" | "change" -> "Form"
  | "click" | "contextmenu" | "dblclick" | "mousedown" | "mouseenter" | "mouseleave" | "mousemove" | "mouseout"
  | "mouseover" | "mouseup" ->
      "Mouse"
  | "drag" | "dragend" | "dragenter" | "dragexit" | "dragleave" | "dragover" | "dragstart" | "drop" -> "Drag"
  | "select" -> "Selection"
  | "touchcancel" | "touchend" | "touchmove" | "touchstart" -> "Touch"
  | "scroll" -> "UI"
  | "wheel" -> "Wheel"
  | "load" -> "Image"
  | "animationstart" | "animationend" | "animationiteration" -> "Animation"
  | "transitionend" -> "Transition"
  | event when String.length event > 7 && String.equal (String.sub event 0 7) "pointer" -> "Pointer"
  | "gotpointercapture" | "lostpointercapture" -> "Pointer"
  | _ -> "Media"

let value_type (value : Melhole_compiler.Dom_props.value) =
  match value with Text -> "string" | Flag | Booleanish -> "bool" | Integer -> "int" | Decimal -> "float"

let label_type (kind : Melhole_compiler.Dom_props.kind) =
  match kind with
  | Attribute (_, value) | Property (_, value) | Controlled (_, value) -> value_type value
  | Handler event -> "React.Event." ^ family event ^ ".t -> unit"
  | Style -> "Style.t"
  | Ref -> "domRef"
  | Inner_html -> "< __html : string > Js.t"
  | Ignored -> "bool"

let applying (kind : Melhole_compiler.Dom_props.kind) =
  match kind with
  | Attribute (name, Text) -> Printf.sprintf "Text_attribute %S" name
  | Attribute (name, Flag) -> Printf.sprintf "Flag_attribute %S" name
  | Attribute (name, Booleanish) -> Printf.sprintf "Booleanish_attribute %S" name
  | Attribute (name, Integer) -> Printf.sprintf "Integer_attribute %S" name
  | Attribute (name, Decimal) -> Printf.sprintf "Decimal_attribute %S" name
  | Property (name, _) -> Printf.sprintf "Property_value %S" name
  | Controlled (name, _) -> Printf.sprintf "Controlled_value %S" name
  | Handler event -> Printf.sprintf "Event %S" event
  | Style -> "Style_value"
  | Ref -> "Ref_value"
  | Inner_html -> "Inner_html_value"
  | Ignored -> "Skipped"

let keywords =
  [ "and"; "as"; "assert"; "begin"; "class"; "constraint"; "do"; "done"; "downto"; "else"; "end"; "exception";
    "external"; "false"; "for"; "fun"; "function"; "functor"; "if"; "in"; "include"; "inherit"; "initializer";
    "lazy"; "let"; "match"; "method"; "module"; "mutable"; "new"; "nonrec"; "object"; "of"; "open"; "or";
    "private"; "rec"; "sig"; "struct"; "then"; "to"; "true"; "try"; "type"; "val"; "virtual"; "when"; "while";
    "with"; "mod"; "land"; "lor"; "lxor"; "lsl"; "lsr"; "asr" ]

let () =
  let label name = match List.mem name keywords with true -> name ^ "_" | false -> name in
  let props =
    List.map (fun prop -> (Melhole_compiler.Dom_props.Prop.to_string prop, Melhole_compiler.Dom_props.kind prop)) Melhole_compiler.Dom_props.Prop.all
  in
  let template, part = match Sys.argv with [| _; template; part |] -> (template, part) | _ -> failwith "usage: gen template impl|intf" in
  let lines = In_channel.with_open_text template In_channel.input_lines in
  let generated =
    match part with
    | "impl" ->
        [
          "type domComponent = props_object -> React.element";
          "type domProps = domComponent -> React.element";
          "";
          "let domProps ?key ?children "
          ^ String.concat " " (List.map (fun (name, _) -> "?" ^ label name) props)
          ^ " () =";
          "  let props = new_props () in";
          "  Option.iter (put props \"key\") key;";
          "  Option.iter (put props \"children\") children;";
        ]
        @ List.map (fun (name, _) -> Printf.sprintf "  Option.iter (put props %S) %s;" name (label name)) props
        @ [
            "  fun render -> render props";
            "";
            "let applying name =";
            "  match name with";
          ]
        @ List.map (fun (label, kind) -> Printf.sprintf "  | %S -> %s" label (applying kind)) props
        @ [ "  | _ -> Skipped" ]
    | _ ->
        [
          "(** A DOM element's component when its tag is known only at run time: what [stringToComponent] gives. *)";
          "type domComponent";
          "";
          "(** The props of a DOM element built at run time, as [domProps] makes them. *)";
          "type domProps = domComponent -> React.element";
          "";
          "val domProps :";
          "  ?key:string ->";
          "  ?children:React.element ->";
        ]
        @ List.map (fun (name, kind) -> Printf.sprintf "  ?%s:(%s) ->" (label name) (label_type kind)) props
        @ [ "  unit ->"; "  domProps" ]
  in
  List.iter
    (fun line -> if String.equal (String.trim line) "[@@@melact.dom_props]" then List.iter print_endline generated else print_endline line)
    lines
