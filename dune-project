(lang dune 3.16)

(using melange 0.1)

(name melact)

(dialect
 (name mlx)
 (implementation
  (extension mlx)
  (merlin_reader mlx)
  (preprocess
   (run mlx-pp %{input-file}))))

(generate_opam_files true)

(license MIT)

(authors "Gleb <jongleber@gmail.com>")

(maintainers "Gleb <jongleber@gmail.com>")

(homepage "https://jongleb.github.io/melact-meltea-sites/melact/")

(documentation "https://github.com/jongleb/melact#readme")

(source
 (github jongleb/melact))

(package
 (name melhole)
 (synopsis "Templates with holes for Melange: the runtime and the compiler shared by Melact and Meltea")
 (description
  "melhole turns a view known at build time into a DOM template with holes and per-template update code, guarded by === on the values each hole reads. It is the runtime and the compiler under Melact and Meltea, and has a server writer that renders the same views to HTML natively.")
 (depends
  (ocaml
   (>= 5.4))
  (dune
   (>= 3.16))
  (melange
   (>= 7.0.0))
  (ppxlib
   (>= 0.39.0))
  ppx_deriving_variant_string
  ppx_enumerate))

(package
 (name melact)
 (synopsis "The reason-react API for Melange, compiled to templates, without React or a virtual DOM")
 (description
  "Melact keeps reason-react's API (components, hooks, ReactDOM, ReactDOMServer, ReasonReactRouter, error boundaries, Suspense) and compiles every view to DOM templates with melact-ppx: an app moves over by changing two lines of its dune file, and runs without React.")
 (depends
  (ocaml
   (>= 5.4))
  (dune
   (>= 3.16))
  (melange
   (>= 7.0.0))
  (melhole
   (= :version))
  (melact-ppx
   (and
    :with-test
    (= :version)))
  (reason-react :with-test)
  (reason-react-ppx :with-test)
  (reason :with-test)
  (mlx :with-test))
 (depopts meltea))

(package
 (name melact-ppx)
 (synopsis "The JSX and [@react.component] of reason-react, compiled to templates, for Melact")
 (description
  "melact-ppx compiles reason-react's JSX, [@react.component] and hooks to melhole templates with typed hook keys, and rewrites bindings to npm's react into Melact's own functions.")
 (depends
  (ocaml
   (>= 5.4))
  (dune
   (>= 3.16))
  (ppxlib
   (>= 0.39.0))
  (melhole
   (= :version))
  (qcheck-core :with-test)))

(package
 (name meltea)
 (synopsis "The Elm architecture for Melange: pure functions, mlx views, compiled templates")
 (description
  "Meltea is the Elm architecture in OCaml: a model, messages, a pure update and a pure view written in mlx, compiled by meltea-ppx to DOM templates that re-render only what a message changed.")
 (depends
  (ocaml
   (>= 5.4))
  (dune
   (>= 3.16))
  (melange
   (>= 7.0.0))
  (melhole
   (= :version))
  (meltea-ppx
   (and
    :with-test
    (= :version)))
  (mlx :with-test)
  (jsonkit-melange :with-test)))

(package
 (name meltea-ppx)
 (synopsis "Meltea's mlx views with messages, compiled to templates")
 (description
  "meltea-ppx compiles Meltea's mlx views to melhole templates, reads update and view for the model fields each message changes, and can write a view's HTML natively for server rendering.")
 (depends
  (ocaml
   (>= 5.4))
  (dune
   (>= 3.16))
  (ppxlib
   (>= 0.39.0))
  (melhole
   (= :version))
  (qcheck-core :with-test)))
