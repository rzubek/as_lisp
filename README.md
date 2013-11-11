as_lisp
=======

**as_lisp** is a Lisp dialect implemented in Actionscript. 

It's a bytecode compiled language, and comes with its own compiler and a small bytecode interpreter, both written in Actionscript. The language includes the typical Lisp-dialect features you'd expect, like proper closures, tail-call optimization, and macros. 

Language implementation should be pretty readable and easy to extend (which also means: it's not particularly optimized). Compiler and bytecode design are heavily influenced by (ie. cribbed from) Quinnec's *"Lisp in Small Pieces"* and Norvig's *"Principles of Artificial Intelligence Programming"* . Standing on the shoulders on giants. :)  

**as_lisp** is intended to be used as a library, embedded in another host program, and not a standalone executable. The compiler, bytecode interpreter, and runtime environment, are all easy to access and manipulate from host programs. A simple REPL console host app is included as an example. Since **as_lisp** can run inside the Adobe Flash runtime, it's compatible with a wide range of environments, including web browsers, and standalone AIR apps (iOS, Android, PC/Mac).

This is very much a work in progress, so please pardon the dust, use at your own risk, and so on. :)



### USAGE

```actionscript
var ctx :Context = new Context(null, true); // make a new vm + compiler
ctx.execute("(+ 1 2)");                     // => [ 3 ]
```


### LANGUAGE DETAILS

Value types:
-  Boolean - #t or #f, backed by Actionscript boolean
-  Number - same as Actionscript Number (floating point double)
-  String - same as Actionscript String (immutable char sequence in double quotes)
-  Symbol - similar to Scheme
-  Cons - pair of expressions
-  Closure - non-inspectable pair of environment and compiled code sequence

Small set of reserved keywords - everything else is a valid symbol
-  quote
-  begin
-  set!
-  if
-  if*
-  lambda
-  defmacro
-  .

Tail calls get optimized during compilation, without any language hints
```lisp
  (define (rec x) (if (= x 0) 0 (rec (- x 1))))
  (rec 1000000) ;; look ma, no stack overflow!
```

Quotes, quasiquotes and unquotes are supported in the Lisp fashion:
```
  'x                 ;; => 'x
  `x                 ;; => 'x
  `,x                ;; => x
  `(1 ,(list 2 3))   ;; => '(1 (2 3))
  `(1 ,@(list 2 3))  ;; => '(1 2 3)
```

Closures
```lisp
  (set! fn (let ((sum 0)) (lambda (delta) (set! sum (+ sum delta)) sum))) 
  (fn 0)    ;; => 0
  (fn 100)  ;; => 100
  (fn 0)    ;; => 100
```

Macros are more like Lisp than Scheme. 
```lisp
  ;; (let ((x 1) (y 2)) (+ x 1)) => 
  ;;   ((lambda (x y) (+ x y)) 1 2)
  (defmacro let (bindings . body) 
    `((lambda ,(map car bindings) ,@body) 
      ,@(map cadr bindings)))
```

Macroexpansion - single-step and full
```lisp
  (and 1 (or 2 3))         ;; => 2
  (mx1 '(and 1 (or 2 3)))  ;; => (if 1 (core:or 2 3) #f)
  (mx '(and 1 (or 2 3)))   ;; => (if 1 (if* 2 3) #f)
```

Built-in primitives live in the "core" package and can be redefined
```lisp
  (+ 1 2)               ;; => 3
  (set! core:+ core:*)  ;; => [Closure]
  (+ 1 2)               ;; => 2
```

Packages 
```lisp
  (package-set "math")       ;; => "math"
  (package-get)              ;; => "math"
  (package-import ("core"))  ;; => null
  (package-export '(sin cos))
```

Built-in primitives are very bare bones (for now):
-  Functions:
  -  + - * / = != < <= > >= 
  -  const list append length
  -  not null? cons? atom? string? number? boolean?
  -  car cdr cadr cddr caddr cdddr map
  -  mx mx1 trace gensym
  -  package-set package-get package-import package-export
  -  first second third rest
  -  fold-left fold-right
-  Macros
  -  let let* letrec define
  -  and or cond case
-  Flash interop
  -  new deref ..



##### TODOS

- Fix bugs (hah!)
- Build out the standard library
- Flesh out Flash interop. Right now it's in its infancy:
    - `(new '(flash geom Point) 2 3)                ;; => [Native: (x=2, y=3)]`
    - `(deref (new '(flash geom Point) 2 3) 'x)     ;; => 2  `
    - `  ;; also (.. instance '(field1 field2)) == (deref (deref instance field1) field2)`
- Peephole optimizer. Also optimize execution of built-in primitives.
- Add better debugging: trace function calls, their args and return values, etc


##### KNOWN BUGS

- Error messages are somewhere between opaque and completely misleading
- Redefining a known macro as a function will fail silently in weird ways
- Symbol / package resolution is buggy - eg. if a symbol "foo" is defined in core 
  but not in the package "bar", then "bar:foo" will resolve to "core:foo" 
  even though it should resolve as undefined.



