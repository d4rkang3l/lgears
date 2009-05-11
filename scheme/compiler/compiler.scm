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

(library (compiler compiler)
  (export start-compile)
  (import (rnrs)
		  (reader)
		  (format)
		  (compiler fasl))

  ;; The table of builtin functions which also describe functions safity
  ;; (name mutate? change-cont?)
  (define builtins
    '((display #f #f)
      (__exit #f #f)
      (call/cc #f #t)
      (apply #f #t)
      (cons #f #f)
      (list #f #f)
      ($make-list #f #f)
      (list? #f #f)
      (length #f #f)
      (car #f #f)
      (cdr #f #f)
      (void #f #f)
      (char->integer #f #f)
      (integer->char #f #f)
      (eq? #f #f)
      (procedure? #f #f)
      (boolean? #f #f)
      (null? #f #f)
      (char? #f #f)
      (number? #f #f)
      (pair? #f #f)
      (symbol? #f #f)
      ($+ #f #f)
      ($- #f #f)
      ($* #f #f)
      ($/ #f #f)
      (mod #f #f)
      ($= #f #f)
      ($< #f #f)
      ($> #f #f)
      (fxior #f #f)
      (vector #f #f)
      (vector? #f #f)
      (vector-length #f #f)
      (vector-set! #t #f)
      (vector-ref #f #f)
      (vector->list #f #f)
      ($make-vector #f #f)
      (symbol->string #f #f)
      (string-ref #f #f)
      (string-length #f #f)
      (string? #f #f)
      (string=? #f #f)
      (string-concat #f #f)
      (make-bytevector #f #f)
      (bytevector? #f #f)
      (bytevector-u8-set! #t #f)
      (fd-open #f #f)
      (fd-close #f #f)
      (fd-seek #f #f)
      (fd-write #f #f)
      (load-library #f #t)
      (library-cache #f #f)))

  (define (init-static)
	(map (lambda (x)
		   (cons (car x) (make-static (symbol->string (car x)))))
		 builtins))

  (define static-variables (init-static))

  (define (set-func-args! ntbl args)
	(let loop ((idx 0) (lst args))
	  (cond
		((null? lst)
		 (cons #f idx))
		((symbol? lst)
		 (hashtable-set! ntbl lst idx)
		 (cons #t idx))
		((pair? lst)
		 (hashtable-set! ntbl (car lst) idx)
		 (loop (+ idx 1) (cdr lst)))
		(else
		  (error 'make-env "unexpected" lst)))))

  ;; Environment of current-compiling function
  (define-record-type env
	(fields parent
            tbl
            (mutable size)
            argc
            swallow
            depth
            (mutable onheap)
            (mutable bindings)
            (mutable bindmap))
	(protocol
	  (lambda (new)
		(lambda (prev args)
		  (let* ((ntbl (make-eq-hashtable))
				 (nargc (set-func-args! ntbl args))
				 (ndepth (if (null? prev) 0
						   (+ 1(env-depth prev))))
				 (nsize (if (car nargc)
						  (+ (cdr nargc) 1)
						  (cdr nargc))))
			(new prev ntbl nsize (cdr nargc)
				 (car nargc) ndepth #f '() '()))))))

  (define (env-define env name)
	(let ((size (env-size env)))
	  (hashtable-set! (env-tbl env) name size)
	  (env-size-set! env (+ size 1))))

  (define (env-bind env up idx)
	(define (set-binding! midx)
	  (let* ((bindings (env-bindings env))
			 (nmidx (- midx 1))
			 (key (cons nmidx idx))
			 (found (member key bindings)))
		(if found
		  (- (length found) 1)
		  (let ((newbind (cons key bindings)))
			(env-bindings-set! env newbind)
			(- (length newbind) 1)))))

	(let* ((bindmap (env-bindmap env))
		   (inmap (memv up bindmap)))
	  (if inmap
		(set-binding! (length inmap))
		(let ((nb (cons up bindmap)))
		  (env-bindmap-set! env nb)
		  (set-binding! (length nb))))))

  (define (make-func code env)
	(make-i-func
	  code
	  (env-size env)
	  (env-argc env)
	  (env-swallow env)
	  (env-onheap env)
	  (env-depth env)
	  (reverse (env-bindings env))
	  (reverse (env-bindmap env))))

  (define (env-ref env name)
	(hashtable-ref (env-tbl env) name #f))

  (define-record-type store
	(fields (mutable head) (mutable count))
	(protocol
	  (lambda (new)
		(lambda () (new '() 0)))))

  (define (store-push! store val)
	(let ((res (store-count store)))
	  (store-count-set! store (+ 1 res))
	  (store-head-set! store (cons val (store-head store)))
	  res))

  (define (map-append proc lst)
	(if (null? lst)
	  '()
	  (append (proc (car lst))
			  (map-append proc (cdr lst)))))

  (define (datum->string dt)
    (call-with-string-output-port
     (lambda (port)
       (write dt port))))

  (define (start-compile root)
	(let ((code-store (make-store))
		  (consts '()))

	  (define (make-const datum)
		(cond ((assoc datum consts)
			   => cdr)
			  (else
			   (let ((idx (length consts)))
				 (set! consts (cons (cons datum idx)
									consts))
				 idx))))

	  (define (env-lookup env name)
		(let loop ((step 0)
				   (cur-env env))
		  (if (null? cur-env)
			  (cond ((assq name static-variables)
					 => (lambda (res)
						  `(STATIC . ,(make-const (cdr res)))))
					(else
					 (error 'env-lookup "undefined" name)))
			  (let ((res (env-ref cur-env name)))
				(if res
					(if (zero? step)
						`(LOCAL . ,res)
						(begin
						  (env-onheap-set! cur-env #t)
						  `(BIND . ,(env-bind env (env-depth cur-env) res))))
					(loop (+ step 1) (env-parent cur-env)))))))

	  (define (split-extend node)
		(if (and (pair? (car node))
			 (eq? (caar node) 'extend))
			 (values (cadar node)
					 (cdr node))
			 (values #f node)))

	  (define (compile-body env body)
		(define (code? x)
		  (not (eq? (car x) 'extend)))
		(let-values (((extend code) (split-extend body)))
		  (if extend
			(for-each (lambda (def)
						(env-define env def))
					  extend))
		  (map-append (lambda (expr)
						(compile env expr))
					  code)))

	  (define (compile-func parent args body)
		(let* ((env (make-env parent args))
			   (compiled (compile-body env body))
			   (idx (store-push! code-store
								 (make-func compiled env))))
		  `((LOAD_CLOSURE ,idx))))
		  ;(if (null? (env-bindings env))
			;`((LOAD_FUNC ,idx))
			;`((LOAD_CLOSURE ,idx)))))

	  (define (compile-if env node)
		(let ((pred (compile env (car node)))
			  (then-clause (compile env (cadr node)))
			  (else-clause (compile env (caddr node))))
		  `(,@pred
			 (JUMP_IF_FALSE ,(+ (length then-clause) 1))
			 ,@then-clause
			 (JUMP_FORWARD ,(length else-clause))
			 ,@else-clause)))

      (define (cont-safe? var)
        (cond ((assq var builtins)
               => (lambda (b) (not (caddr b))))
              (else #f)))

      (define (optimize-cont? node)
        (and (symbol? (car node))
             (and (pair? (cadr node))
                  (eq? (caadr node) 'lambda))
             (cont-safe? (car node))))

      (define (rewrite-cont args)
        (cons `(LOAD_FUNC ,(cadar args))
              (cdr args)))

	  (define (compile-call env node)
		(let* ((func (compile env (car node)))
			   (argc (length (cdr node)))
			   (args (map-append (lambda (x)
								   (compile env x))
								 (cdr node))))
		  `(,@(if (optimize-cont? node)
                  (rewrite-cont args)
                  args)
            ,@func
            (FUNC_CALL ,argc))))

	  (define (compile-assigment env node)
		(let* ((name (car node))
			   (slot (env-lookup env name)))
		  (if (not slot)
			  (error 'compile-assigment "undefined variable" name)
			  `(,@(compile env (cadr node))
				,(case (car slot)
				   ((LOCAL)
					`(SET_LOCAL ,(cdr slot)
								,(datum->string name)))
				   ((BIND)
					`(SET_BIND ,(cdr slot)
							   ,(datum->string name)))
				   (else (error 'compile-assigment "invalid set")))))))

	  (define (compile env node)
		(cond ((pair? node)
			   (case (car node)
				 ((lambda)
				  (compile-func env (cadr node) (cddr node)))
				 ((if)
				  (compile-if env (cdr node)))
				 ((quote)
				  (if (null? (cadr node))
					`((PUSH_NULL 0))
					`((LOAD_CONST ,(make-const (cadr node))
								  ,(datum->string (cadr node))))))
				 ((set!)
				  (compile-assigment env (cdr node)))
				 (else
				   (compile-call env node))))
			  ((or (char? node)
				   (number? node)
				   (string? node))
			   `((LOAD_CONST ,(make-const node)
							 ,(datum->string node))))
			  ((boolean? node)
			   `((PUSH_BOOL ,(if node 1 0)
							,(datum->string node))))
			  (else
				(let ((res (env-lookup env node)))
				  (case (car res)
					((LOCAL)
					  `((LOAD_LOCAL ,(cdr res)
									,(datum->string node))))
					((BIND)
					  `((LOAD_BIND ,(cdr res)
								   ,(datum->string node))))
					((STATIC)
					 `((LOAD_CONST ,(cdr res)
								   ,(datum->string node))))
					(else
					 (error 'compile "unknown" res)))))))

	  (let ((entry-point (compile '() root)))
		(make-ilr (map car (reverse consts))
				  (reverse (store-head code-store))
				  (cadar entry-point)))))
  )
