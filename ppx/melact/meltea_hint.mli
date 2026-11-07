(** With [-meltea-hints], an alert [meltea] at every [@react.component] whose only hooks are
    [useState] and [useReducer]: its state is a model and its setters are messages, so it moves to
    Meltea one to one (docs/migration.md). Without the flag the code is left as it is. *)
