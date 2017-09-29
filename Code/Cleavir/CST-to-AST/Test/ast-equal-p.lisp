(cl:in-package #:cleavir-cst-to-ast-test)

(defun ast-equal-p (x y)
  (let ((table (make-hash-table :test #'equalp)))
    (flet ((report-difference (x y)
             (format *trace-output*
                     "difference ~s ~s" x y)))
      (labels ((aux (x y)
                 (cond ((gethash (cons x y) table)
                        t)
                       ((nth-value 1 (gethash (cons x y) table))
                        (report-difference x y)
                        nil)
                       ((and (typep x 'cleavir-ast:ast)
                             (typep y 'cleavir-ast:ast))
                        (and (eq (class-of x) (class-of y))
                             (setf (gethash (cons x y) table) t)
                             (setf (gethash (cons x y) table)
                                   (loop for save-info in (cleavir-io:save-info x)
                                         always (aux
                                                 (funcall (cadr save-info) x)
                                                 (funcall (cadr save-info) y))))))
                       ((or (typep x 'cleavir-ast:ast)
                            (typep y 'cleavir-ast:ast))
                        (report-difference x y)
                        nil)
                       ((and (listp x)
                             (listp y))
                        (and (= (length x) (length y))
                             (setf (gethash (cons x y) table) t)
                             (setf (gethash (cons x y) table)
                                   (loop for element1 in x
                                         for element2 in y
                                         always (aux element1 element2)))))
                       ((and (symbolp x)
                             (symbolp y))
                        (string= (symbol-name x) (symbol-name y)))
                       (t
                        (setf (gethash (cons x y) table)
                              (equal x y))))))
        (aux x y)))))
