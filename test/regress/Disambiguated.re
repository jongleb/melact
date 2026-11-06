[@react.component]
let make = () => {
  let (n, setN) = React.useState(() => 0);
  <div onClick={_ => setN(n => n + 1)}>
    <Shapes.Box
      style={pad: n, tone: Strong(1)}
      padding={All(n)}
      tone=Soft
      maybe={Some(Strong(n))}
      pair=(Soft, n)
      tones=[|Soft, Strong(n)|]
      listed=[Soft, Strong(n)]
      onPick={() => Strong(n)}
      render={s => s.pad + n}
      describe={({pad, tone}) =>
        switch (tone) {
        | Soft => "s"
        | Strong(k) => string_of_int(pad + k)
        }
      }
      name={
        fun
        | Soft => "soft"
        | Strong(_) => "strong"
      }
    />
  </div>;
};
