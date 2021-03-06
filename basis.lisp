;;; -*- Mode: LISP; Syntax: COMMON-LISP; Package: PERGAMUM; Base: 10 -*-
;;;

(in-package :pergamum)


(defun maybe-list (x)
  "Return either X wrapped in a list, when it's non-NIL, or NIL."
  (when x (list x)))

(defun symbol-macro-p (x env)
  "See if X denotes a symbol macro within ENV."
  (and (symbolp x)
       (nth-value 1 (macroexpand-1 x env))))

(defmacro currily (func &rest argspec)
  (with-gensyms (arg)
    `(lambda (,arg) (funcall ,func ,@(subst-if arg (lambda (x) (and (symbolp x) (string= x "_"))) argspec)))))

(defmacro progn-1 (&body body)
  `(multiple-value-prog1
       (progn
         ,@(butlast body))
     ,(lastcar body)))

(defmacro lret (bindings &body body) 
  "A @macro{let}-construct which returns its last binding." 
  `(let ,bindings ,@body 
        ,(let ((x (car (last bindings)))) 
              (if (atom x) 
                  x 
                  (car x))))) 

(defmacro lret* (bindings &body body) 
  "A @macro{let*}-construct which returns its last binding." 
  `(let* ,bindings ,@body 
         ,(let ((x (car (last bindings)))) 
               (if (atom x) 
                   x 
                   (car x)))))

(defmacro if-let* (bindings then-form &optional else-form)
  "Creates new variable bindings, and conditionally executes either THEN-FORM
or ELSE-FORM. ELSE-FORM defaults to NIL.

BINDINGS must be a list of bindings of the form:

 ((variable-1 initial-form-1)
  (variable-2 initial-form-2)
  ...
  (variable-n initial-form-n))

Each initial-form is executed in turn, and the variable bound to the
corresponding value. Initial-form expressions can refer to variables
previously bound by the IF-LET*.

If all variables are true after the bindings are complete, the THEN-FORM is
executed with the bindings in effect, otherwise the ELSE-FORM is executed with
the bindings NOT in effect."
  (with-gensyms (%if-let* block else-tag)
    `(macrolet ((,%if-let* (rec-bindings)
                  (let* ((,%if-let* ',%if-let*)
                         (,block ',block)
                         (,else-tag ',else-tag))
                    (destructuring-bind (first-binding &rest rest) rec-bindings
                      `(let (,first-binding)
                         (if ,(car first-binding)
                             ,(if (endp rest)
                                  `(return-from ,,block ,',then-form)
                                  `(,,%if-let* ,rest))
                             (go ,,else-tag)))))))
       (block ,block
         (tagbody
            (,%if-let* ,bindings)
            ,else-tag
            (return-from ,block ,else-form))))))

(defmacro if-maybe-let (bindings &body (then-form &optional else-form))
  "Evaluates value forms in BINDINGS, and conditionally executes
either THEN-FORM with BINDINGS established, or ELSE-FORM, without
BINDINGS.  ELSE-FORM defaults to NIL.

BINDINGS must be either single binding of the form:

 (variable initial-form)

or a list of bindings of the form:

 ((variable-1 initial-form-1)
  (variable-2 initial-form-2)
  ...
  (variable-n initial-form-n))

All initial-forms are executed sequentially in the specified order. Then,
if all initial forms evaluated to true values, all the variables are bound
to these values and THEN-FORM is executed with these bindings in effect,
otherwise the ELSE-FORM is executed, without additional bindings."
  (let* ((binding-list (if (and (consp bindings) (symbolp (car bindings)))
                           (list bindings)
                           bindings))
         (temp-variables (make-gensym-list (length binding-list)))
         (variables (mapcar #'car binding-list)))
    `(let ,(mapcar #'list temp-variables (mapcar #'cadr binding-list))
       (if (and ,@temp-variables)
           (let ,(mapcar #'list variables temp-variables)
             ,then-form)
           ,else-form))))

(defmacro case-let (binding &body clauses)
  "BINDING is a single variable binding established for CLAUSES,
   which are handled as if by CASE.

   WARNING: a better docstring than this one is needed."
  `(let (,binding)
     (case ,(first binding)
       ,@clauses)))

(defun fcase (bool then-fn else-fn)
  "Return a function APPLYing either THEN-FN, when BOOL is true or ELSE-FN,
   otherwise."
  (lambda (&rest x)
    (if bool
        (apply then-fn x)
        (apply else-fn x))))

(defun fcase-1 (bool then-fn else-fn)
  "Return a function FUNCALLing either THEN-FN, when BOOL is true or ELSE-FN,
   otherwise."
  (lambda (x)
    (if bool
        (funcall then-fn x)
        (funcall else-fn x))))

(defun fif (if-fn then-fn else-fn)
  "Return a function APPLYing either THEN-FN or ELSE-FN to its arguments, 
   depending on the return value of IF-FN, applied to the same arguments."
  (lambda (&rest x)
    (if (apply if-fn x)
        (apply then-fn x)
        (apply else-fn x))))

(defun fif-1 (if-fn then-fn else-fn)
  "Return a function FUNCALLing either THEN-FN or ELSE-FN with its argument, 
   depending on the return value of IF-FN, passed the same argument."
  (lambda (x)
    (if (funcall if-fn x)
        (funcall then-fn x)
        (funcall else-fn x))))

(defun map-remove-if-not (xform test &rest sequences)
  "Essentially (mapcar XFORM (remove nil (apply #'mapcar TEST SEQUENCES))), 
   but works when NIL is present in SEQUENCES."
  (labels ((iterate (acc sequences)
                    (if (notany #'null sequences)
                        (let ((crop (mapcar #'car sequences))
                              (rest (mapcar #'cdr sequences)))
                          (iterate (if (apply test crop)
                                       (cons (apply xform crop) acc)
                                       acc)
                                   rest))
                        acc)))
    (nreverse (iterate nil sequences))))

(defun maybe-capture-subform (condition form accessor)
  `(or (and ,condition (,accessor ,form)) (gensym)))

(defmacro with-optional-subform-captures ((&rest specs) &body body)
  `(let ,(iter (for (vars accessors condition form) in specs)
               (appending (mapcar (lambda (var accessor)
                                    (list var (maybe-capture-subform condition form accessor)))
                                  vars accessors)))
     ,@body))

(defun syncformat (stream format-control &rest args)
  "Same as FORMAT, but also call FINISH-OUTPUT on STREAM."
  (apply #'format stream format-control args)
  (finish-output (if (eq stream t) *standard-output* stream)))

(defun prepend (something list &key (test (complement #'null)) (key #'identity))
  (if (funcall test (funcall key something))
      (list* something list)
      list))
