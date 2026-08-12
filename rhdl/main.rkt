#lang racket/base
;; Reads the deliberately small first-cut #lang rhdl surface and expands it to Rhombus.

(module reader syntax/module-reader
  #:language 'rhdl/frontend
  #:read rhdl-read
  #:read-syntax rhdl-read-syntax
  #:whole-body-readers? #t

  (require racket/list
           racket/match
           racket/port
           racket/string
           syntax/readerr
           shrubbery/parse)

(struct source-line (number indent text) #:transparent)
(struct parameter (name) #:transparent)
(struct port-decl (direction name width line) #:transparent)
(struct local-decl (name expression line) #:transparent)
(struct assignment (target expression line) #:transparent)
(struct generator-call (name arguments line) #:transparent)
(struct module-decl (name parameters body line) #:transparent)

(define (source-name src)
  (cond
    [(path? src) (path->string src)]
    [(string? src) src]
    [else "<unknown>"]))

(define (read-error src line message)
  (raise-read-error message src line 0 #f #f))

(define (significant-lines text)
  (for/list ([raw (in-list (string-split text "\n" #:trim? #f))]
             [number (in-naturals 1)]
             #:unless (or (regexp-match? #px"^\\s*$" raw)
                          (regexp-match? #px"^\\s*//" raw)))
    (define indentation (string-length (car (regexp-match #px"^ *" raw))))
    (when (regexp-match? #rx"\t" raw)
      (error 'rhdl-reader "tabs are not allowed for indentation"))
    (source-line number indentation (string-trim raw))))

(define (parse-parameters src line text)
  (if (string=? (string-trim text) "")
      '()
      (for/list ([piece (in-list (string-split text ","))])
        (match (regexp-match #px"^\\s*([A-Za-z_][A-Za-z0-9_]*)\\s*:\\s*Int\\s*$" piece)
          [(list _ name) (parameter name)]
          [_ (read-error src line "module parameters must have the form name: Int")]))))

(define (parse-host-arguments src line text)
  (if (string=? (string-trim text) "")
      '()
      (for/list ([piece (in-list (string-split text ","))])
        (define arg (string-trim piece))
        (cond
          [(regexp-match? #px"^[0-9]+$" arg) arg]
          [(regexp-match? #px"^[A-Za-z_][A-Za-z0-9_]*$" arg) arg]
          [(member arg '("#true" "#false")) arg]
          [else (read-error src line "generator arguments must be simple host values")]))))

(define (parse-module-body src name parameters lines)
  (define parameter-names (map parameter-name parameters))
  (define declarations (make-hash))
  (define body '())
  (let loop ([remaining lines])
    (cond
      [(null? remaining) (reverse body)]
      [else
       (define current (car remaining))
       (unless (= (source-line-indent current) 2)
         (read-error src (source-line-number current)
                     "module body forms must be indented by two spaces"))
       (define text (source-line-text current))
       (cond
         [(member text '("input:" "output:"))
          (define direction (if (string=? text "input:") 'input 'output))
          (define-values (port-lines rest)
            (splitf-at (cdr remaining)
                       (lambda (candidate) (= (source-line-indent candidate) 4))))
          (when (null? port-lines)
            (read-error src (source-line-number current)
                        "port section must contain at least one declaration"))
          (for ([port-line (in-list port-lines)])
            (match (regexp-match #px"^([A-Za-z_][A-Za-z0-9_]*)\\s*:\\s*Bits\\(([^)]+)\\)$"
                                 (source-line-text port-line))
              [(list _ port-name width)
               (define width-expr (string-trim width))
               (unless (or (regexp-match? #px"^[1-9][0-9]*$" width-expr)
                           (member width-expr parameter-names))
                 (read-error src (source-line-number port-line)
                             "Bits width must be an explicit positive Int or Int parameter"))
               (when (hash-has-key? declarations port-name)
                 (read-error src (source-line-number port-line)
                             (string-append "duplicate port " port-name)))
               (hash-set! declarations port-name direction)
               (set! body (cons (port-decl direction port-name width-expr
                                           (source-line-number port-line))
                                body))]
              [_ (read-error src (source-line-number port-line)
                             "port declarations must have the form name: Bits(width)")]))
          (loop rest)]
         [(regexp-match #px"^(if|when|unless|cond)\\b" text)
          (read-error src (source-line-number current)
                      "host conditionals are not supported; hardware values cannot control host conditions")]
         [(regexp-match #px"^([A-Za-z_][A-Za-z0-9_]*(?:\\.[A-Za-z_][A-Za-z0-9_]*)?)\\s*:=\\s*(.+)$" text)
          => (lambda (matched)
               (define target (list-ref matched 1))
               (define expression (string-trim (list-ref matched 2)))
               (define target_base (car (string-split target ".")))
               (unless (hash-has-key? declarations target_base)
                 (read-error src (source-line-number current)
                             (string-append "unknown assignment target " target)))
               (when (and (not (string-contains? target "."))
                          (eq? (hash-ref declarations target) 'input))
                 (read-error src (source-line-number current) "inputs are read only"))
               (set! body (cons (assignment target expression (source-line-number current)) body))
               (loop (cdr remaining)))]
         [(regexp-match #px"^([A-Za-z_][A-Za-z0-9_]*)\\s*=\\s*(.+)$" text)
          => (lambda (matched)
               (define local-name (list-ref matched 1))
               (when (hash-has-key? declarations local-name)
                 (read-error src (source-line-number current)
                             (string-append "duplicate hardware name " local-name)))
               (hash-set! declarations local-name 'local)
               (set! body (cons (local-decl local-name
                                            (string-trim (list-ref matched 2))
                                            (source-line-number current))
                                body))
               (loop (cdr remaining)))]
         [(regexp-match #px"^([A-Za-z_][A-Za-z0-9_]*)\\((.*)\\)$" text)
          => (lambda (matched)
               (set! body
                     (cons (generator-call (list-ref matched 1)
                                           (parse-host-arguments src
                                                                 (source-line-number current)
                                                                 (list-ref matched 2))
                                           (source-line-number current))
                           body))
               (loop (cdr remaining)))]
         [else
          (read-error src (source-line-number current)
                      (string-append "unsupported module form: " text))])])))

(define (parse-program src text)
  (define lines (significant-lines text))
  (define modules '())
  (define elaboration #f)
  (let loop ([remaining lines])
    (cond
      [(null? remaining)
       (unless elaboration
         (read-error src 1 "program must end with elaborate(Module(...))"))
       (values (reverse modules) elaboration)]
      [else
       (define current (car remaining))
       (unless (= (source-line-indent current) 0)
         (read-error src (source-line-number current) "top-level forms must not be indented"))
       (define text (source-line-text current))
       (match (regexp-match #px"^module\\s+([A-Za-z_][A-Za-z0-9_]*)\\((.*)\\):$" text)
         [(list _ name raw-parameters)
          (when elaboration
            (read-error src (source-line-number current)
                        "module declarations must precede elaborate"))
          (define-values (body-lines rest)
            (splitf-at (cdr remaining)
                       (lambda (candidate) (> (source-line-indent candidate) 0))))
          (define parameters (parse-parameters src (source-line-number current) raw-parameters))
          (set! modules
                (cons (module-decl name parameters
                                   (parse-module-body src name parameters body-lines)
                                   (source-line-number current))
                      modules))
          (loop rest)]
         [_
          (match (regexp-match #px"^elaborate\\(([A-Za-z_][A-Za-z0-9_]*)\\((.*)\\)\\)$" text)
            [(list _ name arguments)
             (when elaboration
               (read-error src (source-line-number current) "program may contain only one elaborate form"))
             (set! elaboration
                   (generator-call name
                                   (parse-host-arguments src (source-line-number current) arguments)
                                   (source-line-number current)))
             (loop (cdr remaining))]
            [_
             (when (regexp-match? #px"^[A-Za-z_][A-Za-z0-9_]*\\(.*\\)$" text)
               (read-error src (source-line-number current)
                           "module generators may only be called from elaborate or another generator"))
             (read-error src (source-line-number current)
                         (string-append "unsupported top-level form: " text))])])])))

(define (quoted value) (format "~s" value))

(define (location-code src line)
  (format "Location(~a, ~a, 0)" (quoted (source-name src)) line))

(define identifier-pattern "[A-Za-z_][A-Za-z0-9_]*")
(define entity-pattern (string-append identifier-pattern "(?:\\." identifier-pattern ")?"))

(define (entity-code src text line)
  (define pieces (string-split (string-trim text) "."))
  (if (= (length pieces) 1)
      (car pieces)
      (format "context.field(~a, ~a, ~a)"
              (car pieces) (quoted (cadr pieces)) (location-code src line))))

(define (arguments text)
  (if (string=? (string-trim text) "")
      '()
      (map string-trim (string-split text ","))))

(define (expression-code src target expression line)
  (define loc (location-code src line))
  (define result-name (quoted target))
  (define expr (string-trim expression))
  (cond
    [(regexp-match (pregexp (string-append "^(" entity-pattern ")$")) expr)
     => (lambda (matched) (entity-code src (list-ref matched 1) line))]
    [(regexp-match #px"^Bits\\(([^)]+)\\)\\(([0-9]+)\\)$" expr)
     => (lambda (matched)
          (format "context.constant(module_def, Bits(~a), ~a, ~a, ~a)"
                  (string-trim (list-ref matched 1)) (list-ref matched 2)
                  result-name loc))]
    [(regexp-match (pregexp (string-append "^not\\((" entity-pattern ")\\)$")) expr)
     => (lambda (matched)
          (format "context.unary(module_def, ~a, ~a, ~a, ~a)"
                  (quoted "not") (entity-code src (list-ref matched 1) line)
                  result-name loc))]
    [(regexp-match (pregexp (string-append "^(" entity-pattern ")\\s*(==|[&|^+\\-])\\s*(" entity-pattern ")$")) expr)
     => (lambda (matched)
          (define opcode
            (hash-ref (hash "&" "and" "|" "or" "^" "xor" "+" "add" "-" "sub" "==" "eq")
                      (list-ref matched 2)))
          (format "context.binary(module_def, ~a, ~a, ~a, ~a, ~a)"
                  (quoted opcode)
                  (entity-code src (list-ref matched 1) line)
                  (entity-code src (list-ref matched 3) line)
                  result-name loc))]
    [(regexp-match #px"^(mux|concat|extract|zext|trunc|reg|instance)\\((.*)\\)$" expr)
     => (lambda (matched)
          (define operation (list-ref matched 1))
          (define args (arguments (list-ref matched 2)))
          (case (string->symbol operation)
            [(mux)
             (unless (= (length args) 3) (read-error src line "mux expects three arguments"))
             (format "context.mux(module_def, ~a, ~a, ~a, ~a, ~a)"
                     (entity-code src (list-ref args 0) line)
                     (entity-code src (list-ref args 1) line)
                     (entity-code src (list-ref args 2) line) result-name loc)]
            [(concat)
             (unless (>= (length args) 2) (read-error src line "concat expects at least two arguments"))
             (format "context.concat(module_def, [~a], ~a, ~a)"
                     (string-join (map (lambda (arg) (entity-code src arg line)) args) ", ")
                     result-name loc)]
            [(extract)
             (unless (= (length args) 3) (read-error src line "extract expects value, high, and low"))
             (format "context.extract(module_def, ~a, ~a, ~a, ~a, ~a)"
                     (entity-code src (list-ref args 0) line)
                     (list-ref args 1) (list-ref args 2) result-name loc)]
            [(zext trunc)
             (unless (= (length args) 2) (read-error src line (string-append operation " expects value and target width")))
             (format "context.~a(module_def, ~a, ~a, ~a, ~a)"
                     operation (entity-code src (list-ref args 0) line)
                     (list-ref args 1) result-name loc)]
            [(reg)
             (unless (or (= (length args) 2) (= (length args) 4))
               (read-error src line "reg expects type and clock, optionally followed by reset and reset value"))
             (match (regexp-match #px"^Bits\\(([^)]+)\\)$" (list-ref args 0))
               [(list _ width)
                (format "context.register(module_def, ~a, Bits(~a), ~a, ~a, ~a, ~a)"
                        result-name width (entity-code src (list-ref args 1) line)
                        (if (= (length args) 4) (entity-code src (list-ref args 2) line) "#false")
                        (if (= (length args) 4) (entity-code src (list-ref args 3) line) "#false")
                        loc)]
               [_ (read-error src line "reg type must be Bits(width)")])]
            [(instance)
             (unless (= (length args) 1) (read-error src line "instance expects one module definition"))
             (format "context.instance(module_def, ~a, ~a, ~a)"
                     (car args) result-name loc)]))]
    [(regexp-match (pregexp (string-append "^(" identifier-pattern ")\\((.*)\\)$")) expr)
     => (lambda (matched)
          (format "~a.instantiate([~a], ~a)"
                  (list-ref matched 1) (list-ref matched 2) loc))]
    [else
     (read-error src line (string-append "unsupported hardware expression: " expr))]))

(define (target-code src target line)
  (entity-code src target line))

(define (call-code src call)
  (format "~a.instantiate([~a], ~a)"
          (generator-call-name call)
          (string-join (generator-call-arguments call) ", ")
          (location-code src (generator-call-line call))))

(define (module-code src module)
  (define params (module-decl-parameters module))
  (define bindings
    (for/list ([param (in-list params)] [index (in-naturals)])
      (format "    def ~a = arguments[~a]" (parameter-name param) index)))
  (define forms
    (for/list ([form (in-list (module-decl-body module))])
      (match form
        [(port-decl direction name width line)
         (format "    def ~a = context.~a(module_def, ~a, Bits(~a), ~a)"
                 name direction (quoted name) width (location-code src line))]
        [(assignment target expression line)
         (format "    context.drive(~a, ~a, ~a)"
                 (target-code src target line)
                 (expression-code src (string-append (string-replace target "." "_") "_value") expression line)
                 (location-code src line))]
        [(local-decl name expression line)
         (format "    def ~a = ~a"
                 name (expression-code src name expression line))]
        [(? generator-call? call)
         (format "    ~a" (call-code src call))])))
  (string-append
   (format "  def mutable ~a = #false\n" (module-decl-name module))
   (format "  fun ~a_implementation(module_def, arguments):\n"
           (module-decl-name module))
   (if (null? bindings) "" (string-append (string-join bindings "\n") "\n"))
   (if (null? forms) "    #void\n" (string-append (string-join forms "\n") "\n"))
   (format "  ~a := ModuleGenerator(context, ~a, [~a], ~a_implementation)\n"
           (module-decl-name module)
           (quoted (module-decl-name module))
           (string-join (map (lambda (param) (quoted (parameter-name param))) params) ", ")
           (module-decl-name module))))

(define (generate-program src modules elaboration)
  (string-append
   "fun elaborate_program(context):\n"
   (apply string-append (map (lambda (module) (module-code src module)) modules))
   (format "  context.elaborate(~a, ~a)\n"
           (call-code src elaboration)
           (location-code src (generator-call-line elaboration)))
   "\n"
   "def design = frontend_run(elaborate_program)\n\n"
   "export:\n"
   "  design\n"))

(define (validate-generator-references src modules elaboration)
  (define module-names (map module-decl-name modules))
  (define (validate call)
    (unless (member (generator-call-name call) module-names)
      (read-error src (generator-call-line call)
                  (string-append "unknown module generator " (generator-call-name call)))))
  (validate elaboration)
  (for ([module (in-list modules)])
    (for ([form (in-list (module-decl-body module))]
          #:when (generator-call? form))
      (validate form))))

(define (rhdl-read-syntax src in)
  (define text (port->string in))
  (define-values (modules elaboration) (parse-program src text))
  (validate-generator-references src modules elaboration)
  (define generated (generate-program src modules elaboration))
  (list (parse-all (open-input-string generated) #:source src)))

(define (rhdl-read in)
  (map syntax->datum (rhdl-read-syntax #f in)))

  )
