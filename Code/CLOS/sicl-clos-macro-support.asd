(cl:in-package #:asdf-user)

(defsystem :sicl-clos-macro-support
  :depends-on (:sicl-clos-package)
  :serial t
  :components
  ((:file "with-slots-support")))
