#|
  This file is a part of Caveman package.
  URL: http://github.com/fukamachi/caveman
  Copyright (c) 2011 Eitarow Fukamachi <e.arrows@gmail.com>

  Caveman is freely distributable under the LLGPL License.
|#

(clack.util:namespace caveman.app
  (:use :cl
        :clack
        :clack.builder
        :clack.middleware.static
        :clack.middleware.clsql)
  (:shadow :stop)
  (:import-from :cl-syntax
                :use-syntax)
  (:import-from :cl-syntax-annot
                :annot-syntax)
  (:import-from :cl-ppcre
                :scan-to-strings)
  (:import-from :cl-fad
                :file-exists-p)
  (:import-from :caveman.middleware.context
                :<caveman-middleware-context>)
  (:import-from :caveman.request
                :request-method
                :path-info
                :parameter)
  (:import-from :caveman.context
                :*request*)
  (:export :config))

(use-syntax annot-syntax)

@export
(defclass <app> (<component>)
     ((config :initarg :config :initform nil
              :accessor config)
      (routing-rules :initarg routing-rules :initform nil
                     :accessor routing-rules)
      (acceptor :initform nil :accessor acceptor))
  (:documentation "Base class for Caveman Application. All Caveman Application must inherit this class."))

(defmethod call ((this <app>) req)
  "Overriding method. This method will be called for each request."
  @ignore req
  (let* ((req *request*)
         (method (request-method req))
         (path-info (path-info req)))
    (loop for rule in (reverse (routing-rules this))
          for (meth triple fn) = (cdr rule)
          for re = (first triple)
          for vars = (third triple)
          if (string= meth method)
            do (multiple-value-bind (matchp res)
                   (scan-to-strings re path-info)
                 (when matchp
                   (let ((params
                          (loop for key in vars
                                for val in (coerce res 'list)
                                append (list
                                         (intern (symbol-name key) :keyword)
                                         val))))
                     (setf (slot-value req 'clack.request::query-parameters)
                           (append
                            params
                            (slot-value req 'clack.request::query-parameters)))
                     (return (call fn (parameter req))))))
          finally (return '(404 nil nil)))))

@export
(defmethod build ((this <app>))
  (builder
   (<clack-middleware-static>
    :path "/public/"
    :root (merge-pathnames (getf (config this) :static-path)
                           (getf (config this) :application-root)))
   (<clack-middleware-clsql>
    :database-type (getf (config this) :database-type)
    :connection-spec (getf (config this) :database-connection-spec)
    :connect-args '(:pool t :encoding :utf-8))
   <caveman-middleware-context>
   this))

@export
(defmethod add-route ((this <app>) routing-rule)
  "Add a routing rule to the Application."
  (setf (routing-rules this)
        (delete (car routing-rule)
                (routing-rules this)
                :key #'car))
  (push routing-rule
        (routing-rules this)))

@export
(defmethod lookup-route ((this <app>) symbol)
  "Lookup a routing rule with SYMBOL from the application."
  (loop for rule in (reverse (routing-rules this))
        if (eq (first rule) symbol) do
          (return rule)))

@export
(defmethod start ((this <app>)
                  &key (mode :dev) port server debug lazy)
  (let ((config (load-config this mode)))
    (setf *builder-lazy-p* lazy)
    (setf (config this) config)
    (setf (acceptor this)
          (clackup
           (build this)
           :port (or port (getf config :port))
           :debug debug
           :server (or server (getf config :server))))))

@export
(defmethod stop ((this <app>))
  "Stop a server."
  (clack:stop (acceptor this) :server (getf (config this) :server))
  (setf (acceptor this) nil))

(defmethod load-config ((this <app>) mode)
  (let ((config-file (asdf:system-relative-pathname
                      (type-of <app>)
                      (format nil "src/config/~(~A~).lisp" mode))))
    (when (file-exists-p config-file)
      (eval
       (read-from-string
        ;; FIXME: remove dependence on skeleton, slurp-file.
        (caveman.skeleton::slurp-file config-file))))))

(doc:start)

@doc:NAME "
Caveman.App - Caveman Application Class.
"

@doc:SYNOPSIS "
    ;; Usually you shouldn't write this code.
    ;; These code will be generated by `caveman.skeleton:generate'.
    (defclass <myapp> (<app>) ())
    (defvar *app* (make-instance '<myapp>
                     :config '(:application-name \"My App\"
                               :application-root #p\"~/public/\"
                               :server :hunchentoot
                               :port 8080)))
    (start *app*)
"

@doc:DESCRIPTION "
Caveman.App provide a base class `<app>' for Caveman Application.

Usually you don't have to cave about this package because `caveman.skeleton:generate' will generate code for you.
"

@doc:AUTHOR "
* Eitarow Fukamachi (e.arrows@gmail.com)
"

@doc:SEE "
* Clack.Component
"
