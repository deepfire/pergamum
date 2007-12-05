(in-package :pergamum)

(defun %typespec-unsigned-byte-32-p (spec)
  (equal spec '(unsigned-byte 32)))

(defun %typespec-unsigned-byte-8-p (spec)
  (equal spec '(unsigned-byte 8)))

(deftype typespec-unsigned-byte-32 () `(satisfies %typespec-unsigned-byte-32-p))
(deftype typespec-unsigned-byte-8 () `(satisfies %typespec-unsigned-byte-8-p))
(deftype permissible-extent-list-typespec () `(or typespec-unsigned-byte-8 typespec-unsigned-byte-32))

(defclass extent-list ()
  ((element-type :accessor extent-list-element-type :initarg :element-type :type permissible-extent-list-typespec)
   (extents :accessor extent-list-extents :initform nil :type list)))

(defclass u32-extent-list (extent-list)
  ((element-type :type typespec-unsigned-byte-32)))

(defclass u8-extent-list (extent-list)
  ((element-type :type typespec-unsigned-byte-8)))

(deftype extent () `(cons (unsigned-byte 32) vector))

(defun make-extent (base vector)
  (declare ((unsigned-byte 32) base) (vector vector))
  (cons base vector))

(defun extent-base (extent)
  (declare (extent extent))
  (car extent))

(defun extent-data (extent)
  (declare (extent extent))
  (cdr extent))

(defun extent-length (extent)
  (declare (extent extent))
  (array-dimension (extent-data extent) 0))

(defmethod print-object ((obj extent-list) stream)
  (format stream "#<EXTENT-LIST")
  (dolist (extent (extent-list-extents obj))
    (format stream " (~X:~X)" (extent-base extent) (+ (extent-base extent) (extent-length extent))))
  (format stream ">"))

(defun point-in-extent-p (extent p)
  (declare ((unsigned-byte 32) p) (extent extent))
  (and (>= p (extent-base extent)) (< p (+ (extent-base extent) (extent-length extent)))))

(defun extents-intersect-p (x y)
  (declare (extent x y))
  (and (plusp (extent-length x)) (plusp (extent-length y))
       (or (point-in-extent-p x (extent-base y)) (point-in-extent-p x (+ (extent-base y) (extent-length y) -1)))))

(defun extent-list-insert (extent-list vector base)
  (declare (extent-list extent-list) ((unsigned-byte 32) base) (vector vector))
  (push (make-extent base vector) (extent-list-extents extent-list)))

(defun extent-list-adjoin (extent-list vector base)
  (declare (extent-list extent-list) ((unsigned-byte 32) base) (vector vector))
  (let ((new-extent (make-extent base vector)))
    (when (find-if (curry #'extents-intersect-p new-extent) (extent-list-extents extent-list))
      (error "vector ~S at base ~S collides with extent list ~S." vector base extent-list))
    (push new-extent (extent-list-extents extent-list))))

(defun merge-extent-lists (to what)
  "Adjoin all extents from the list WHAT to the list TO."
  (declare (extent-list what to))
  (dolist (extent (extent-list-extents what))
    (extent-list-adjoin to (extent-data extent) (extent-base extent))))

(defun extent-list-compatible-vector-p (extent-list vector)
  (equal (extent-list-element-type extent-list) (array-element-type vector)))

(defun extent-list-grow (extent-list length base &key check-p)
  (let ((vector (make-array length :element-type (extent-list-element-type extent-list) :initial-element 0)))
    (first
     (if check-p
	 (extent-list-adjoin extent-list vector base)
	 (extent-list-insert extent-list vector base)))))

(defmacro do-extent-list-vectors ((basevar vectorvar) extent-list &body body)
  `(iter (for (,basevar . ,vectorvar) in (extent-list-extents ,extent-list))
	 ,@body))

(defun extent-list-vector-by-base (extent-list base)
  (cdr (find base (extent-list-extents extent-list) :key #'car)))

(defun serialize-extent-list (stream extent-list)
  (let ((*print-base* 16) (*print-array* t) (*print-length* nil))
    (and (print (list :extent-list (extent-list-element-type extent-list)) stream)
	 (print (extent-list-extents extent-list) stream)
	 t)))

(defun unserialize-extent-list (stream)
  (let ((*read-base* 10))
    (destructuring-bind (magic element-type) (read stream)
      (unless (eq magic :extent-list)
	(error "Unrecognized extent list serialization format: magic mismatch: ~S instead of ~S." magic :extent-list))
      (unless (typep element-type 'permissible-extent-list-typespec)
	(error "Bad extent list element type: ~S." element-type))
      (let ((*read-base* 16) (*read-eval* nil)
	    (extent-list (make-instance (ecase (second element-type)
					  (8 'u8-extent-list)
					  (32 'u32-extent-list))
					:element-type element-type)))
	(loop :for (base . data) :in (read stream) :do
	  (map-into (extent-data (extent-list-grow extent-list (length data) base)) #'identity data))
	(setf (extent-list-extents extent-list) (nreverse (extent-list-extents extent-list)))
	extent-list))))

(defun extent-lists-equal (a b)
  (and (= (length (extent-list-extents a)) (length (extent-list-extents b)))
       (loop :for (a-base . a-data) :in (extent-list-extents a)
	     :for (b-base . b-data) :in (extent-list-extents b)
	  :do (unless (and (= a-base b-base)
			   (equalp a-data b-data))
		(return nil))
	  :finally (return t))))