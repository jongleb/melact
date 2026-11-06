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

let style_module source =
  let lines = In_channel.with_open_text source In_channel.input_lines in
  let rec from lines =
    match lines with
    | [] -> failwith ("gen: no module Style in " ^ source)
    | line :: rest when String.length line >= 12 && String.equal (String.sub line 0 12) "module Style" -> line :: until rest
    | _ :: rest -> from rest
  and until lines =
    match lines with
    | [] -> []
    | "end" :: _ -> [ "end" ]
    | line :: rest -> line :: until rest
  in
  from lines

let style_labels source =
  List.filter_map
    (fun line ->
      let trimmed = String.trim line in
      match String.length trimmed > 0 && trimmed.[0] = '?' && Option.is_some (String.index_opt trimmed ':') with
      | true -> Some (String.sub trimmed 1 (String.index trimmed ':' - 1))
      | false -> None)
    (style_module source)

let server_applying (name, (kind : Melhole_compiler.Dom_props.kind)) =
  let named = Melhole_compiler.Dom_props.react_name in
  match (name, kind) with
  | "defaultValue", _ -> "Default_value_prop"
  | "defaultChecked", _ -> "Default_checked_prop"
  | _, Attribute (attribute, value) -> applying (Attribute (named attribute, value))
  | _, (Property _ | Controlled _ | Handler _ | Style | Ref | Inner_html | Ignored) -> applying kind

let native_label_type (kind : Melhole_compiler.Dom_props.kind) =
  match kind with
  | Inner_html -> "< __html : string >"
  | Attribute _ | Property _ | Controlled _ | Handler _ | Style | Ref | Ignored -> label_type kind

let native_prop name (kind : Melhole_compiler.Dom_props.kind) variable =
  let named = Melhole_compiler.Dom_props.react_name in
  let mapped constructor = Printf.sprintf "Option.map (fun value -> Melact_server.Dom.%s) %s" constructor variable in
  match (name, kind) with
  | "defaultValue", _ -> Some (mapped "Default_value value")
  | "defaultChecked", _ -> Some (mapped "Default_checked value")
  | _, Attribute (attribute, Text) -> Some (mapped (Printf.sprintf "Attribute (%S, value)" (named attribute)))
  | _, Attribute (attribute, Flag) ->
      Some
        (Printf.sprintf "Option.bind %s (fun value -> match value with true -> Some (Melact_server.Dom.Present %S) | false -> None)"
           variable (named attribute))
  | _, Attribute (attribute, Booleanish) ->
      Some
        (mapped (Printf.sprintf "Attribute (%S, match value with true -> \"true\" | false -> \"false\")" (named attribute)))
  | _, Attribute (attribute, Integer) -> Some (mapped (Printf.sprintf "Number (%S, value)" (named attribute)))
  | _, Attribute (attribute, Decimal) -> Some (mapped (Printf.sprintf "Attribute (%S, Melhole_server.float value)" (named attribute)))
  | _, (Property ("value", _) | Controlled ("value", _)) -> Some (mapped "Value value")
  | _, (Property ("checked", _) | Controlled ("checked", _)) -> Some (mapped "Checked value")
  | _, (Property ("selected", _) | Controlled ("selected", _)) -> Some (mapped "Selected value")
  | _, (Property (property, _) | Controlled (property, _)) ->
      Some
        (Printf.sprintf "Option.bind %s (fun value -> match value with true -> Some (Melact_server.Dom.Present %S) | false -> None)"
           variable property)
  | _, Style -> Some (mapped "Style (Style.declarations value)")
  | _, Inner_html -> Some (mapped "Inner_html value#__html")
  | _, (Handler _ | Ref | Ignored) -> None

let () =
  let label name = match List.mem name keywords with true -> name ^ "_" | false -> name in
  let props =
    List.map (fun prop -> (Melhole_compiler.Dom_props.Prop.to_string prop, Melhole_compiler.Dom_props.kind prop)) Melhole_compiler.Dom_props.Prop.all
  in
  let template, part, style =
    match Sys.argv with
    | [| _; template; part |] -> (template, part, None)
    | [| _; template; part; style |] -> (template, part, Some style)
    | _ -> failwith "usage: gen template impl|intf|server_impl|server_intf|native_impl|native_intf [style source]"
  in
  let lines = In_channel.with_open_text template In_channel.input_lines in
  let external_props =
    [ "external domProps :"; "  ?key:(string[@mel.as \"key\"]) ->"; "  ?children:(React.element[@mel.as \"children\"]) ->" ]
    @ List.map (fun (name, kind) -> Printf.sprintf "  ?%s:((%s)[@mel.as %S]) ->" (label name) (label_type kind) name) props
    @ [ "  unit ->"; "  domProps = \"\""; "[@@mel.obj]" ]
  in
  let generated =
    match part with
    | "impl" ->
        external_props
        @ [ ""; "let applying name ="; "  match name with" ]
        @ List.map (fun (label, kind) -> Printf.sprintf "  | %S -> %s" label (applying kind)) props
        @ [ "  | _ -> Skipped" ]
    | "server_impl" ->
        external_props
        @ [ ""; "let applying name ="; "  match name with" ]
        @ List.map (fun (label, kind) -> Printf.sprintf "  | %S -> %s" label (server_applying (label, kind))) props
        @ [ "  | _ -> Skipped" ]
    | "native_impl" ->
        [
          "type domProps = { key : string option; children : React.element option; props : Melact_server.Dom.prop list }";
          "";
          "let domProps ?key ?children";
        ]
        @ List.map (fun (name, _) -> Printf.sprintf "    ?%s:%s" (label name) ("prop_" ^ name)) props
        @ [ "    () ="; "  { key; children; props = List.filter_map Fun.id [" ]
        @ List.filter_map
            (fun (name, kind) -> Option.map (fun made -> "    " ^ made ^ ";") (native_prop name kind ("prop_" ^ name)))
            props
        @ [ "  ] }" ]
    | "native_intf" ->
        [
          "(** The props of a DOM element built at run time, as [domProps] makes them. *)";
          "type domProps";
          "";
          "val domProps :";
          "  ?key:string ->";
          "  ?children:React.element ->";
        ]
        @ List.map (fun (name, kind) -> Printf.sprintf "  ?%s:(%s) ->" (label name) (native_label_type kind)) props
        @ [ "  unit ->"; "  domProps" ]
    | _ ->
        [ "(** The props of a DOM element built at run time, as [domProps] makes them. *)"; "type domProps"; "" ]
        @ external_props
  in
  let styled () =
    match (part, style) with
    | ("server_impl" | "server_intf"), Some source -> style_module source
    | "native_intf", Some source ->
        [ "module Style : sig"; "  (** Inline style declarations, in the order [make] takes them. *)"; "  type t"; ""; "  val make :" ]
        @ List.map (fun name -> Printf.sprintf "    ?%s:string ->" name) (style_labels source)
        @ [
            "    unit ->";
            "    t";
            "";
            "  val combine : t -> t -> t";
            "  val unsafeAddProp : t -> string -> string -> t";
            "  val declarations : t -> (string * string) list";
            "end";
          ]
    | "native_impl", Some source ->
        let names = style_labels source in
        [ "module Style = struct"; "  type t = Declarations of (string * string) list [@@unboxed]"; ""; "  let make" ]
        @ List.map (fun name -> Printf.sprintf "      ?%s" name) names
        @ [ "      () ="; "    Declarations (List.filter_map Fun.id [" ]
        @ List.map (fun name -> Printf.sprintf "      Option.map (fun value -> (%S, value)) %s;" name name) names
        @ [
            "    ])";
            "";
            "  let combine (Declarations first) (Declarations second) =";
            "    Declarations";
            "      (List.map (fun (name, value) -> (name, Option.value ~default:value (List.assoc_opt name second))) first";
            "      @ List.filter (fun (name, _) -> not (List.mem_assoc name first)) second)";
            "";
            "  let unsafeAddProp style name value = combine style (Declarations [ (name, value) ])";
            "  let declarations (Declarations declarations) = declarations";
            "end";
          ]
    | _ -> failwith "gen: [@@@melact.style] needs a server or native part and the style source"
  in
  List.iter
    (fun line ->
      match String.trim line with
      | "[@@@melact.dom_props]" -> List.iter print_endline generated
      | "[@@@melact.style]" -> List.iter print_endline (styled ())
      | _ -> print_endline line)
    lines
