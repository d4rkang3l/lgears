(import ($builtin)
        (base))

;(define (range from to)
  ;(let loop ((cur to)
             ;(res '()))
    ;(if ($= cur from)
      ;(cons cur res)
      ;(loop ($- cur 1) (cons cur res)))))

;(let loop ((n 0))
  ;(if ($= n 5)
    ;(void)
    ;(begin
      ;(display (range 1 150))
      ;(loop ($+ n 1)))))

(display (fold-left * '(1 2 3 4)))