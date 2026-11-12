open Melhole
open Testing

external listen : Dom.element -> string -> (Dom.event -> unit) -> unit = "addEventListener" [@@mel.send]
external remove : Dom.element -> unit = "remove" [@@mel.send]
external cancel_bubble : Dom.event -> bool = "cancelBubble" [@@mel.get]
external stop : Dom.event -> unit = "stopPropagation" [@@mel.send]

let seen = ref []
let stopping = ref None

let walked ~depth ~target ~slots ~stopper =
  let root = attached () in
  let rec nest parent level made =
    match level = depth with
    | true -> Array.of_list (List.rev made)
    | false ->
        let element = create_element document "div" in
        append_child parent element;
        ignore (Events.register element "click");
        Events.set element (Events.key_of "click") (fun native ->
            seen := level :: !seen;
            Option.iter (fun stopper -> match level = stopper with true -> stop native | false -> ()) !stopping);
        nest element (level + 1) (element :: made)
  in
  let chain = nest root 0 [] in
  let cuts = List.map (fun level -> chain.(level)) slots in
  listen root "click" (fun native ->
      let rec through remaining =
        match (remaining, cancel_bubble native) with
        | [], _ | _, true -> ()
        | slot :: rest, false ->
            Events.segment native (as_node slot);
            through rest
      in
      through cuts);
  seen := [];
  stopping := stopper;
  click chain.(target);
  remove root;
  List.rev !seen

let () =
  describe "Melact's delegated walk in segments, as islands of real React run it" (fun () ->
      test "segments up to slots on the target's path, then the document's walk, run each handler once, inner first, up to a stop"
        (fun () ->
          check
            (property (tapes ~shortest:4 ~longest:30) (fun values ->
                 let tape = tape values in
                 let depth = 1 + draw tape 8 in
                 let target = draw tape depth in
                 let slots = List.filter (fun _ -> draw tape 2 = 0) (List.rev (List.init (target + 1) Fun.id)) in
                 let stopper = match draw tape (depth + 1) with 0 -> None | level -> Some (level - 1) in
                 let reached = List.rev (List.init (target + 1) Fun.id) in
                 let plain =
                   Option.fold ~none:reached
                     ~some:(fun stopper -> match stopper <= target with true -> List.filter (fun level -> level >= stopper) reached | false -> reached)
                     stopper
                 in
                 expect (walked ~depth ~target ~slots ~stopper) |. to_equal plain))
            [%mel.obj { numRuns = 300 }]))
