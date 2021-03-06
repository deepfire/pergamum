;;; -*- Mode: LISP; Syntax: COMMON-LISP; Package: PERGAMUM; Base: 10; indent-tabs-mode: nil; show-trailing-whitespace: t -*-
;;;

(in-package :pergamum)


(defun eq-to (val)
  "Produce a predicate function, testing whether its single argument
is EQ to VAL."
  (lambda (x) (eq x val)))

(defun eql-to (val)
  "Produce a predicate function, testing whether its single argument
is EQL to VAL."
  (lambda (x) (eql x val)))

(defun equal-to (val)
  "Produce a predicate function, testing whether its single argument
is EQUAL to VAL."
  (lambda (x) (equal x val)))

(defun equalp-to (val)
  "Produce a predicate function, testing whether its single argument
is EQUALP to VAL."
  (lambda (x) (equalp x val)))

(defun =-to (val)
  "Produce a predicate function, testing whether its single argument
is = to VAL."
  (lambda (x) (= x val)))

(defun member-of (list &rest args &key key test test-not)
  "Produce a predicate function, testing whether its single argument
satisfies the MEMBER test with regard to LIST and, optionally, KEY,
TEST or TEST-NOT."
  (declare (ignore key test test-not))
  (lambda (x) (apply #'member x list args)))

(define-compiler-macro member-of (list &rest args &key key test test-not)
  (declare (ignore key test test-not))
  `(lambda (x) (member x ,list ,@args)))

(defun eq-member-of* (&rest elements)
  "Produce a predicate function, testing whether its single argument
satisfies the MEMBER test with regard to EQ-equality and the list of
ELEMENTS."
  (lambda (x) (member x elements :test #'eq)))

(defun eq-not-member-of* (&rest elements)
  "Produce a predicate function, testing whether its single argument
does not satisfy the MEMBER test with regard to EQ-equality and the
list of ELEMENTS."
  (lambda (x) (member x elements :test-not #'eq)))

(defun equal-member-of* (&rest elements)
  "Produce a predicate function, testing whether its single argument
satisfies the MEMBER test with regard to EQUAL-equality and the list
of ELEMENTS."
  (lambda (x) (member x elements :test #'equal)))

(defun equal-not-member-of* (&rest elements)
  "Produce a predicate function, testing whether its single argument
does not satisfy the MEMBER test with regard to EQUAL-equality and the
list of ELEMENTS."
  (lambda (x) (member x elements :test-not #'equal)))

(defun string=-member-of* (&rest elements)
  "Produce a predicate function, testing whether its single argument
satisfies the MEMBER test with regard to STRING=-equality and the list
of ELEMENTS."
  (lambda (x) (member x elements :test #'string=)))

(defun string=-not-member-of* (&rest elements)
  "Produce a predicate function, testing whether its single argument
does not satisfy the MEMBER test with regard to STRING+-equality and
the list of ELEMENTS."
  (lambda (x) (member x elements :test-not #'string=)))

(defun maybe (function arg)
  "Given a FUNCTION, return the result of applying ARG to it, when the
latter is non-NIL."
  (when arg
    (funcall function arg)))

(defun maybecall (bool function &rest args)
  "Given a FUNCTION, return the result of applying it to ARGS, when
BOOL is non-NIL."
  (when bool
    (apply function args)))

(defun xform (bool function &rest args)
  "Given a FUNCTION, either return the result of applying it to ARGS,
when BOOL is non-NIL, or return them as multiple values."
  (if bool
      (apply function args)
      (values-list args)))

(defun xform-if (predicate function &rest args)
  "Given a FUNCTION, either return the result of applying it to ARGS,
when PREDICATE applied to them yields non-NIL, or return them as
multiple values."
  (if (apply predicate args)
      (apply function args)
      (values-list args)))

(defun xform-if-not (predicate function &rest args)
  "Given a FUNCTION, either return the result of applying it to ARGS,
when PREDICATE applied to them yields NIL, or return them as multiple
values."
  (if (apply predicate args)
      (values-list args)
      (apply function args)))

(define-compiler-macro xform (&whole form bool function &rest args)
  (if (endp (rest args))
      `(if ,bool
           (funcall ,function ,(first args))
           ,(first args))
      form))

(define-compiler-macro xform-if (&whole form predicate function &rest args)
  (if (endp (rest args))
      `(if (funcall ,predicate ,(first args))
           (funcall ,function ,(first args))
           ,(first args))
      form))

(define-compiler-macro xform-if-not (&whole form predicate function &rest args)
  (if (endp (rest args))
      `(if (funcall ,predicate ,(first args))
           ,(first args)
           (funcall ,function ,(first args)))
      form))

(defun orp (&rest args)
  "Functional variant of OR."
  (some #'identity args))

(define-compiler-macro orp (&rest args)
  (case (length args)
    (0 'nil)
    (1 (first args))
    (t `(or ,@args))))

(defun andp (&rest args)
  "Functional variant of AND."
  (labels ((rec (rest) (cond ((endp (cdr rest)) (car rest))
                             ((car rest)        (rec (cdr rest)))
                             (t                 nil))))
    (rec args)))

(define-compiler-macro andp (&rest args)
  (case (length args)
    (0 't)
    (1 (first args))
    (t `(and ,@args))))

(defun compose* (&rest functions)
  "Return a function composed of FUNCTIONS, each of which must be a
function of two arguments, except the last one, which can accept an
arbitrary amount of arguments.  The resulting function requires at
least one argument per function provided plus the amount of arguments
required by the last function, minus one.  The value returned by the
resulting function is computed by first taking the last (1+ (-
N-TOTAL-ARGUMENTS (LENGTH FUNCTIONS))) arguments and applying the last
function to them, using the returned value to iteratively reduce the
remaining arguments with remaining functions, by applying, on each
step, the last remaining function to the last remaining argument and
the value obtained on the previous step.

Example: (FUNCALL (COMPOSE* #'CONS #'* #'+ #'LENGTH) :A 3 1 '(1)) => (:A . 6)"
  (when (null functions)
    (error "~@<Must specify at least one function.~:@>"))
  (reduce (lambda (f acc)
            (lambda (arg &rest args)
              (funcall f arg (apply acc args))))
          functions
          :from-end t))

(defun reduce* (fn initial-value &rest sequences)
  (if (every #'null sequences)
      initial-value
      (iter (for marker initially sequences then (mapcar #'cdr marker))
            (until (every #'null marker))
            (for value = (apply fn (if (first-iteration-p) initial-value value) (mapcar #'car marker)))
            (finally (return value)))))

(defun flist (&rest before-items)
  "Return a function which places its first argument as the last
element of a fresh list containing BEFORE-ITEMS."
  (lambda (x)
    (apply #'list (append before-items (list x)))))

(define-compiler-macro flist (&rest before-items)
  "Return a function which places its first argument as the last
element of a fresh list containing BEFORE-ITEMS."
  `(lambda (x)
     (list ,@before-items x)))

(defun latch (&rest args)
  "Produce a function which applies its first parameter to ARGS."
  (lambda (fn)
    (apply fn args)))

(defun arg (n)
  "Return a function returning its N'th argument, while ignoring others."
  (lambda (&rest args)
    (nth n args)))

(define-compiler-macro arg (&whole form n)
  (if (and (integerp n) (< n 10))
      (let ((syms (append (iter (for i below n) (collect (gensym "IGN")))
                          (list (gensym "RETARG")))))
        `(lambda (,@syms &rest rest)
           (declare (ignore ,@(butlast syms) rest))
           ,(lastcar syms)))
      form))

(defun bukkake-combine (&rest functions)
  "Return a function accepting an indefinite amount of values,
applying all FUNCTIONS to them in turn, returning the value of last
application.  Name courtesy of Andy Hefner."
  (lambda (&rest params)
    (mapc (rcurry #'apply params) (butlast functions))
    (apply (lastcar functions) params)))

(defun apply/find-if (pred fn &rest args)
  "Return the first member of a set computed by application of FN to
ARGS, which also satisfies PRED. The second value indicates whether
the set returned by FN was non-empty."
  (declare (type (function (*) list) fn))
  (let ((set (apply fn args)))
    (values (find-if pred set) (not (null set)))))

(define-compiler-macro apply/find-if (&whole whole pred fn &rest args)
  (if (null (cdr args))
      (with-gensyms (set)
        (once-only (pred fn)
         `(let ((,set (funcall ,fn ,(car args))))
            (values (find-if ,pred ,set) (not (null ,set))))))
      whole))

(defun iterate-until (pred function &rest initial-args)
  "Given an INITIAL parameter value and a FUNCTION, iteratily apply
the latter to the parameter, getting the new parameter, returning the
last non-NIL one."
  (iter (with params = initial-args)
    (for result = (multiple-value-list (apply function params)))
    (until (apply pred result))
    (setf params result)
    (finally (return params))))

(defun collect-until (pred function &rest initial-args)
  "Given an INITIAL parameter value and a FUNCTION, iteratively apply
the latter to the parameter, getting the new parameter, until it
becomes NIL, collecting all non-NIL result parameters."
  (iter (with params = initial-args)
    (for result = (multiple-value-list (apply function params)))
    (until (apply pred result))
    (collect result)
    (setf params result)))
