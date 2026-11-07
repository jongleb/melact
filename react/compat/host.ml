open Melhole

(** The namespace an element is created in. *)
type space = Html | Svg

type mounted = {
  element : Dom.element;
  tag : string;
  space : space;
  mutable props : Raw.t;
  mutable content : View.live;
  mutable reference : Raw.t;
}

let svg_namespace = "http://www.w3.org/2000/svg"

external create_in : Dom.document -> string -> string -> Dom.element = "createElementNS" [@@mel.send]
external namespace_of : Dom.node -> string Js.null = "namespaceURI" [@@mel.get]
external focus : Dom.element -> unit = "focus" [@@mel.send]

let assign reference value =
  match Raw.view reference with
  | Callable call -> ignore (Raw.call1 call value)
  | Record record -> Raw.set record "current" value
  | Missing | Flag _ | Number _ | Text _ | Listed _ | Other _ -> ()

external trimmed : string -> string = "trim" [@@mel.send]

(** How react-dom writes an attribute's value. *)
type flavour = Boolean | Overloaded | Booleanish | Plain

let write element space tag name previous value =
  let attribute element space name value =
    let attribute_name space name =
      let hyphenated =
        [
          "accent-height"; "alignment-baseline"; "arabic-form"; "baseline-shift"; "cap-height"; "clip-path"; "clip-rule";
          "color-interpolation"; "color-interpolation-filters"; "color-profile"; "color-rendering"; "dominant-baseline";
          "enable-background"; "fill-opacity"; "fill-rule"; "flood-color"; "flood-opacity"; "font-family"; "font-size";
          "font-size-adjust"; "font-stretch"; "font-style"; "font-variant"; "font-weight"; "glyph-name";
          "glyph-orientation-horizontal"; "glyph-orientation-vertical"; "horiz-adv-x"; "horiz-origin-x"; "image-rendering";
          "letter-spacing"; "lighting-color"; "marker-end"; "marker-mid"; "marker-start"; "overline-position";
          "overline-thickness"; "paint-order"; "pointer-events"; "rendering-intent"; "shape-rendering"; "stop-color";
          "stop-opacity"; "strikethrough-position"; "strikethrough-thickness"; "stroke-dasharray"; "stroke-dashoffset";
          "stroke-linecap"; "stroke-linejoin"; "stroke-miterlimit"; "stroke-opacity"; "stroke-width"; "text-anchor";
          "text-decoration"; "text-rendering"; "underline-position"; "underline-thickness"; "unicode-bidi"; "unicode-range";
          "units-per-em"; "v-alphabetic"; "v-hanging"; "v-ideographic"; "v-mathematical"; "vector-effect"; "vert-adv-y";
          "vert-origin-x"; "vert-origin-y"; "word-spacing"; "writing-mode"; "x-height";
        ]
      in
      match name with
      | "className" -> "class"
      | "htmlFor" -> "for"
      | "acceptCharset" -> "accept-charset"
      | "httpEquiv" -> "http-equiv"
      | _ -> (
          match space with
          | Html -> name
          | Svg ->
              let buffer = Buffer.create (String.length name + 4) in
              String.iter
                (fun letter ->
                  match Char.lowercase_ascii letter = letter with
                  | true -> Buffer.add_char buffer letter
                  | false ->
                      Buffer.add_char buffer '-';
                      Buffer.add_char buffer (Char.lowercase_ascii letter))
                name;
              let kebab = Buffer.contents buffer in
              (match List.mem kebab hyphenated with true -> kebab | false -> name))
    in
    let flavour name =
      match name with
      | "allowFullScreen" | "async" | "autoPlay" | "controls" | "default" | "defer" | "disabled"
      | "disablePictureInPicture" | "disableRemotePlayback" | "formNoValidate" | "hidden" | "loop" | "noModule"
      | "noValidate" | "open" | "playsInline" | "readOnly" | "required" | "reversed" | "scoped" | "seamless" | "itemScope" ->
          Boolean
      | "capture" | "download" -> Overloaded
      | "contentEditable" | "draggable" | "spellCheck" | "autoReverse" | "externalResourcesRequired" | "focusable"
      | "preserveAlpha" ->
          Booleanish
      | _ when String.length name > 5 && (String.sub name 0 5 = "data-" || String.sub name 0 5 = "aria-") -> Booleanish
      | _ -> Plain
    in
    let target =
      match flavour name with Boolean -> String.lowercase_ascii name | Overloaded | Booleanish | Plain -> attribute_name space name
    in
    let write text = Dom_api.set_attribute element target text and erase () = Dom_api.remove_attribute element target in
    match (Raw.view value, flavour name) with
    | (Missing | Callable _ | Other _), _ -> erase ()
    | Flag true, (Boolean | Overloaded) -> write ""
    | Flag false, (Boolean | Overloaded) -> erase ()
    | Flag shown, Booleanish -> write (string_of_bool shown)
    | Flag _, Plain -> erase ()
    | Text "", Boolean -> erase ()
    | _, Boolean -> write ""
    | (Number _ | Text _ | Record _ | Listed _), (Overloaded | Booleanish | Plain) -> write (Raw.text_of value)
  in
  let styles element previous next =
    let unitless name =
      let bare =
        let prefixed prefix =
          let length = String.length prefix in
          String.length name > length && String.sub name 0 length = prefix && Char.uppercase_ascii name.[length] = name.[length]
        in
        match List.find_opt prefixed [ "Webkit"; "Moz"; "ms"; "O" ] with
        | Some prefix ->
            let rest = String.sub name (String.length prefix) (String.length name - String.length prefix) in
            String.make 1 (Char.lowercase_ascii rest.[0]) ^ String.sub rest 1 (String.length rest - 1)
        | None -> name
      in
      List.mem bare
        [
          "animationIterationCount"; "aspectRatio"; "borderImageOutset"; "borderImageSlice"; "borderImageWidth"; "boxFlex";
          "boxFlexGroup"; "boxOrdinalGroup"; "columnCount"; "columns"; "flex"; "flexGrow"; "flexPositive"; "flexShrink";
          "flexNegative"; "flexOrder"; "gridArea"; "gridRow"; "gridRowEnd"; "gridRowSpan"; "gridRowStart"; "gridColumn";
          "gridColumnEnd"; "gridColumnSpan"; "gridColumnStart"; "fontWeight"; "lineClamp"; "lineHeight"; "opacity"; "order";
          "orphans"; "tabSize"; "widows"; "zIndex"; "zoom"; "fillOpacity"; "floodOpacity"; "stopOpacity"; "strokeDasharray";
          "strokeDashoffset"; "strokeMiterlimit"; "strokeOpacity"; "strokeWidth";
        ]
    in
    let style = Dom_api.style element in
    let put name value =
      let shown =
        match Raw.view value with
        | Missing | Flag _ -> ""
        | Text "" -> ""
        | Number number when number <> 0. && not (unitless name) -> Raw.text_of value ^ "px"
        | Number _ | Text _ | Callable _ | Listed _ | Record _ | Other _ -> trimmed (Raw.text_of value)
      in
      match String.length name > 1 && String.sub name 0 2 = "--" with
      | true -> Dom_api.set_style_property style name shown ""
      | false -> Dom_api.set_style style (match name with "float" -> "cssFloat" | other -> other) shown
    in
    let fields value = match Raw.view value with Record record -> Some record | _ -> None in
    Option.iter
      (fun old ->
        Array.iter
          (fun name ->
            match Option.bind (fields next) (fun next -> Raw.present (Raw.get next name)) with
            | Some _ -> ()
            | None -> put name Raw.undefined)
          (Raw.keys old))
      (fields previous);
    Option.iter
      (fun next ->
        Array.iter
          (fun name ->
            let value = Raw.get next name in
            match fields previous with
            | Some old when Raw.same (Raw.get old name) value -> ()
            | Some _ | None -> put name value)
          (Raw.keys next))
      (fields next)
  in
  let valued tag = match tag with "input" | "select" | "textarea" -> `Valued | _ -> `Plain in
  match (name, valued tag) with
  | ( ( "children" | "key" | "ref" | "suppressContentEditableWarning" | "suppressHydrationWarning" | "defaultValue"
      | "defaultChecked" | "autoFocus" | "innerHTML" ),
      _ )
  | ("value" | "checked"), `Valued ->
      ()
  | "dangerouslySetInnerHTML", _ ->
      Dom_api.set_inner_html element
        (Option.fold ~none:"" ~some:Raw.text_of (Option.bind (Raw.present value) (fun html -> Raw.find html "__html")))
  | "style", _ -> styles element previous value
  | ("selected" | "muted" | "multiple"), _ ->
      Dom_api.set_property element name (match Raw.view value with Flag true -> true | _ -> false)
  | _ -> (
      match Synthetic.of_prop ~tag name with
      | Some prop -> Synthetic.put element prop (match Raw.view value with Callable handler -> Some handler | _ -> None)
      | None -> attribute element space name value)

let field props name = Raw.get props name

let latest = "$$react:props"

let values element tag ~mounting props =
  Dom_api.set_property element latest props;
  let given name = Raw.present (field props name) in
  match tag with
  | "input" ->
      (match (given "value", given "defaultValue") with
      | Some value, _ ->
          let text = Raw.text_of value in
          if not (String.equal (Dom_api.property element "value") text) then Dom_api.set_property element "value" text;
          (match ((Dom_api.property element "type" : string), Dom_api.same (Dom_api.active_element Dom_api.document) (Js.Null.return element)) with
          | "number", true -> ()
          | _ -> Dom_api.set_property element "defaultValue" text);
          Dom_api.set_property element Events.controlled (fun _ ->
              let shown = Raw.text_of (field (Dom_api.property element latest) "value") in
              if not (String.equal (Dom_api.property element "value") shown) then Dom_api.set_property element "value" shown;
              Events.track element)
      | None, Some initial ->
          (match mounting with `Mounting -> Dom_api.set_property element "value" (Raw.text_of initial) | `Patching -> ());
          Dom_api.set_property element "defaultValue" (Raw.text_of initial)
      | None, None -> ());
      (match given "checked" with
      | Some checked ->
          Dom_api.set_property element "checked" (match Raw.view checked with Flag true -> true | _ -> false);
          Dom_api.set_property element Events.controlled (fun _ ->
              Dom_api.set_property element "checked"
                (match Raw.view (field (Dom_api.property element latest) "checked") with Flag true -> true | _ -> false);
              Events.track element)
      | None -> (
          match (mounting, given "defaultChecked") with
          | `Mounting, Some initial -> Dom_api.set_property element "defaultChecked" (match Raw.view initial with Flag true -> true | _ -> false)
          | _ -> ()));
      Events.track element
  | "textarea" ->
      Option.iter
        (fun value ->
          let text = Raw.text_of value in
          if not (String.equal (Dom_api.property element "value") text) then Dom_api.set_property element "value" text;
          Events.track element)
        (given "value")
  | "select" ->
      Option.iter
        (fun value ->
          let chosen = Raw.text_of value in
          let options_of : Dom.element -> Dom.element array =
            [%mel.raw {|function (select) { return Array.from(select.options); }|}]
          in
          let options = options_of element in
          match Array.find_opt (fun option -> String.equal (Dom_api.property option "value") chosen) options with
          | Some option -> Dom_api.set_property option "selected" true
          | None -> ())
        (match given "value" with Some value -> Some value | None -> (match mounting with `Mounting -> given "defaultValue" | `Patching -> None))
  | _ -> ()

let hosting =
  View.hosting
    ~visit:(fun [@u] mounted see -> see (Dom_api.to_node mounted.element) [@u])
    ~first:(fun [@u] mounted _ -> Js.Null.return (Dom_api.to_node mounted.element))
    ~let_go:(fun [@u] mounted ->
      View.release mounted.content;
      assign mounted.reference Raw.null)

let child tag props reference children =
  let space_at (position : Template.position) tag =
    match tag with
    | "svg" -> Svg
    | _ -> (
        match (Js.Null.toOption (namespace_of position.parent), Dom_api.node_name position.parent) with
        | Some namespace, name when String.equal namespace svg_namespace && not (String.equal name "foreignObject") -> Svg
        | _ -> Html)
  in
  View.host
    ~build:(fun [@u] position ->
      let space = space_at position tag in
      let element =
        match space with Svg -> create_in Dom_api.document svg_namespace tag | Html -> Dom_api.create_element Dom_api.document tag
      in
      Array.iter (fun name -> write element space tag name Raw.undefined (Raw.get props name)) (Raw.keys props);
      let inside = { Template.parent = Dom_api.to_node element; before = Js.null } in
      let content = View.build children inside in
      values element tag ~mounting:`Mounting props;
      View.insert position (Dom_api.to_node element);
      (match (tag, Raw.view (field props "autoFocus")) with
      | ("input" | "button" | "select" | "textarea"), Flag true -> View.attach_later (fun () -> focus element)
      | _ -> ());
      (match Raw.present reference with
      | Some reference -> View.attach_later (fun () -> assign reference (Raw.of_any element))
      | None -> ());
      View.live hosting { element; tag; space; props; content; reference })
    ~patch:(fun [@u] _ live ->
      match View.hosted hosting live with
      | Some mounted when String.equal mounted.tag tag ->
          let previous = mounted.props in
          (match Raw.same previous props with
          | true -> ()
          | false ->
              Array.iter
                (fun name ->
                  match Raw.present (Raw.get props name) with
                  | Some _ -> ()
                  | None -> write mounted.element mounted.space tag name (Raw.get previous name) Raw.undefined)
                (Raw.keys previous);
              Array.iter
                (fun name ->
                  let value = Raw.get props name in
                  match Raw.same (Raw.get previous name) value with
                  | true -> ()
                  | false -> write mounted.element mounted.space tag name (Raw.get previous name) value)
                (Raw.keys props);
              mounted.props <- props);
          mounted.content <- View.update { Template.parent = Dom_api.to_node mounted.element; before = Js.null } mounted.content children;
          values mounted.element tag ~mounting:`Patching props;
          (match Raw.same mounted.reference reference with
          | true -> ()
          | false ->
              assign mounted.reference Raw.null;
              mounted.reference <- reference;
              Option.iter (fun reference -> View.attach_later (fun () -> assign reference (Raw.of_any mounted.element))) (Raw.present reference));
          Some live
      | Some _ | None -> None)
