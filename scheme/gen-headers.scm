#!r6rs
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


(import (rnrs)
        (format)
        (compiler opcode))

;;
;; It's ugly, I know :\
;;

(define (with-header path func)
  (let ((port (open-file-output-port
               path
               (file-options no-fail)
               (buffer-mode block)
               (native-transcoder))))
    (format #t "Generating header ~a ...\n" path)
    (func port)
    (close-port port)))

(define (code-defines codes port)
  (fold-left
   (lambda (idx op)
     (format port "#define ~a\t0x~x\t/* ~a */\n"
             (car op) idx (cdr op))
     (+ 1 idx))
   0 codes)
  (newline port))

(define (code-names prefix codes port)
  (format port "static inline const char* ~a_name(int code)\n{\n" prefix)
  (put-string port "\tswitch (code) {\n")
  (for-each
   (lambda (op)
     (format port "\t\tOP_CASE(~a);\n" (car op)))
   codes)
  (put-string port "\t}\n")
  (put-string port "\treturn \"unknown\";\n}\n\n"))

(with-header
  "opcodes.h"
  (lambda (port)
    (display "#ifndef OPCODES_H\n#define OPCODES_H\n\n" port)
    (display "/* Generated by gen-headers.scm, do not edit. */\n" port)
    (display "\n#define OP_CASE(code) case code: return #code\n\n" port)

    (code-defines oplist port)
    (code-defines object-types port)
    (code-names "opcode" oplist port)
    (code-names "object_type" object-types port)

    (display "#endif\n" port)))

(with-header
  "opcode_targets.h"
  (lambda (port)

    (display "#ifndef OPCODE_TARGETS_H\n#define OPCODE_TARGETS_H\n\n" port)
    (display "static const void* opcode_targets[] = {\n" port)
    (oplist-for-each (lambda (idx op)
                       (format port "\t&&TARGET_~a,\n" (car op)) port))
    (display "};\n\n#endif" port)))
