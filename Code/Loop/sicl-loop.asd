;;;; Copyright (c) 2008 - 2015
;;;;
;;;;     Robert Strandh (robert.strandh@gmail.com)
;;;;
;;;; all rights reserved. 
;;;;
;;;; Permission is hereby granted to use this software for any 
;;;; purpose, including using, modifying, and redistributing it.
;;;;
;;;; The software is provided "as-is" with no warranty.  The user of
;;;; this software assumes any responsibility of the consequences. 

(cl:in-package #:asdf-user)

(defsystem :sicl-loop
  :depends-on (:sicl-loop-support)
  :serial t
  :components
  ((:file "loop-defmacro")))
