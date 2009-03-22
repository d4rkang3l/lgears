#|
 | Copyright (C) 2009 - Stepan Zastupov
 | This program is free software; you can redistribute it and/or
 | modify it under the terms of the GNU General Public License
 | as published by the Free Software Foundation; either version 2
 | of the License, or (at your option) any later version.
 |
 | This program is distributed in the hope that it will be useful,
 | but WITHOUT ANY WARRANTY; without even the implied warranty of
 | MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 | GNU General Public License for more details.
 |
 | You should have received a copy of the GNU General Public License
 | along with this program; if not, write to the Free Software
 | Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 |#

(library (sc cps)
  (export cps-convert)
  (import (rnrs)
          (only (core) pretty-print) ; This works only for ypsilon
          (format)
          (sc quotes))

  ;For testing
  (define orig '(
                 #|
                 (define (f-aux n a)
                   (if (= n 0)
                     a
                     (f-aux (- n 1) (* n a))))

                 (define (factorial n)
                   (if (= n 0)
                     1
                     (* n (factorial (- n 1)))))
                 (factorian 6)

                 (define (foo n)
                   (bar (lambda (x) (+ x n))))

                 (define (bla)
                   (display '(a b c d)))

                 (display (lambda (x y) (x y)))
                 ((lambda (x y) (x y)) a b)
                 ((c d) x y)
                 |#


                 (if #f #t)

                 ))


  (define last-name 0)

  (define (gen-name)
    (let ((res (string-append "_var" (number->string last-name 16))))
      (set! last-name (+ last-name 1))
      (string->symbol res)))

  (define (self-eval? node)
    (or (not (pair? node))
        (and (eq? (car node) 'quote)
             (not (pair? (cadr node))))))

  (define (inlinable? node)
    (and (pair? node)
         (eq? (car node) 'lambda)))

  (define (convert-quote res node func name)
    (if (pair? node)
      (convert res (func node) name)
      node))

  (define (convert-func args body)
    (let ((name (gen-name)))
      `(lambda (,name ,@args)
         ,@(convert-body body name))))

  (define (unletrec node)
    `(,@(map (lambda (x)
               `(define ,(car x) ,(cadr x)))
             (cadr node))
       ,@(cddr node)))

  (define (convert-lambda node)
    (convert-func (cadr node) (cddr node)))

  (define (convert res node name)
    (if (self-eval? node)
      (if (null? res)
        (list name node)
        `((lambda (,name) ,res) ,node))
      (case (car node)
        ((lambda)
         (if (< (length node) 3)
           (syntax-violation 'convert "wrong lambda syntax" node))
         (let ((func (convert-lambda node)))
           (if (null? res)
             (list name func)
             `((lambda (,name) ,res) ,func))))

        ((letrec)
         (let ((func (convert-func '() (unletrec node))))
           (if (null? res)
             (list name func)
             `(,func (lambda (,name) ,res)))))

        ((if)
         (if (or (> (length node) 4)
                 (< (length node) 3))
           (syntax-violation 'convert "if expected two or three arguments" node))
         (let* ((args (cdr node))
                (pred (car args))
                (predname (if (self-eval? pred)
                            pred (gen-name)))
                (lname (gen-name))
                (escape (if (null? res) name lname))
                (condition `(if ,predname
                              ,(convert '() (cadr args) escape)
                              ,(if (null? (cddr args))
                                 (convert '() '(void) escape)
                                 (convert '() (caddr args) escape))))
                (expr (if (null? res)
                        condition
                        `((lambda (,lname) ,condition)
                          (lambda (,name) ,res)))))
           (if (self-eval? pred)
             expr
             (convert expr pred predname))))

        ((begin)
         (convert-seq res (cdr node) name))

        ((set!)
         (if (> (length node) 3)
           (syntax-violation 'convert "set! expected two arguments" node))
         (convert `((set! ,(cadr node) ,name) ,res) (caddr node) name))

        ((define)
         (syntax-violation 'convert "misplaced defination" node))

        ((quote)
         (convert-quote res (cadr node) trquote name))
        ((quasiquote)
         (convert-quote res (cadr node) trquasiquote name))

        ;;; Conversion of call
        ;;; We covnert both arguments and functions
        ;;; FIXME function fail if symbol in tail position
        (else
          (let* ((args (reverse node))
                 ;;; List of arguments ready for applicaton
                 (largs (map (lambda (x)
                               (cond ((self-eval? x) x)
                                     ((inlinable? x) (convert-lambda x))
                                     (else (gen-name))))
                             args))
                 (rlargs (reverse largs))
                 (control (cond ((null? res)
                                 name)
                                ((and (pair? (car res))
                                      (eq? (caar res) 'set!)) ;;FIXME
                                 `(lambda (,name) ,@res))
                                (else
                                  `(lambda (,name) ,res))))
                 (expr `(,(car rlargs) ,control ,@(cdr rlargs))))
            ;;; Clue everything
            (fold-left (lambda (prev x n)
                         (if (or (self-eval? x) (inlinable? x))
                           prev
                           (convert prev x n)))
                       expr args largs))))))

  (define (convert-define res def)
    (cond ((pair? (car def))
           `((set! ,(caar def)
               ,(convert-func (cdar def) (cdr def)))
             ,@res))

          ((self-eval? (cadr def))
           `((set! ,(car def) ,(cadr def))
             ,@res))

          ((and (pair? (cadr def))
                (eq? (caadr def) 'lambda))
           `((set! ,(car def)
               ,(convert-lambda (cadr def)))
             ,@res))

          ((pair? (cadr def))
           (let* ((name (gen-name))
                  (expr `((set! ,(car def) ,name)
                          ,@res)))
             (list (convert expr (cadr def) name))))))

  (define (convert-seq res source name)
    (if (null? source)
      '()
      (let* ((seq (reverse source))
             (frst (car seq)))
        (fold-left (lambda (prev x)
                     (convert prev x (if (eq? x frst)
                                       name
                                       (gen-name))))
                   res seq))))

  (define (defination? x)
    (and (pair? x) (eq? (car x) 'define)))

  (define (splice-begin src)
    (let loop ((cur src))
      (cond ((null? cur)
             '())
            ((and (pair? cur) (pair? (car cur))
                  (eq? (caar cur) 'begin))
             (append (cdar cur) (loop (cdr cur))))
            (else
              (cons (car cur) (loop (cdr cur)))))))

  (define (convert-body body name)
    (let ((body (splice-begin body)))
      (let-values (((defines expressions)
                    (partition defination? body)))
        (if (null? expressions)
          (syntax-violation 'convert-body "empty body" #f))
        (let* ((rest (convert-seq '() expressions name))
               (extend (if (null? defines)
                         '()
                         `((extend ,(map (lambda (x)
                                           (if (pair? (cadr x))
                                             (caadr x)
                                             (cadr x)))
                                         defines))))))
          `(,@extend
             ,@(fold-left (lambda (prev x)
                            (if (null? (cddr x))
                              prev
                              (convert-define prev (cdr x))))
                          (list rest) (reverse defines)))))))

  (define (cps-convert source)
    (let ((res (convert-body source '__exit)))
      (display "CPS: \n")
      (pretty-print res)
      (newline)
      (if (pair? (car res))
        res
        (list res))))

  ;(pretty-print (convert-body orig 'exit))
  )