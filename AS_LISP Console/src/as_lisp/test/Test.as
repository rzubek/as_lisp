package as_lisp.test
{
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.system.System;
	import flash.utils.getTimer;
	
	import as_lisp.data.Closure;
	import as_lisp.data.Cons;
	import as_lisp.data.Environment;
	import as_lisp.data.Instruction;
	import as_lisp.data.Package;
	import as_lisp.data.Packages;
	import as_lisp.data.Printer;
	import as_lisp.data.Symbol;
	import as_lisp.util.Stream;
	import as_lisp.util.Context;
	
	/**
	 * Tests various parts of the system.
	 */
	public class Test extends Sprite
	{
		public function Test():void 
		{
			if (stage) init();
			else addEventListener(Event.ADDED_TO_STAGE, init);
		}
		
		private function init(e:Event = null):void 
		{
			removeEventListener(Event.ADDED_TO_STAGE, init);
			
			Test.testAll();
			System.exit(0);
		}

		/** Failures count during the last test run. */
		public static var failures :int = 0;
		
		/** Static logger. Can be replaced with something else */
		public static var logger :Function = function (... args) :void {
			var message :String = (args as Array).join(" ");
			trace(message);
		}
		
		/** Runs all tests in order */
		public static function testAll () :void {
			failures = 0;
			var start :int = getTimer();
			testDataClasses();
			testParser();
			testCompiler();
			testMachine();
			var delta :int = getTimer() - start;
			log("Tests finished in " + delta + " ms");
			log(failures ? "FAILED " + failures + " TESTS" : "SUCCESS");
		}
		
		/** Tests various internal classes */
		public static function testDataClasses () :void {
			log("Running testDataClasses");
			
			// test cons
			
			check(Cons.isAtom("foo"));
			check(Cons.isAtom(5));
			check(Cons.isAtom(null));
			check(! Cons.isAtom(new Cons(1, 2)));
			
			var list1 :Cons = new Cons("foo", new Cons("bar", null));
			check(Cons.isCons(list1));
			check(Cons.isList(list1));
			check(Cons.length(list1), 2);
			check(list1.car, "foo");
			check(list1.cadr, "bar");
			check(list1.cddr, null);
			check(Cons.isAtom(list1.car)); // "foo"
			check(Cons.isCons(list1.cdr)); // ("bar")
			check(Cons.isAtom(list1.cadr)); // "bar"
			check(! Cons.isCons(list1.cddr)); // null
			check(Cons.isNull(list1.cddr)); // null
			check(Printer.toString(list1), "(\"foo\" \"bar\")");
			
			var list2 :Cons = Cons.make("foo", "bar");
			check(Cons.isCons(list2));
			check(Cons.isList(list2));
			check(Cons.length(list2), 2);
			check(list2.car, "foo");
			check(list2.cadr, "bar");
			check(list2.cddr, null);
			check(Cons.isAtom(list2.car)); // "foo"
			check(Cons.isCons(list2.cdr)); // ("bar")
			check(Cons.isAtom(list2.cadr)); // "bar"
			check(! Cons.isCons(list2.cddr)); // null
			check(Cons.isNull(list2.cddr)); // null
			check(Printer.toString(list2), "(\"foo\" \"bar\")");
			
			var nonlist :Cons = new Cons("foo", "bar");
			check(Cons.isCons(nonlist));
			check(! Cons.isList(nonlist));
			check(nonlist.car, "foo");
			check(nonlist.cdr, "bar");
			check(Cons.isAtom(nonlist.car)); // "foo"
			check(Cons.isAtom(nonlist.cdr)); // "bar"
			check(! Cons.isCons(nonlist.cdr));
			check(Printer.toString(nonlist), "(\"foo\" . \"bar\")");
			
			// test packages and symbols
			
			var p :Package = new Package(null); // global package
			var foo :Symbol = p.intern("foo");
			check(foo.name, "foo");
			check(foo.pkg, p);
			check(foo.fullName, "foo");
			check(p.intern("foo") == foo); // make sure interning returns the same instance
			check(p.unintern(foo));        // first one removes successfully
			check(! p.unintern(foo));      // but second time there is nothing to remove
			check(p.intern("foo") != foo); // since we uninterned, second interning will return a different one
			
			var p2 :Package = new Package("fancy"); // some fancy package
			var foo2 :Symbol = p2.intern("foo");
			check(foo2.name, "foo");
			check(foo2.pkg, p2);
			check(foo2.fullName, "fancy:foo");
			
			// test the packages list
			
			check(Packages.global.name, null); // get the global package
			check(Printer.toString(Packages.global.intern("foo")), "foo"); // check symbol name
			check(Packages.keywords.name, "");	// get the keywords package
			check(Printer.toString(Packages.keywords.intern("foo")), ":foo");  // check symbol name
			Packages.add(p2); 						// add a fancy custom package
			check(Packages.intern("fancy"), p2);	// get the custom package - should be the same one
			check(Printer.toString(Packages.intern("fancy").intern("foo")), "fancy:foo");  // check symbol name
			check(Packages.remove(p2)); 			// check removal (should only return true the first time)
			check(! Packages.remove(p2)); 			// check removal (should only return true the first time)
			
			// test environments
			
			p = new Package("temp");
			var e2 :Environment = Environment.prepend(Cons.make(p.intern("env2symbol0")), null);
			// e2.setAt(0, p.intern("env2symbol0"));
			var e1 :Environment = Environment.prepend(Cons.make(p.intern("env1symbol0"), p.intern("env1symbol1")), e2);
			// e1.setAt(0, p.intern("env1symbol0"));
			// e1.setAt(1, p.intern("env1symbol1"));
			var e0 :Environment = Environment.prepend(Cons.make(p.intern("env0symbol0"), p.intern("env0symbol1")), e1);
			// e0.setAt(0, p.intern("env0symbol0"));
			// e0.setAt(1, p.intern("env0symbol1"));
			check(Environment.getLocation(p.intern("env2symbol0"), e0)[0], 2); // get frame coord
			check(Environment.getLocation(p.intern("env2symbol0"), e0)[1], 0); // get symbol coord
			check(Environment.getLocation(p.intern("env1symbol1"), e0)[0], 1); // get frame coord
			check(Environment.getLocation(p.intern("env1symbol1"), e0)[1], 1); // get symbol coord
			check(Environment.getLocation(p.intern("env0symbol0"), e0)[0], 0); // get frame coord
			check(Environment.getLocation(p.intern("env0symbol0"), e0)[1], 0); // get symbol coord
			var e2s0loc :Vector.<uint> = Environment.getLocation(p.intern("env2symbol0"), e0);
			check(Environment.getSymbolAt(e2s0loc[0], e2s0loc[1], e0), p.intern("env2symbol0"));
			Environment.setSymbolAt(e2s0loc[0], e2s0loc[1], p.intern("NEW_SYMBOL"), e0);
			check(Environment.getSymbolAt(e2s0loc[0], e2s0loc[1], e0), p.intern("NEW_SYMBOL"));
			check(Environment.getLocation(p.intern("NEW_SYMBOL"), e0)[0], 2); // get frame coord
			check(Environment.getLocation(p.intern("NEW_SYMBOL"), e0)[1], 0); // get symbol coord
		}
		
		/** Tests the parser part of the system */
		public static function testParser () :void {
			log("Running testParser");

			// first, test the stream wrapper
			var stream :Stream = new Stream();
			stream.add("foo");
			stream.save();
			check(! stream.isEmpty);
			check(stream.peek(), "f"); // don't remove
			check(stream.read(), "f"); // remove
			check(stream.peek(), "o"); // don't remove
			check(stream.read(), "o"); // remove
			check(stream.read(), "o"); // remove last one
			check(stream.read(), null);
			check(stream.isEmpty);
			check(stream.restore());   // make sure we can restore the old save
			check(stream.peek(), "f"); // we're back at the beginning
			check(! stream.restore()); // there's nothing left to restore
			
			// test parsing simple atoms, check their internal form
			checkParseRaw("1", 1);
			checkParseRaw("+1.1", 1.1);
			checkParseRaw("-2.0", -2);
			checkParseRaw("#t", true);
			checkParseRaw("#f", false);
			checkParseRaw("#unknown", false);
			checkParseRaw("a", Packages.global.intern("a"));
			checkParseRaw("()", null);
			checkParseRaw("\"foo \\\" \"", "foo \" ");
			
			// now test by comparing their printed form
			checkParse("(a b c)", "(a b c)");
			checkParse(" (   1.0 2.1   -3  #t   #f   ( ) a  b  c )  ", "(1 2.1 -3 #t #f () a b c)");
			checkParse("(a (b (c d)) e)", "(a (b (c d)) e)");
			checkParse("'(foo) '((a b) c) '()", "(quote (foo))", "(quote ((a b) c))", "(quote ())");
			checkParse("(a b ; c d)\n   e f)", "(a b e f)");
			
			// now check backquotes 
			checkParse("foo 'foo `foo `,foo", "foo", "(quote foo)", "(quote foo)", "foo");
			checkParse("`(foo)", "(list (quote foo))");
			checkParse("`(foo foo)", "(list (quote foo) (quote foo))");
			checkParse("`(,foo)", "(list foo)");
			checkParse("`(,@foo)", "(append foo)");
		}
		
		/** Test helper - does equality comparison on the raw parse results */
		private static function checkParseRaw (input :String, ... outputs) :void {
			var ctx :Context = new Context(Test.logger, false);
			ctx.parser.addString(input);
			var results :Array = ctx.parser.parseAll();
			check(results.length, outputs.length);
			while (results.length > 0 && outputs.length > 0) {
				check(results.shift(), outputs.shift());
			}
		}
		
		/** Test helper - takes parse results, converts them to the canonical string form, and compares to outputs */
		private static function checkParse (input :String, ... outputs) :void {
			var ctx :Context = new Context(Test.logger, false);
			ctx.parser.addString(input);
			var results :Array = ctx.parser.parseAll();
			check(results.length, outputs.length);
			while (results.length > 0 && outputs.length > 0) {
				check(Printer.toString(results.shift()), outputs.shift());
			}
		}

		/** Tests the compiler */
		public static function testCompiler () :void {
			log("Running testCompiler");
			
			// comment this one in or out, depending on how much info you want:
			printSampleCompilations();
		}
		
		/** Compiles some sample scripts and prints them out, without validation. */
		private static function printSampleCompilations () :void {
			var ctx :Context = new Context(Test.logger, false);

			compileAndPrint(ctx, "5");
			compileAndPrint(ctx, "\"foo\"");
			compileAndPrint(ctx, "#t");
			compileAndPrint(ctx, "'foo");
			compileAndPrint(ctx, "(begin 1)");
			compileAndPrint(ctx, "(begin 1 2 3)");
			compileAndPrint(ctx, "x");
			compileAndPrint(ctx, "(set! x (begin 1 2 3))");
			compileAndPrint(ctx, "(begin (set! x (begin 1 2 3)) x)");
			compileAndPrint(ctx, "(if p x y)");
			compileAndPrint(ctx, "(begin (if p x y) z)");
			compileAndPrint(ctx, "(if 5 x y)");
			compileAndPrint(ctx, "(if #f x y)");
			compileAndPrint(ctx, "(if x y)");
			compileAndPrint(ctx, "(if p x (begin 1 2 x))");
			compileAndPrint(ctx, "(if (not p) x y)");
			compileAndPrint(ctx, "(if (if a b c) x y)");
			compileAndPrint(ctx, "(lambda () 5)");
			compileAndPrint(ctx, "((lambda () 5))");
			compileAndPrint(ctx, "(lambda (a) a)");
			compileAndPrint(ctx, "(lambda (a) (lambda (b) a))");
			compileAndPrint(ctx, "(set! x (lambda (a) a))");
			compileAndPrint(ctx, "((lambda (a) a) 5)");
			compileAndPrint(ctx, "((lambda (x) ((lambda (y z) (f x y z)) 3 x)) 4)");
			compileAndPrint(ctx, "(if a b (f c))");
			compileAndPrint(ctx, "(if* (+ 1 2) b)");
			compileAndPrint(ctx, "(if* #f b)");
			compileAndPrint(ctx, "(begin (- 2 3) (+ 2 3))");
//			compileAndPrint(ctx, "(begin (set! sum (lambda (x) (if (<= x 0) 0 (sum (+ 1 (- x 1)))))) (sum 5))");
		}
		
		/** Front-to-back test of the virtual machine */
		private static function testMachine () :void {
			// first without the standard library
			var ctx :Context = new Context(Test.logger, false);
			
			// test reserved keywords
			compileAndRun(ctx, "5", "5");
			compileAndRun(ctx, "#t", "#t");
			compileAndRun(ctx, "\"foo\"", "\"foo\"");
			compileAndRun(ctx, "(begin 1 2 3)", "3");
			compileAndRun(ctx, "xyz", "[Undefined]");
			compileAndRun(ctx, "xyz", "[Undefined]");
			compileAndRun(ctx, "(set! x 5)", "5");
			compileAndRun(ctx, "(begin (set! x 2) x)", "2");
			compileAndRun(ctx, "(begin (set! x #t) (if x 5 6))", "5");
			compileAndRun(ctx, "(begin (set! x #f) (if x 5 6))", "6");
			compileAndRun(ctx, "(begin (if* 5 6))", "5");
			compileAndRun(ctx, "(begin (if* (if 5 #f) 6))", "6");
			compileAndRun(ctx, "(begin (if* (+ 1 2) 4) 5)", "5");
			compileAndRun(ctx, "(begin (if* (if 5 #f) 4) 5)", "5");
			compileAndRun(ctx, "((lambda (a) a) 5)", "5");
			compileAndRun(ctx, "((lambda (a . b) b) 5 6 7 8)", "(6 7 8)");
			compileAndRun(ctx, "((lambda (a) (set! a 6) a) 1)", "6");
			compileAndRun(ctx, "((lambda (x . rest) (if x 'foo rest)) #t 'a 'b 'c)", "foo");
			compileAndRun(ctx, "((lambda (x . rest) (if x 'foo rest)) #f 'a 'b 'c)", "(a b c)");
			compileAndRun(ctx, "(begin (set! x (lambda (a b c) (if a b c))) (x #t 5 6))", "5");
			
			// test primitives
			compileAndRun(ctx, "(+ 1 2)", "3");
			compileAndRun(ctx, "(+ (+ 1 2) 3)", "6");
			compileAndRun(ctx, "(+ 1 2 3)", "6");
			compileAndRun(ctx, "(* 1 2 3)", "6");
			compileAndRun(ctx, "(= 1 1)", "#t");
			compileAndRun(ctx, "(!= 1 1)", "#f");
			compileAndRun(ctx, "(cons 1 2)", "(1 . 2)");
			compileAndRun(ctx, "`(a 1)", "(a 1)");
			compileAndRun(ctx, "(list)", "()");
			compileAndRun(ctx, "(list 1)", "(1)");
			compileAndRun(ctx, "(list 1 2)", "(1 2)");
			compileAndRun(ctx, "(list 1 2 3)", "(1 2 3)");
			compileAndRun(ctx, "(length '(a b c))", "3");
			compileAndRun(ctx, "(append '(1 2) '(3 4) '() '(5))", "(1 2 3 4 5)");
			compileAndRun(ctx, "(list (append '() '(3 4)) (append '(1 2) '()))", "((3 4) (1 2))");
			compileAndRun(ctx, "(list #t (not #t) #f (not #f) 1 (not 1) 0 (not 0))", "(#t #f #f #t 1 #f 0 #f)");
			compileAndRun(ctx, "(list (null? ()) (null? '(a)) (null? 0) (null? 1) (null? #f))", "(#t #f #f #f #f)");
			compileAndRun(ctx, "(list (cons? ()) (cons? '(a)) (cons? 0) (cons? 1) (cons? #f))", "(#f #t #f #f #f)");
			compileAndRun(ctx, "(list (atom? ()) (atom? '(a)) (atom? 0) (atom? 1) (atom? #f))", "(#t #f #t #t #t)");
			compileAndRun(ctx, "(list (number? ()) (number? '(a)) (number? 0) (number? 1) (number? #f))", "(#f #f #t #t #f)");
			compileAndRun(ctx, "(list (string? ()) (string? '(a)) (string? 0) (string? 1) (string? #f) (string? \"foo\"))", "(#f #f #f #f #f #t)");
			compileAndRun(ctx, "(begin (set! x '(1 2 3 4 5)) (list (car x) (cadr x) (caddr x) (cdddr x)))", "(1 2 3 (4 5))");
			compileAndRun(ctx, "(begin (trace \"foo\" \"bar\") 5)", "5");
			compileAndRun(ctx, "(begin (set! first car) (first '(1 2 3)))", "1");
			
			// test quotes and macros
			compileAndRun(ctx, "`((list 1 2) ,(list 1 2) ,@(list 1 2))", "((list 1 2) (1 2) 1 2)");
			compileAndRun(ctx, "(begin (set! x 5) (set! y '(a b)) `(x ,x ,y ,@y))", "(x 5 (a b) a b)");
			compileAndRun(ctx, "(begin (defmacro inc1 (x) `(+ ,x 1)) (inc1 2))", "3");
			compileAndRun(ctx, "(begin (defmacro foo (op . rest) `(,op ,@(map number? rest))) (foo list 1 #f 'a))", "(#t #f #f)");
			compileAndRun(ctx, "(begin (defmacro lettest (bindings . body) `((lambda ,(map car bindings) ,@body) ,@(map cadr bindings))) (lettest ((x 1) (y 2)) (+ x y)))", "3");
			compileAndRun(ctx, "(begin (defmacro inc1 (x) `(+ ,x 1)) (inc1 (inc1 (inc1 1))))", "4");
			compileAndRun(ctx, "(begin (defmacro add (x y) `(+ ,x ,y)) (mx1 '(add 1 (add 2 3))))", "(core:+ 1 (add 2 3))");
			
			// test packages
			compileAndRun(ctx, "(package-set \"foo\") (package-get)", "\"foo\"", "\"foo\"");
			compileAndRun(ctx, "(package-set \"foo\") (package-import \"core\") (car '(1 2))", "\"foo\"", "()", "1");
			compileAndRun(ctx, "(set! x 5) (package-set \"foo\") (package-import \"core\") (set! x 6) (package-set nil) x", "5", "\"foo\"", "()", "6", "()", "5");
			compileAndRun(ctx, "(package-set \"foo\") (package-import \"core\") (set! first car) (first '(1 2))", "\"foo\"", "()", "[Closure]", "1");
			compileAndRun(ctx, "(package-set \"a\") (package-export '(afoo)) (set! afoo 1) (package-set \"b\") (package-import \"a\") afoo", "\"a\"", "()", "1", "\"b\"", "()", "1");
			
			// test more integration
			compileAndRun(ctx, "(package-set \"foo\")", "\"foo\"");
			compileAndRun(ctx, "(begin (+ (+ 1 2) 3) 4)", "4");
			compileAndRun(ctx, "(begin (set! incf (lambda (x) (+ x 1))) (incf (incf 5)))", "7");
			compileAndRun(ctx, "(begin (set! fact (lambda (x) (if (<= x 1) 1 (* x (fact (- x 1)))))) (fact 5))", "120");
			compileAndRun(ctx, "(begin (set! add +) (add 3 (add 2 1)))", "6");
			compileAndRun(ctx, "(begin (set! kar car) (set! car cdr) (set! result (car '(1 2 3))) (set! car kar) result)", "(2 3)");
			compileAndRun(ctx, "((lambda (x) (set! x 5) x) 6)", "5");

			// flash interop
			compileAndRun(ctx, "(new '(flash geom Point) 2 3)", "[Native: (x=2, y=3)]");
			compileAndRun(ctx, "(deref (new '(flash geom Point) 2 3) 'x)", "2");
			

			// now initialize the standard library
			ctx = new Context(Test.logger, true);	
			
			// test some basic functions
			compileAndRun(ctx, "(map number? '(a 2 \"foo\"))", "(#f #t #f)");

			// test standard library
			compileAndRun(ctx, "(package-set \"foo\")", "\"foo\"");
			compileAndRun(ctx, "(mx1 '(let ((x 1)) x))", "((lambda (foo:x) foo:x) 1)");
			compileAndRun(ctx, "(mx1 '(let ((x 1) (y 2)) (set! y 42) (+ x y)))", "((lambda (foo:x foo:y) (set! foo:y 42) (core:+ foo:x foo:y)) 1 2)");
			compileAndRun(ctx, "(mx1 '(let* ((x 1) (y 2)) (+ x y)))", "(core:let ((foo:x 1)) (core:let* ((foo:y 2)) (core:+ foo:x foo:y)))");
			compileAndRun(ctx, "(mx1 '(define x 5))", "(begin (set! foo:x 5) (quote foo:x))");
			compileAndRun(ctx, "(mx1 '(define (x y) 5))", "(core:define foo:x (lambda (foo:y) 5))");
			compileAndRun(ctx, "(list (gensym) (gensym) (gensym \"bar\"))", "(foo:GENSYM-1 foo:GENSYM-2 foo:bar-3)");
			compileAndRun(ctx, "(let ((x 1)) (+ x 1))", "2");
			compileAndRun(ctx, "(let ((x 1) (y 2)) (set! y 42) (+ x y))", "43");
			compileAndRun(ctx, "(let* ((x 1) (y x)) (+ x y))", "2");
			compileAndRun(ctx, "(let ((x 1)) (let ((y x)) (+ x y)))", "2");
			compileAndRun(ctx, "(letrec ((x (lambda () y)) (y 1)) (x))", "1");
			compileAndRun(ctx, "(begin (let ((x 0)) (define (set v) (set! x v)) (define (get) x)) (set 5) (get))", "5");
			compileAndRun(ctx, "(define x 5) x", "foo:x", "5");
			compileAndRun(ctx, "(define (x y) y) (x 5)", "foo:x", "5");
			compileAndRun(ctx, "(cons (first '(1 2 3)) (rest '(1 2 3)))", "(1 2 3)");
			compileAndRun(ctx, "(list (and 1) (and 1 2) (and 1 2 3) (and 1 #f 2 3))", "(1 2 3 #f)");
			compileAndRun(ctx, "(list (or 1) (or 2 1) (or (< 1 0) (< 2 0) 3) (or (< 1 0) (< 2 0)))", "(1 2 3 #f)");
			compileAndRun(ctx, "(cond ((= 1 2) 2) ((= 1 4) 4) 0)", "0");
			compileAndRun(ctx, "(cond ((= 2 2) 2) ((= 1 4) 4) 0)", "2");
			compileAndRun(ctx, "(cond ((= 1 2) 2) ((= 4 4) 4) 0)", "4");
			compileAndRun(ctx, "(case (+ 1 2) (2 #f) (3 #t) 'error)", "#t");
			compileAndRun(ctx, "(fold-left cons '() '(1 2))", "((() . 1) . 2)");
			compileAndRun(ctx, "(fold-right cons '() '(1 2))", "(1 2)");

			// standard library interop
			compileAndRun(ctx, "(.. (new '(flash geom Point) 2 3) '(x))", "2");
		}
		
		/** Compiles an s-expression and prints the resulting assembly */
		private static function compileAndPrint (ctx :Context, input :String) :void {
			log("compiling: ", input);
			ctx.parser.addString(input);
			var results :Array = ctx.parser.parseAll();
			for each (var result :* in results) {
				var cl :Closure = ctx.compiler.compile(result);
				log(Instruction.printInstructions(cl.instructions));
			}
		}
		
		/** Compiles an s-expression, runs the resulting code, and checks the output against the expected value */
		private static function compileAndRun (ctx :Context, input :String, ... expecteds) :void {
			ctx.parser.addString(input);
			log("inputs: ", input);
			
			while (expecteds.length > 0) {
				var expected :String = expecteds.shift();
				var result :* = ctx.parser.parseNext();

				log("parsed: ", Printer.toString(result));
				var cl :Closure = ctx.compiler.compile(result);
				log(Instruction.printInstructions(cl.instructions));
				
				log("running...");
				var output :* = ctx.vm.run(cl);
				var formatted :String = Printer.toString(output);
				check(formatted, expected);
			}
		}
		
		/** Checks whether the result is equal to the expected value; if not, logs an info statement */
		private static function check (result :*, expected :* = true, test :Function = null) :void {
			// log("test: got", result, " - expected", expected);
			var equal :Boolean = (test != null) ? test(result, expected) : (result == expected);
			if (! equal) {
				failures++;
				log("*** FAILED TEST: got", result, " - expected", expected);
			}
		}
		
		/** Log that log! */
		private static function log (... args) :void {
			if (logger != null) {
				logger.apply(null, args);
			}
		}
		
		/** Reference equality check */
		private static function equal (a :*, b :*) :Boolean {
			return a == b;
		}
	}

}