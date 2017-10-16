(cl:in-package #:cleavir-cst-to-ast)

;;; Check that the syntax of a special form is correct.  The special
;;; form is represented as a CST.  OPERATOR is the name of the special
;;; operator of the special form.  Primary methods on this generic
;;; function signal an error when an incorrect syntax is detected.  An
;;; :AROUND method proposes restarts that replace the CST by one that
;;; signals an error at run time.  The replacement CST is returned by
;;; the :AROUND method.
(defgeneric check-special-form-syntax (operator cst))

(defmethod check-special-form-syntax :around (operator cst)
  (restart-case (progn (call-next-method) cst)
    (recover ()
      :report "Recover by replacing form by a call to ERROR."
      (cst:cst-from-expression
       '(error 'run-time-program-error
         :expr (cst:raw cst)
         :origin (cst:source cst))))))

;;; Take a CST, check whether it represents a proper list.  If it does
;;; not represent ERROR-TYPE is a symbol that is passed to ERROR.
(defun check-cst-proper-list (cst error-type)
  (unless  (cst:proper-list-p cst)
    (error error-type
           :expr (cst:raw cst)
           :origin (cst:source cst))))

;;; Check that the number of arguments greater than or equal to MIN
;;; and less than or equal to MAX.  When MAX is NIL, then there is no
;;; upper bound on the number of arguments.  If the argument count is
;;; wrong, then signal an error.  It is assumed that CST represents a
;;; proper list, so this must be checked first by the caller.
(defun check-argument-count (cst min max)
  (let ((count (1- (length (cst:raw cst)))))
    (unless (and (>= count min)
                 (or (null max)
                     (<= count max)))
      (error 'incorrect-number-of-arguments
             :expr (cst:raw cst)
             :expected-min min
             :expected-max max
             :observed count
             :origin (cst:source cst)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Checking QUOTE.

(defmethod check-special-form-syntax ((operator (eql 'quote)) cst)
  ;; The code in this method has been moved to the corresponding
  ;; method of convert-special.  Ultimately, the code of every method
  ;; on CHECK-SPECIAL-FORM-SYNTAX will be moved.
  (declare (ignore cst))
  nil)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Checking BLOCK.

(defmethod check-special-form-syntax ((operator (eql 'block)) cst)
  ;; The code in this method has been moved to the corresponding
  ;; method of convert-special.  Ultimately, the code of every method
  ;; on CHECK-SPECIAL-FORM-SYNTAX will be moved.
  (declare (ignore cst))
  nil)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Checking EVAL-WHEN.

(defmethod check-special-form-syntax ((operator (eql 'eval-when)) cst)
  (check-cst-proper-list cst 'form-must-be-proper-list)
  (check-argument-count cst 1 nil)
  (let ((situations-cst (cst:second cst)))
    (unless (cst:proper-list-p situations-cst)
      (error 'situations-must-be-proper-list
             :expr (cst:raw situations-cst)
             :origin (cst:source situations-cst)))
    ;; Check each situation
    (loop for remaining = situations-cst then (cst:rest remaining)
          until (cst:null remaining)
          do (let* ((situation-cst (cst:first remaining))
                    (situation (cst:raw situation-cst)))
               (unless (and (symbolp situation)
                            (member situation
                                    '(:compile-toplevel :load-toplevel :execute
                                      compile load eval)))
                 (error 'invalid-eval-when-situation
                        :expr situation
                        :origin (cst:source situation-cst)))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Checking FLET and LABELS.

(defmethod check-special-form-syntax ((operator (eql 'flet)) cst)
  ;; The code in this method has been moved to the corresponding
  ;; method of convert-special.  Ultimately, the code of every method
  ;; on CHECK-SPECIAL-FORM-SYNTAX will be moved.
  (declare (ignore cst))
  nil)

(defmethod check-special-form-syntax ((operator (eql 'labels)) cst)
  ;; The code in this method has been moved to the corresponding
  ;; method of convert-special.  Ultimately, the code of every method
  ;; on CHECK-SPECIAL-FORM-SYNTAX will be moved.
  (declare (ignore cst))
  nil)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Checking FUNCTION.

(defun proper-function-name-p (name-cst)
  (let ((name (cst:raw name-cst)))
    (or (symbolp name)
        (and (cleavir-code-utilities:proper-list-p name)
             (= (length name) 2)
             (eq (car name) 'setf)
             (symbolp (cadr name))))))

(defmethod check-special-form-syntax ((operator (eql 'function)) cst)
  (check-cst-proper-list cst 'form-must-be-proper-list)
  (check-argument-count cst 1 1)
  (let ((function-name-cst (cst:second cst)))
    (cond ((proper-function-name-p function-name-cst)
           nil)
          ((cst:consp function-name-cst)
           (unless (eq (cst:raw (cst:first function-name-cst)) 'lambda)
             (error 'function-argument-must-be-function-name-or-lambda-expression
                    :expr (cst:raw function-name-cst)
                    :origin (cst:source function-name-cst)))
           (unless (cst:proper-list-p function-name-cst)
             (error 'lambda-must-be-proper-list
                    :expr (cst:raw function-name-cst)
                    :origin (cst:source function-name-cst))))
          (t
           (error 'function-argument-must-be-function-name-or-lambda-expression
                  :expr (cst:raw function-name-cst)
                  :origin (cst:source function-name-cst))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Checking GO.

(defmethod check-special-form-syntax ((operator (eql 'go)) cst)
  ;; The code in this method has been moved to the corresponding
  ;; method of convert-special.  Ultimately, the code of every method
  ;; on CHECK-SPECIAL-FORM-SYNTAX will be moved.
  (declare (ignore cst))
  nil)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Checking IF.

(defmethod check-special-form-syntax ((operator (eql 'if)) cst)
  (check-cst-proper-list cst 'form-must-be-proper-list)
  (check-argument-count cst 2 3))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Checking LET and LET*

;;; Check the syntax of a single LET or LET* binding.  If the syntax
;;; is incorrect, signal an error.
(defun check-binding (cst)
  (cond ((or (and (cst:atom cst)
                  (symbolp (cst:raw cst)))
             (and (cst:consp cst)
                  (cst:atom (cst:first cst))
                  (symbolp (cst:raw (cst:first cst)))
                  (or (cst:null (cst:rest cst))
                      (and (cst:consp (cst:rest cst))
                           (cst:null (cst:rest (cst:rest cst)))))))
         nil)
        ((cst:atom cst)
         (error 'binding-must-be-symbol-or-list
                :expr (cst:raw cst)
                :origin (cst:source cst)))
        ((or (and (cst:atom (cst:rest cst))
                  (not (cst:null (cst:rest cst))))
             (not (cst:null (cst:rest (cst:rest cst)))))
         (error 'binding-must-have-length-one-or-two
                :expr (cst:raw cst)
                :origin (cst:source cst)))
        (t
         (error 'variable-must-be-a-symbol
                :expr (cst:raw (cst:first cst))
                :origin (cst:source (cst:first cst))))))

;;; Check the syntax of the bindings of a LET or a LET* form.  If the
;;; syntax is incorrect, signal an error and propose a restart for
;;; fixing it up.
(defun check-bindings (cst)
  (check-cst-proper-list cst 'bindings-must-be-proper-list)
  (loop for remaining = cst then (cst:rest remaining)
        until (cst:null remaining)
        do (check-binding (cst:first remaining))))

(defmethod check-special-form-syntax ((operator (eql 'let)) cst)
  (check-cst-proper-list cst 'form-must-be-proper-list)
  (check-argument-count cst 1 nil)
  (check-bindings (cst:second cst)))

(defmethod check-special-form-syntax ((operator (eql 'let*)) cst)
  (check-cst-proper-list cst 'form-must-be-proper-list)
  (check-argument-count cst 1 nil)
  (check-bindings (cst:second cst)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Checking LOAD-TIME-VALUE.

(defmethod check-special-form-syntax ((operator (eql 'load-time-value)) cst)
  (check-cst-proper-list cst 'form-must-be-proper-list)
  (check-argument-count cst 1 2)
  (let ((tail-cst (cst:rest (cst:rest cst))))
    (unless (cst:null tail-cst)
      ;; The HyperSpec specifically requires a "boolean"
      ;; and not a "generalized boolean".
      (unless (member (cst:raw (cst:first tail-cst)) '(nil t))
        (error 'read-only-p-must-be-boolean
               :expr (cst:first tail-cst)
               :origin (cst:source (cst:first tail-cst)))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Checking LOCALLY.

(defmethod check-special-form-syntax ((operator (eql 'locally)) cst)
  ;; The code in this method has been moved to the corresponding
  ;; method of convert-special.  Ultimately, the code of every method
  ;; on CHECK-SPECIAL-FORM-SYNTAX will be moved.
  (declare (ignore cst))
  nil)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Checking MACROLET.

(defmethod check-special-form-syntax ((operator (eql 'macrolet)) cst)
  (check-cst-proper-list cst 'form-must-be-proper-list)
  (check-argument-count cst 1 nil)
  (let ((definitions-cst (cst:second cst)))
    (unless (cst:proper-list-p definitions-cst)
      (error 'macrolet-definitions-must-be-proper-list
             :expr (cst:raw definitions-cst)
             :origin (cst:source definitions-cst)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Checking MULTIPLE-VALUE-CALL.

(defmethod check-special-form-syntax ((operator (eql 'multiple-value-call)) cst)
  (check-cst-proper-list cst 'form-must-be-proper-list)
  (check-argument-count cst 1 nil))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Checking MULTIPLE-VALUE-PROG1.

(defmethod check-special-form-syntax ((operator (eql 'multiple-value-prog1)) cst)
  (check-cst-proper-list cst 'form-must-be-proper-list)
  (check-argument-count cst 1 nil))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Checking PROGN.

(defmethod check-special-form-syntax ((operator (eql 'progn)) cst)
  (check-cst-proper-list cst 'form-must-be-proper-list))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Checking PROGV.

(defmethod check-special-form-syntax ((operator (eql 'progv)) cst)
  (check-cst-proper-list cst 'form-must-be-proper-list)
  (check-argument-count cst 2 nil))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Checking RETURN-FROM.

(defmethod check-special-form-syntax ((operator (eql 'return-from)) cst)
  (check-cst-proper-list cst 'form-must-be-proper-list)
  (check-argument-count cst 1 2)
  (let* ((block-name-cst (cst:second cst))
         (block-name (cst:raw block-name-cst)))
    (unless (symbolp block-name)
      (error 'block-name-must-be-a-symbol
             :expr block-name
             :origin (cst:source block-name-cst)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Checking SETQ.

(defmethod check-special-form-syntax ((operator (eql 'setq)) cst)
  (check-cst-proper-list cst 'form-must-be-proper-list)
  (unless (oddp (length (cst:raw cst)))
    (error 'setq-must-have-even-number-of-arguments
	   :expr cst
           :origin (cst:source cst)))
  (loop for remaining = (cst:rest cst) then (cst:rest (cst:rest remaining))
        until (cst:null remaining)
        do (let* ((variable-cst (cst:first remaining))
                  (variable (cst:raw variable-cst)))
             (unless (symbolp variable)
               (error 'setq-var-must-be-symbol
                      :expr variable
                      :origin (cst:source variable-cst))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Checking SYMBOL-MACROLET.
;;;
;;; FIXME: syntax check bindings

(defmethod check-special-form-syntax ((head (eql 'symbol-macrolet)) cst)
  (check-cst-proper-list cst 'form-must-be-proper-list)
  (check-argument-count cst 1 nil))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Checking TAGBODY.

(defmethod check-special-form-syntax ((head (eql 'tagbody)) cst)
  (check-cst-proper-list cst 'form-must-be-proper-list))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Checking THE.

(defmethod check-special-form-syntax ((head (eql 'the)) cst)
  (check-cst-proper-list cst 'form-must-be-proper-list)
  (check-argument-count cst 2 2))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Checking THROW

(defmethod check-special-form-syntax ((head (eql 'throw)) cst)
  (check-cst-proper-list cst 'form-must-be-proper-list)
  (check-argument-count cst 2 2))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Checking UNWIND-PROTECT

(defmethod check-special-form-syntax ((head (eql 'unwind-protect)) cst)
  (check-cst-proper-list cst 'form-must-be-proper-list)
  (check-argument-count cst 1 nil))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Checking CATCH.

(defmethod check-special-form-syntax ((head (eql 'catch)) cst)
  (check-cst-proper-list cst 'form-must-be-proper-list)
  (check-argument-count cst 1 nil))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Syntax checks for the PRIMOPs.

;;; This macro can be used to define a simple syntax-check method,
;;; where the form must be a proper list and it has a fixed number of
;;; arguments.
(defmacro define-simple-check (operation argcount)
  `(defmethod check-special-form-syntax ((operator (eql ',operation)) cst)
     (check-cst-proper-list cst 'form-must-be-proper-list)
     (check-argument-count cst ,argcount ,argcount)))

(define-simple-check cleavir-primop:eq 2)
(define-simple-check cleavir-primop:car 1)
(define-simple-check cleavir-primop:cdr 1)
(define-simple-check cleavir-primop:rplaca 2)
(define-simple-check cleavir-primop:rplacd 2)
(define-simple-check cleavir-primop:slot-read 2)
(define-simple-check cleavir-primop:slot-write 3)
(define-simple-check cleavir-primop:coerce 3)
(define-simple-check cleavir-primop:fixnum-less 2)
(define-simple-check cleavir-primop:fixnum-not-greater 2)
(define-simple-check cleavir-primop:fixnum-greater 2)
(define-simple-check cleavir-primop:fixnum-not-less 2)
(define-simple-check cleavir-primop:fixnum-equal 2)
(define-simple-check cleavir-primop:aref 5)
(define-simple-check cleavir-primop:aset 6)
(define-simple-check cleavir-primop:float-add 3)
(define-simple-check cleavir-primop:float-sub 3)
(define-simple-check cleavir-primop:float-mul 3)
(define-simple-check cleavir-primop:float-div 3)
(define-simple-check cleavir-primop:float-less 3)
(define-simple-check cleavir-primop:float-not-greater 3)
(define-simple-check cleavir-primop:float-equal 3)
(define-simple-check cleavir-primop:float-not-less 3)
(define-simple-check cleavir-primop:float-greater 3)
(define-simple-check cleavir-primop:float-sin 2)
(define-simple-check cleavir-primop:float-cos 2)
(define-simple-check cleavir-primop:float-sqrt 2)
(define-simple-check cleavir-primop:unreachable 0)
(define-simple-check cleavir-primop:ast 1)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Checking LET-UNINITIALIZED.

(defmethod check-special-form-syntax
    ((operator (eql 'cleavir-primop:let-uninitialized)) cst)
  (check-cst-proper-list cst 'form-must-be-proper-list)
  (check-argument-count cst 1 nil)
  (assert (cst:proper-list-p (cst:second cst)))
  (assert (every #'symbolp (cst:raw (cst:second cst)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Checking FUNCALL.

(defmethod check-special-form-syntax
    ((operator (eql 'cleavir-primop:funcall)) cst)
  (check-cst-proper-list cst 'form-must-be-proper-list)
  (check-argument-count cst 1 nil))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Checking MULTIPLE-VALUE-CALL (primop).

(defmethod check-special-form-syntax
    ((operator (eql 'cleavir-primop:multiple-value-call)) cst)
  (check-cst-proper-list cst 'form-must-be-proper-list)
  (check-argument-count cst 1 nil))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Checking VALUES.

(defmethod check-special-form-syntax
    ((operator (eql 'cleavir-primop:values)) cst)
  (check-cst-proper-list cst 'form-must-be-proper-list))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Checking TYPEQ.

(defmethod check-special-form-syntax
    ((operator (eql 'cleavir-primop:typeq)) cst)
  (check-cst-proper-list cst 'form-must-be-proper-list)
  (check-argument-count cst 2 2))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Checking FIXNUM-ADD

(defmethod check-special-form-syntax
    ((operator (eql 'cleavir-primop:fixnum-add)) cst)
  (check-cst-proper-list cst 'form-must-be-proper-list)
  (check-argument-count cst 3 3))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Checking FIXNUM-SUB

(defmethod check-special-form-syntax
    ((operator (eql 'cleavir-primop:fixnum-sub)) cst)
  (check-cst-proper-list cst 'form-must-be-proper-list)
  (check-argument-count cst 3 3))
