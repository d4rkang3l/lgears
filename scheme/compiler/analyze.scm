#|
 | This file is part of lGears scheme system
 | Copyright (C) 2009 Stepan Zastupov <redchrom@gmail.com>
 |
 | This program is free software; you can redistribute it and/or
 | modify it under the terms of the GNU Lesser General Public
 | License as published by the Free Software Foundation; either
 | version 3 of the License, or (at your option) any later version.
 |
 | This program is distributed in the hope that it will be useful,
 | but WITHOUT ANY WARRANTY; without even the implied warranty of
 | MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 | Lesser General Public License for more details.
 |
 | You should have received a copy of the GNU Lesser General
 | Public Licens along with this program, if not; see
 | <http://www.gnu.org/licenses>.
 |#

(library (compiler analyze)
  (export analyze tagged? binding-ref-count function? function-args
          function-body self-eval?)
  (import (rnrs))

  (define-record-type binding
    (fields (mutable ref-count)
            (mutable mutate)))

  (define-record-type env
    (fields prev (mutable bindings)))

  (define-record-type function
    (fields bindings args body))

  (define-record-type reference
    (fields bind))

  (define (env-lookup env name)
    (cond ((null? env) #f)
          ((assq name (env-bindings env))
           => cdr)
          (else (env-lookup (env-prev env)
                            name))))

  (define (binding-incref! b)
    (binding-ref-count-set!
     b (+ 1 (binding-ref-count b))))

  (define (fresh-bind name)
    (cons name (make-binding 0 #f)))

  (define (make-bindings lst)
    (let loop ((lst lst))
      (cond ((null? lst) '())
            ((pair? lst)
             (cons (fresh-bind (car lst))
                   (loop (cdr lst))))
            (else
             (list (fresh-bind lst))))))

  (define (analyze-lambda prev node)
    (let* ((env (make-env prev (make-bindings (cadr node))))
           (body (map (lambda (x)
                        (analyze env x))
                      (cddr node))))
      (make-function
       (env-bindings env)
       (cadr node)
       body)))

  (define (analyze-assigment env node)
    (cond ((env-lookup env (cadr node))
           => (lambda (b)
                (binding-mutate-set! b #t)
                (binding-incref! b))))
    node)

  (define (analyze-define env node)
    (let ((bind (fresh-bind (cadr node))))
      (env-bindings-set!
       env
       (cons bind
             (env-bindings env)))
      `(define ,bind
         ,(analyze env (caddr node)))))

  (define (tagged? node tag)
    (and (pair? node)
         (eq? (car node) tag)))

  (define (self-eval? node)
    (or (not (or (pair? node)
                 (symbol? node)))
        (tagged? node 'quote)))

  (define (analyze env node)
    (cond ((self-eval? node) node)
          ((symbol? node)
           (cond ((env-lookup env node)
                  => binding-incref!))
           node)
          ((tagged? node 'lambda)
           (analyze-lambda env node))
          ((tagged? node 'set!)
           (analyze-assigment env node))
          ((tagged? node 'define)
           (analyze-define env node))
          ((pair? node)
           (cons (analyze env (car node))
                 (analyze env (cdr node))))
          (else node)))
  )