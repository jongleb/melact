(** [Scope.mapper] for Melact: a call of a hook ([use], or [use] then no lowercase letter) is stateful. *)
class mapper : object
  inherit Melhole_compiler.Scope.mapper
end
