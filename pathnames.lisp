(in-package :pergamum)


(defun subfile (directory-pathname sub &rest make-pathname-keywords)
  "Return a file pathname with name SUB in DIRECTORY-PATHNAME.
   MAKE-PATHNAME-KEYWORDS are passed to MAKE-PATHNAME."
  (merge-pathnames (apply #'make-pathname :directory `(:relative ,@(butlast sub)) :name (lastcar sub) make-pathname-keywords) (or directory-pathname *default-pathname-defaults*)))

(defun subfile* (directory-pathname &rest sub)
  "Return a file pathname with name SUB in DIRECTORY-PATHNAME."
  (merge-pathnames (make-pathname :directory `(:relative ,@(butlast sub)) :name (lastcar sub)) (or directory-pathname *default-pathname-defaults*)))

(defun subdirectory (directory-pathname sub &rest make-pathname-keywords)
  "Return a subdirectory pathname with name SUB in DIRECTORY-PATHNAME.
   MAKE-PATHNAME-KEYWORDS are passed to MAKE-PATHNAME."
  (merge-pathnames (apply #'make-pathname :directory `(:relative ,@sub) make-pathname-keywords) (or directory-pathname *default-pathname-defaults*)))

(defun subdirectory* (directory-pathname &rest sub)
  "Return a subdirectory pathname with name SUB in DIRECTORY-PATHNAME."
  (merge-pathnames (make-pathname :directory `(:relative ,@sub)) (or directory-pathname *default-pathname-defaults*)))

(defun flatten-path-list (path &optional absolute directory-p)
  "Transform a list of strings in PATH into a string constituting of 
   individual strings interspersed with slashes.
   A leading slash is prepended when ABSOLUTE is non-nil.
   A trailing slash is appended when DIRECTORY-P is non-nil."
  (apply #'concatenate 'simple-base-string
         (xform directory-p (rcurry #'append (list "/"))
                (xform (not absolute) #'rest (mapcan (curry #'list "/") path)))))

(defun fuse-downcased-string-path-list (path &optional absolute)
  "Transform a list of strings in PATH into a string constituting of 
   individual strings interspersed with slashes.
   A leading slash is prepended when ABSOLUTE is non-nil."
  (apply #'concatenate 'simple-base-string
         (xform (not absolute) #'rest (mapcan (compose (curry #'list "/") #'string-downcase #'string) path))))
