(in-package :pergamum)

(defclass baseless-extent ()
  ((data :accessor extent-data :type vector :initarg :data)))

(defclass extent (baseless-extent)
  ((base :accessor extent-base :type integer :initarg :base)))

(defun make-extent (type base vector &rest keys &key (element-type (array-element-type vector) element-type-p) &allow-other-keys)
  (declare (type integer base) (type vector vector))
  (apply #'make-instance type
         :base base
         :data (if (and element-type-p (subtypep (array-element-type vector) element-type))
                   vector
                   (make-array (length vector) :element-type element-type :initial-contents vector))
         (remove-from-plist keys :element-type :base :data)))

(defun extent-length (extent)
  (declare (type baseless-extent extent))
  (array-dimension (extent-data extent) 0))

(defun extent-end (extent)
  (declare (type extent extent))
  (+ (extent-base extent) (extent-length extent)))

(defun point-extent-base-p (extent p)
  (declare (type integer p) (type extent extent))
  (= p (extent-base extent)))

(defun point-in-extent-p (extent p)
  (declare (type integer p) (type extent extent))
  (and (>= p (extent-base extent)) (< p (+ (extent-base extent) (extent-length extent)))))

(defun extents-intersect-p (x y)
  (declare (type extent x y))
  (and (plusp (extent-length x)) (plusp (extent-length y))
       (or (point-in-extent-p x (extent-base y)) (point-in-extent-p x (+ (extent-base y) (extent-length y) -1)))))

(defun extent-spec (extent)
  (declare (type extent extent))
  (cons (extent-base extent) (length (extent-data extent))))
 
(deftype extent-spec () `(cons integer (integer 0)))

(defun make-extent-spec (base length)
  (cons base length))

(defun print-extent-spec (stream spec colon at-sign)
  (declare (ignore colon at-sign))
  (pprint-logical-block (stream spec)
    (format stream "(~X:~X)" (car spec) (+ (car spec) (cdr spec)))))

(defun print-extent (stream extent &optional (endianness :little-endian))
  (print-u8-sequence stream (extent-data extent) :address (extent-base extent) :endianness endianness))

(defgeneric serialize-extent (stream extent)
  (:method (stream (o extent))
    (print (cons (extent-base o) (extent-data o)) stream)))

(defun extent-spec-base (spec)
  (car spec))

(defun extent-spec-length (spec)
  (cdr spec))

(defun extent-spec-end (spec)
  (+ (car spec) (cdr spec)))

(defmacro do-extent-spec-aligned-blocks (alignment (addr len spec) &body body)
  "Execute body with ADDR being set to all successive beginnings of ALIGNMENT-aligned blocks covering the extent specified by SPEC."
  (once-only (alignment spec)
    `(iter (for ,addr from (align-down ,alignment (extent-spec-base ,spec)) below (extent-spec-end ,spec) by ,alignment)
           (for ,len = (min ,alignment (- (extent-spec-end ,spec) ,addr)))
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
