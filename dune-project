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
 (name melact)
 (synopsis "reason-react-compatible UI library for Melange without a virtual DOM")
 (depends
  (ocaml
   (>= 5.3))
  (dune
   (>= 3.16))
  (melange
   (>= 5.1))
  (reason-react :with-test)
  (reason-react-ppx :with-test)
  (reason :with-test)
  (mlx :with-test)))

(package
 (name melact-ppx)
 (synopsis "JSX to DOM templates with holes, for melact")
 (depends
  (ocaml
   (>= 5.3))
  (dune
   (>= 3.16))
  (ppxlib
   (>= 0.34))
  ppx_deriving_variant_string))
