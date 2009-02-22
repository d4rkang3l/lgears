(import (rnrs)
        (cps)
        (assembly))

(define (set-func-args! ntbl args)
  (let loop ((idx 0) (lst args))
    (cond
      ((null? lst)
       idx)
      ((symbol? lst)
       (hashtable-set! ntbl lst idx)
       (+ idx 1))
      ((pair? lst)
       (hashtable-set! ntbl (car lst) idx)
       (loop (+ idx 1) (cdr lst)))
      (else
        (error 'make-env "unexpected" lst)))))

;; Environment of current-compiling function
(define-record-type env
  (fields parent tbl (mutable size)
    argc (mutable heap))
  (protocol
    (lambda (new)
      (case-lambda
        (()
         (new '() (make-eq-hashtable) 0 0 #f))
        ((prev args)
         (let* ((ntbl (make-eq-hashtable))
                (nargc (set-func-args! ntbl args)))
           (new prev ntbl nargc nargc #f)))))))

(define (env-define env name)
  (let ((size (env-size env)))
    (hashtable-set! (env-tbl env) name size)
    (env-size-set! env (+ size 1))))

(define (make-func code env)
  (make-i-func
    code
    (env-size env)
    (env-argc env)
    (env-heap env)))

(define (env-lookup env name)
  (let loop ((step 0)
             (cur-env env))
    (if (null? cur-env)
      #f
      (let ((res (hashtable-ref (env-tbl cur-env) name #f)))
        (if res
          (if (zero? step)
            `(LOCAL . ,res)
            (begin
              (env-heap-set! cur-env #t)
              `(PARENT ,step ,res)))
          (loop (+ step 1) (env-parent cur-env)))))))

(define (env-idx env name)
  (let ((res (hashtable-ref (env-tbl env) name #f)))
    (if res
      res
      (error 'env-idx "not found" name))))

(define-record-type sym-table
  (fields table (mutable count))
  (protocol
    (lambda (new)
      (lambda () (new (make-eq-hashtable) 0)))))

(define (sym-table-insert stbl sym)
  (let* ((tbl (sym-table-table stbl))
         (res (hashtable-ref tbl sym #f)))
    (if res
      res
      (begin
        (set! res (sym-table-count stbl))
        (hashtable-set! tbl sym res)
        (sym-table-count-set! stbl (+ res 1))
        res))))

;; Return list of keys sorted by value (index)
;;
;; As order of returned hash values is not specified, we have
;; to guaranty that everything is ok.
(define (symtable->list stbl)
  (let-values (((keys vals) (hashtable-entries (sym-table-table stbl))))
    (map (lambda (x)
           (symbol->string (car x)))
         (list-sort (lambda (x y) (< (cdr x) (cdr y)))
                    (map cons
                         (vector->list keys)
                         (vector->list vals))))))


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

(define (start-compile root)
  (let ((undefs (make-sym-table))
        (symbols (make-sym-table))
        (code-store (make-store)))

    (define (compile-body env body)
      (define (code? x)
        (not (eq? (car x) 'extend)))
      (let ((extend (assq 'extend body))
            (code (filter code? body)))
        (if extend
          (for-each (lambda (def)
                      (env-define env def))
                    (cadr extend)))
        (map-append (lambda (expr)
                      (compile env expr))
                    code)))

    (define (compile-func parent args body)
      (let* ((env (make-env parent args))
             (compiled (compile-body env body)))
        `((LOAD_FUNC
            ,(store-push! code-store
                          (make-func compiled env))
            1))))

    (define (compile-if env node)
      (let ((pred (compile env (car node)))
            (then-clause (compile env (cadr node)))
            (else-clause (compile env (caddr node))))
        `(,@pred
           (JUMP_IF_FALSE ,(+ (length then-clause) 1) 0)
           ,@then-clause
           (JUMP_FORWARD ,(length else-clause) 0)
           ,@else-clause)))

    (define (compile-args env args)
      (let loop ((cur args)
                 (idx 0)
                 (res '()))
        (if (null? cur)
          (cons idx res)
          (loop (cdr cur) 
                (+ idx 1)
                (append res (compile env (car cur)))))))

    (define (compile-call env node)
      (let* ((func (compile env (car node)))
             (args (compile-args env (cdr node)))
             (argc (car args)))
        `(,@(cdr args)
           ,@func
           (FUNC_CALL ,argc ,(- argc)))))

    (define (compile-assigment env node)
      (let* ((name (car node))
             (slot (env-lookup env name)))
        (if (not slot)
          (error 'compile-assigment "undefined variable" name)
          `(,@(compile env (cadr node))
             ,(if (eq? (car slot) 'LOCAL)
                `(SET_LOCAL ,(cdr slot), -1)
                (error 'compile-assigment "non-local setting not yet implemented :("))))))

    (define (compile env node)
      (cond ((pair? node)
             (case (car node)
               ((lambda)
                (compile-func env (cadr node) (cddr node)))
               ((if)
                (compile-if env (cdr node)))
               ((quote)
                `((LOAD_SYM ,(sym-table-insert symbols (cadr node)) 1)))
               ((set!)
                (compile-assigment env (cdr node)))
               (else
                 (compile-call env node))))
            ((number? node)
             (cons 'NUMBER node))
            ((string? node)
             (cons 'STRING node))
            (else
              (let ((res (env-lookup env node)))
                (if res
                  (if (eq? (car res) 'LOCAL)
                    `((LOAD_LOCAL ,(cdr res) 1))
                    `((LOAD_ENV ,(cadr res) 1)
                      (LOAD_FROM_ENV ,(caddr res) 0)))
                  `((LOAD_IMPORT ,(sym-table-insert undefs node) 1)))))))

    (let ((entry-point (compile-func (make-env) '() root)))
      (make-ilr (symtable->list undefs)
                (symtable->list symbols)
                (reverse (store-head code-store))
                (cadar entry-point)))))

(let ((res (start-compile
             (cps-convert '(
                            (define (foo n)
                              (if n
                                (car n)
                                (cdr n)))
                            (display (foo (cons 'bla 'boo)))
                            )))))
  (print-ilr res)
  (display "\nAssembly output:\n")
  (let ((port (open-file-output-port "/tmp/assembly" (file-options no-fail))))
    (assemble res port)
    (close-output-port port))
  )
