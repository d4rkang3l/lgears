(include "base.scm")
#|
(define (range from to)
  (let loop ((step to)
             (res '()))
    (if (< step from)
      res
      (loop (- step 1) (cons step res)))))
(display (range 1 100))

;(define (even? x)
  ;(= (mod x 2) 0))

;(define (problem-2 lim)
  ;(define (loop n p r sum)
    ;(if (> r lim)
      ;sum
      ;(loop (+ 1 n) r (+ r p)
            ;(if (even? r)
              ;(+ sum r)
              ;sum))))
  ;(loop 2 1 1 0))

;(display (problem-2 120))
|#

(define (test msg cmp arg expect)
  (display "Testing ") (display msg)
  (if (cmp arg expect)
    (display " ok\n")
    (begin
      ; UGLY!!!!
      (display " fail, expected ") (display expect) (display ", got ") (display arg) (display "\n"))))

(define (test-pred pred arg expect)
  (test pred eq? (pred arg) expect))

(test-pred boolean? #t #t)
(test-pred boolean? #f #t)
(test-pred boolean? 'foo #f)
(test-pred procedure? 'foo #f)
(test-pred procedure? test-pred #t)
(test-pred procedure? display #t)
(test-pred pair? '(1 2) #t)
(test-pred pair? '(1 . 2) #t)
(test-pred pair? 'foo #f)
(test-pred symbol? 'foo #t)
(test-pred symbol? "foo" #f)
(test-pred string? "foo" #t)
(test-pred string? 'foo #f)
(test-pred vector? '(1 2 3) #f)
(test-pred vector? (vector 1 2 3) #t)
(test-pred char? #\f #t)
(test-pred char? 1 #f)
(test-pred null? '(1) #f)
(test-pred null? '() #t)
(test-pred number? 42 #t)
(test-pred number? #\n #f)

(test apply = (apply + '(1 2 3 4 5)) 15)

(test call/cc = (call/cc
                    (lambda (c)
                      (c 42)
                      1)) 42)

(test char->integer = (char->integer #\f) 102)
