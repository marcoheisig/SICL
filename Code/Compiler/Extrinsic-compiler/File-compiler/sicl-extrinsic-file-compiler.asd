(cl:in-package #:asdf-user)

(defsystem :sicl-extrinsic-file-compiler
  :depends-on (:sicl-reader-simple
	       :cleavir-generate-ast
	       :cleavir-ast-to-hir
	       :sicl-extrinsic-environment
	       :sicl-target-sicl
	       :sicl-os-gnu-linux)
  :serial t
  :components
  ((:file "packages")
   (:file "compile-file")))
