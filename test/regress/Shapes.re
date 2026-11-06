module Tone = {
  type t =
    | Soft
    | Strong(int);

  let show =
    fun
    | Soft => "soft"
    | Strong(k) => "strong" ++ string_of_int(k);
};

module Box = {
  type style = {
    pad: int,
    tone: Tone.t,
  };

  type padding =
    | All(int)
    | Sides(int, int);

  [@react.component]
  let make =
      (
        ~style: style,
        ~padding: padding,
        ~tone: Tone.t,
        ~maybe: option(Tone.t),
        ~pair: (Tone.t, int),
        ~tones: array(Tone.t),
        ~listed: list(Tone.t),
        ~onPick: unit => Tone.t,
        ~render: style => int,
        ~describe: style => string,
        ~name: Tone.t => string,
      ) => {
    let shown =
      String.concat(
        " ",
        [
          string_of_int(style.pad),
          Tone.show(style.tone),
          switch (padding) {
          | All(k) => "all" ++ string_of_int(k)
          | Sides(a, b) => "sides" ++ string_of_int(a) ++ string_of_int(b)
          },
          Tone.show(tone),
          Option.fold(~none="none", ~some=Tone.show, maybe),
          Tone.show(fst(pair)) ++ string_of_int(snd(pair)),
          String.concat(",", Array.to_list(Array.map(Tone.show, tones))),
          String.concat(",", List.map(Tone.show, listed)),
          Tone.show(onPick()),
          string_of_int(render(style)),
          describe(style),
          name(tone),
        ],
      );
    <p> {React.string(shown)} </p>;
  };
};
