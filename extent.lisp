;;; -*- Mode: LISP; Syntax: COMMON-LISP; Package: PERGAMUM; Base: 10 -*-
;;;

(in-package :pergamum)

(defclass baseless-extent ()
  ((data :accessor extent-data :type vector :initarg :data)))

(defclass extent (baseless-extent)
  ((base :accessor extent-base :type integer :initarg :base)))
 
(deftype extent-spec () `(cons integer (integer 0)))
(deftype extentile () `(or extent extent-spec))

(defun check-extent (extent)
  "See if EXTENT is a valid extentile."
  (unless (etypecase extent
            (cons (and (realp (car extent)) (realp (cdr extent))))
            (extent (and (realp (extent-base extent)) (typep (extent-data extent) 'vector))))
    (error "~@<~S is neither a valid extent nor a valid extent spec.~:@>" extent)))

(defmethod print-object ((o extent) stream)
  (print-unreadable-object (o stream)
    (format stream "~A ~X:~X" (type-of o) (extent-base o) (end o))))

(defun make-extent (type base vector-or-size &rest keys &key element-type &allow-other-keys)
  "Make an extent of TYPE with BASE and, depending on whether VECTOR-OR-DATA
is a positive integer, or a vector, either the value of VECTOR-OF-DATA, or
a new data vector of length VECTOR-OR-SIZE, with optionally specified
ELEMENT-TYPE, which defaults either to the element type of VECTOR-OR-SIZE,
when appropriate, or to '(UNSIGNED-BYTE 8), when VECTOR-OR-SIZE is an integer.
KEYS, except ELEMENT-TYPE, are passed as-is to MAKE-INSTANCE."
  (declare (type integer base) (type (or vector (integer (0))) vector-or-size))
  (apply #'make-instance type
         :base base
         :data (let* ((vectorp (vectorp vector-or-size))
                      (element-type (or element-type
                                        (if vectorp
                                            (array-element-type vector-or-size)
                                            '(unsigned-byte 8)))))
                 (if (and vectorp (subtypep (array-element-type vector-or-size) element-type))
                     vector-or-size
                     (apply #'make-array (if vectorp (length vector-or-size) vector-or-size) :element-type element-type (when vectorp `(:initial-contents ,vector-or-size)))))
         (remove-from-plist keys :element-type :base :data)))

(defun extent (base size-or-data)
  "Make an extentile with BASE, with type dependent on type of SIZE-OR-DATA.
If the latter is a vector, then a generic extent is made, otherwise
the result is an extent spec."
  (etypecase size-or-data
    (vector (make-extent 'extent base size-or-data))
    (real (cons base size-or-data))))

(defun base (extent)
  "Given EXTENT, return its base."
  (declare (type extentile extent))
  (etypecase extent
    (cons (car extent))
    (extent (extent-base extent))))

(defun (setf base) (value extent)
  "Given EXTENT, return its base."
  (declare (type extentile extent))
  (etypecase extent
    (cons (setf (car extent) value))
    (extent (setf (extent-base extent) value))))

(defun size (extent)
  "Given EXTENT, return its size."
  (declare (type extentile extent))
  (etypecase extent
    (cons (cdr extent))
    (extent (array-dimension (extent-data extent) 0))))

(defun (setf size) (value extent)
  "Change EXTENT's size to VALUE."
  (etypecase extent
    (cons (setf (cdr extent) value))
    (extent (error "~@<Extent size modification is not supported.~:@>"))))

(defun end (extent)
  "Given EXTENT, return its end."
  (declare (type extentile extent))
  (+ (base extent) (size extent)))

(defun inp (extent p)
  "Given EXTENT, see if absolute value P is within it."
  (declare (type extentile extent) (type integer p))
  (if (plusp (size extent))
      (>=/< p (base extent) (end extent))
      (>/=< p (end extent) (base extent))))

(defun intersectp (x y)
  "Determine whether extents X and Y intersect."
  (declare (type extentile x y))
  (and (not (or (zerop (size x)) (zerop (size y))))
       (or (inp x (base y))
           (inp x (+ (end y) (if (plusp (size y))
                                 1 -1))))))

(defun split-extent (extent offset &optional ignore-head ignore-tail)
  "Produce two subextents of EXTENT, by splitting it at OFFSET.
IGNORE-HEAD and IGNORE-TAIL control suppression."
  (values (unless ignore-head (make-extent 'extent (extent-base extent) (subseq (extent-data extent) 0 offset)))
          (unless ignore-tail (make-extent 'extent (+ (extent-base extent) offset) (subseq (extent-data extent) offset)))))

(defmacro with-split-extent ((head tail) extent offset &body body)
  "Execute BODY with HEAD and TAIL bound to EXTENT's subextents produced
by splitting it at OFFSET. Whenever HEAD or TAIL are NIL, the corresponding
subextent is not produced."
  (let ((headvar (or head (gensym)))
        (tailvar (or tail (gensym))))
    `(multiple-value-bind (,headvar ,tailvar) (split-extent ,extent ,offset ,(null head) ,(null tail))
       ,@(unless (and head tail) `((declare (ignore ,@(unless head `(,headvar)) ,@(unless tail `(,tailvar))))))
       ,@body)))

(defun subextent* (extent &optional (start 0) end)
  "Produce a subextent covering a part of EXTENT between START and END, 
the latter of which defaults to NIL, which is interpreted as the end
of EXTENT. The returned extent is of most generic type."
  (if (consp extent)
      (extent (+ (car extent) start) (- (or end (cdr extent)) start))
      (make-extent 'extent (+ (extent-base extent) start)
                   (subseq (extent-data extent) start (or end (array-dimension (extent-data extent) 0))))))

(defun subextent (extent spec)
  "Produce a subextent covering a part of EXTENT specified by SPEC,
which is interpreted to be EXTENT-relative, and whose size might be NIL, 
which is interpreted as the end of EXTENT. The returned extent is of most
generic type. The returned extent is of most generic type."
  (subextent* extent (car spec) (cdr spec)))

(defun subextent-abs* (extent &optional (start (extent-base extent)) end)
  "Produce a subextent covering a part of EXTENT between absolute values
of START and END, the latter of which defaults to NIL, which is interpreted
as absolute end of EXTENT. The returned extent is of most generic type."
  (subextent* extent (- start (extent-base extent)) (when end (- end (extent-base extent)))))

(defun subextent-abs (extent spec)
  "Produce a subextent covering a part of EXTENT specified by SPEC, whose 
size might be NIL, which is interpreted as the end of EXTENT. The returned
extent is of most generic type."
  (subextent-abs* extent (car spec) (cdr spec)))

(defun extent-mask (extent extents)
  "Produce an extentile list consisting of EXTENT's subextentiles not present
in EXTENTS, which must be sorted and completely fit EXTENT. The resulting 
extentiles are of most generic type."
  (append
   (when-let* ((head-length (- (base (first extents)) (base extent)))
               (plusp head-length))
     (list (subextent* extent 0 head-length)))
   (iter (for (hole . rest) on extents)
         (when-let* ((inter-start (end hole))
                     (inter-size (- (if-let ((next (first rest)))
                                            (base next)
                                            (end extent))
                                    inter-start))
                     (plusp inter-size)
                     (inter-start-rel (- inter-start (base extent))))
           (collect (extent inter-start
                            (if (consp extent)
                                inter-size
                                (subseq extent inter-start-rel (+ inter-start-rel inter-size)))))))))

(defun rebase (fn extent)
  (declare (type (function (integer) integer) fn) (type extentile extent))
  "Make a new extentile, by calling FN on EXTENT's base, combining it
with the rest of data in EXTENT."
  (extent (funcall fn (base extent)) (if (consp extent) (cdr extent) (extent-data extent))))

(defun nrebase (fn extent)
  "Replace EXTENT's base with result of calling FN on it."
  (declare (type (function (integer) integer) fn) (type extentile extent))
  (setf (extent-base extent) (funcall fn (base extent)))
  extent)

(defun coerce-extent (extent type)
  "Create a new extent with EXTENT's data vector coerced to TYPE."
  (declare (type extent extent))
  (make-extent 'extent (extent-base extent) (coerce (extent-data extent) type)))

(defun ncoerce-extent (extent type)
  "Replace the data vector in EXTENT with one coerced to TYPE."
  (declare (type extent extent))
  (setf (extent-data extent) (coerce (extent-data extent) type))
  extent)

(defun extent-data-equalp (e1 e2)
  "Return T if data vectors of E1 and E2 match according to EQUALP."
  (declare (type extent e1 e2))
  (equalp (extent-data e1) (extent-data e2)))

(defun extent-equalp (e1 e2)
  "Return T if data vectors of E1 and E2 match according to EQUALP,
and their base addresses match as well."
  (declare (type extent e1 e2))
  (and (extent-data-equalp e1 e2)
       (= (extent-base e1) (extent-base e2))))

;;;
;;; Extent specs.
;;;
(defun extent-spec (extent)
  (declare (type extent extent))
  (cons (extent-base extent) (length (extent-data extent))))

(defun print-extent-spec (stream spec colon at-sign)
  (declare (ignore colon at-sign))
  (pprint-logical-block (stream spec)
    (format stream "(~X:~X)" (car spec) (+ (car spec) (cdr spec)))))

(defun print-extent (stream extent)
  (print-u8-sequence stream (extent-data extent) :address (extent-base extent)))

(defgeneric serialize-extent (stream extent)
  (:method (stream (o extent))
    (print (cons (extent-base o) (extent-data o)) stream)))

(defun serialize-extent-list (stream extents)
  "Write out EXTENTS as a list of base/data conses into STREAM."
  (write-char #\( stream)
  (dolist (e extents)
    (serialize-extent stream e))
  (write-char #\) stream))

(defun read-extent-list (stream &key (type 'extent) (element-type '(unsigned-byte 8)) (initarg-generator-fn (constantly nil)))
  "Construct a list of extents of TYPE by calling READ on STREAM.
The extent data vectors will have ELEMENT-TYPE property, defaulting
to (UNSIGNED-BYTE 8). Extent object initargs are produced by calling
INITARG-GENERATOR-FN with base and data arguments."
  (iter (for (base . data) in (read stream))
        (collect (apply #'make-extent type base data :element-type element-type (funcall initarg-generator-fn base data)))))

(defun extent-reader (stream)
  (destructuring-bind (base . data) (read stream)
    (make-extent 'extent base data :element-type '(unsigned-byte 8))))

;;;
;;; Utilities. Crap ones, admittedly.
;;;
(defmacro do-extent-spec-aligned-blocks (alignment (addr len spec) &body body)
  "Execute body with ADDR being set to all successive beginnings of ALIGNMENT-aligned blocks covering the extent specified by SPEC."
  (once-only (alignment spec)
    `(iter (for ,addr from (align-down ,alignment (base ,spec)) below (end ,spec) by ,alignment)
           (for ,len = (min ,alignment (- (end ,spec) ,addr)))
           ,@body)))

(defmacro with-aligned-extent-spec-pieces (alignment (prehead head body tail &optional posttail) extent-spec &body innards)
  "Bind the HEAD, BODY and TAIL pieces of EXTENT-SPEC, with possible destructurisation, as mandated by aligning it by ALIGNMENT (evaluated)."
  (let ((d-prehead (consp prehead)) (d-head (consp head)) (d-body (consp body)) (d-tail (consp tail)) (d-posttail (consp posttail)))
    (with-optional-subform-captures (((prehead-base prehead-length) (car cadr) d-prehead prehead)
                                     ((head-base head-length) (car cadr) d-head head)
                                     ((body-base body-length) (car cadr) d-body body)
                                     ((tail-base tail-length) (car cadr) d-tail tail)
                                     ((posttail-base posttail-length) (car cadr) d-posttail posttail))
      (with-gensyms (base length alignment-mask)
        (once-only (alignment extent-spec)
          `(let* ((,alignment-mask (1- ,alignment))
                  (,base (car ,extent-spec))
                  (,length (cdr ,extent-spec))
                  (,prehead-base (logandc1 ,alignment-mask ,base))
                  (,prehead-length (logand ,alignment-mask ,base))
                  (,head-base ,base)
                  (,head-length (min ,length (logand ,alignment-mask (- ,alignment ,prehead-length))))
                  (,body-base (+ ,head-base ,head-length))
                  (,body-length (logandc1 ,alignment-mask (- ,length ,head-length)))
                  (,tail-base (+ ,body-base ,body-length))
                  (,tail-length (- ,length ,head-length ,body-length))
                  ,@(when posttail `((,posttail-base (+ ,tail-base ,tail-length))))
                  ,@(when posttail `((,posttail-length (- ,alignment (logand ,alignment-mask (+ ,tail-base ,tail-length))))))
                  ,@(unless d-prehead `((,prehead (cons ,prehead-base ,prehead-length))))
                  ,@(unless d-head `((,head (cons ,base ,head-length))))
                  ,@(unless d-body `((,body (cons ,body-base ,body-length))))
                  ,@(unless d-tail `((,tail (cons ,tail-base ,tail-length))))
                  ,@(unless (or (null posttail) d-posttail) `((,posttail (cons ,posttail-base ,posttail-length)))))
             (declare (ignorable ,prehead-base ,prehead-length ,head-base ,head-length ,body-base ,body-length ,tail-base ,tail-length ,@(when posttail `(,posttail-base ,posttail-length))))
             ,@innards))))))
