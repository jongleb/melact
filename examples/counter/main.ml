open Melact_view

external document : Dom.document = "document"

external element_by_id : Dom.document -> string -> Dom.element option
  = "getElementById"
[@@mel.send] [@@mel.return nullable]

(** What the user can do to the count. *)
type message = Increment | Decrement | Reset

let counter =
  Template.make
    ~html:
      "<div class=\"counter\"><button>-</button><output></output><button>+</button><button>reset</button></div>"
    ~holes:
      [|
        Handler ([ 0 ], "click");
        Text ([ 1 ], 0);
        Class_list [ 1 ];
        Handler ([ 2 ], "click");
        Handler ([ 3 ], "click");
        Attr ([ 3 ], "disabled");
      |]

let () =
  Option.iter
    (Program.sandbox ~init:0
       ~update:(fun message count ->
         match message with
         | Increment -> count + 1
         | Decrement -> count - 1
         | Reset -> 0)
       ~view:(fun dispatch count ->
         View.tpl_instance counter
           [|
             HHandler (fun _ -> dispatch Decrement);
             HText (string_of_int count);
             HClass (if count < 0 then [ "negative" ] else []);
             HHandler (fun _ -> dispatch Increment);
             HHandler (fun _ -> dispatch Reset);
             HAttr (if count = 0 then Some "" else None);
           |]))
    (element_by_id document "root")
