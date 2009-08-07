;;; -*- Mode: Lisp -*-

(defpackage :pergamum.system
  (:use :cl :asdf))

(in-package :pergamum.system)

(defsystem :pergamum
  :depends-on (:alexandria :iterate :cl-fad)
  :components
  (;; tier 0
   (:file "package")
   ;; tier 1
   (:file "alignment" :depends-on ("package"))
   (:file "basis" :depends-on ("package"))
   (:file "binary" :depends-on ("package"))
   (:file "classes" :depends-on ("package"))
   (:file "conditions" :depends-on ("package"))
   (:file "forms" :depends-on ("package"))
   (:file "functions" :depends-on ("package"))
   (:file "numbers" :depends-on ("package"))
   (:file "packages" :depends-on ("package"))
   (:file "mop" :depends-on ("package"))
   (:file "read" :depends-on ("package"))
   ;; tier 2
   (:file "lists" :depends-on ("basis"))
   (:file "streams" :depends-on ("basis"))
   (:file "pathnames" :depends-on ("basis"))
   (:file "hash-table" :depends-on ("basis" "conditions"))
   (:file "pergamum" :depends-on ("basis"))
   (:file "objects" :depends-on ("forms"))
   (:file "extent" :depends-on ("basis" "alignment"))
   ;; tier 3
   (:file "files" :depends-on ("streams"))
   (:file "lambda-lists" :depends-on ("pergamum"))
   (:file "types" :depends-on ("extent"))
   (:file "u8-sequence" :depends-on ("alignment" "extent"))
   ;; tier 4
   (:file "bioable" :depends-on ("extent" "objects" "u8-sequence"))
   ;; expunge tier
   (:file "to-expunge" :depends-on ("bioable"))))
