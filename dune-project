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

(authors "Gleb")

(maintainers "Gleb")

(package
 (name melhole)
 (synopsis "Templates with holes for Melange: the runtime and the compiler shared by Melact and Meltea")
 (depends
  (ocaml
   (>= 5.3))
  (dune
   (>= 3.16))
  (melange
   (>= 5.1))
  (ppxlib
   (>= 0.34))
  ppx_deriving_variant_string
  ppx_enumerate
  (qcheck-core :with-test)))

(package
 (name melact)
 (synopsis "reason-react for Melange without React and without a virtual DOM")
 (depends
  (ocaml
   (>= 5.3))
  (dune
   (>= 3.16))
  (melange
   (>= 5.1))
  melhole
  (reason-react :with-test)
  (reason-react-ppx :with-test)
  (reason :with-test)
  (mlx :with-test)))

(package
 (name melact-ppx)
 (synopsis "reason-react's JSX and [@react.component], compiled to templates, for Melact")
 (depends
  (ocaml
   (>= 5.3))
  (dune
   (>= 3.16))
  (ppxlib
   (>= 0.34))
  melhole))

(package
 (name meltea)
 (synopsis "The Elm architecture for Melange: pure functions, mlx views, compiled templates")
 (depends
  (ocaml
   (>= 5.3))
  (dune
   (>= 3.16))
  (melange
   (>= 5.1))
  melhole
  (mlx :with-test)
  (jsonkit-melange :with-test)))

(package
 (name meltea-ppx)
 (synopsis "mlx views with messages, compiled to templates, for Meltea")
 (depends
  (ocaml
   (>= 5.3))
  (dune
   (>= 3.16))
  (ppxlib
   (>= 0.34))
  melhole))
