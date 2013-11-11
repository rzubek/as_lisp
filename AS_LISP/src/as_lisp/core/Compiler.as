package as_lisp.core 
{
	import flash.utils.Dictionary;
	
	import as_lisp.data.Closure;
	import as_lisp.data.Cons;
	import as_lisp.data.Environment;
	import as_lisp.data.Instruction;
	import as_lisp.data.Macro;
	import as_lisp.data.Packages;
	import as_lisp.data.Printer;
	import as_lisp.data.Symbol;
	import as_lisp.error.CompilerError;
	import as_lisp.util.Context;

	/**
	 * Compiles source s-expression into bytecode.
	 */
	public class Compiler 
	{
		/** Label counter for each separate compilation block */
		private var _labelNum :int = 0;

		/** Internal execution context */
		private var _ctx :Context = null;
		
		// some helpful symbol constants, interned only once at the beginning
		private var _quote :Symbol;
		private var _begin :Symbol;
		private var _set :Symbol;
		private var _if :Symbol;
		private var _ifStar :Symbol;
		private var _lambda :Symbol;
		private var _defmacro :Symbol;

		public function Compiler (ctx :Context) {
			_quote = Packages.global.intern("quote");
			_begin = Packages.global.intern("begin");
			_set = Packages.global.intern("set!");
			_if = Packages.global.intern("if");
			_ifStar = Packages.global.intern("if*");
			_lambda = Packages.global.intern("lambda");
			_defmacro = Packages.global.intern("defmacro");
			
			_ctx = ctx;
			
			// initializePrimitives();
		}
		
		/** Top level compilation entry point. Compiles the expression x given an empty environment. */
		public function compile (x :*) :Closure {
			_labelNum = 0;
			return compLambda(null, new Cons(x, null), null);
		}
		
		/** 
		 * Compiles the expression x, given the environment env, into a vector of instructions 
		 * 
		 * Val and more flags are used for tail-call optimization. "Val" is true when 
		 * the expression returns a value that's then used elsewhere. "More" is false when 
		 * the expression represents the final value, true if there is more to compute.
		 * 
		 * <p> Examples, when compiling expression X:
		 * <ul>
		 * <li> val = t, more = t ... (if X y z) or (f X y)
		 * <li> val = t, more = f ... (if p X z) or (begin y X)
		 * <li> val = f, more = t ... (begin X y)
		 * <li> val = f, more = f ... impossible
		 */
		protected function comp (x :*, env :Environment, val :Boolean, more :Boolean) :Vector.<Instruction> {
			
 			// check if macro
			if (isMacroApplication(x)) {
				return comp(macroExpandFull(x), env, val, more);
			}

			if (x is Symbol) { 		// check if symbol
				return compVar(x as Symbol, env, val, more);
			} 
			
			if (Cons.isAtom(x)) {	// check if it's not a list
				return compConst(x, val, more);
			}
			
			// it's not an atom, it's a list, deal with it.
			var cons :Cons = x as Cons;
			verifyExpression(Cons.isList(cons), "Non-list expression detected!");
			
			switch (cons.car) {
				case _quote: 
					verifyArgCount(cons, 1);
					return compConst(cons.cadr, val, more);	// second element is the constant
				case _begin:
					return compBegin(cons.cdr, env, val, more);
				case _set:
					verifyArgCount(cons, 2);
					verifyExpression(cons.cadr is Symbol, "Invalid lvalue in set!, must be a symbol, got: ", cons.cadr);
					return compSet(cons.cadr as Symbol, cons.caddr, env, val, more);	
				case _if:
					verifyArgCount(cons, 2, 3);
					return compIf(cons.cadr, cons.caddr, (cons.cdddr != null ? cons.cdddr.car : null), env, val, more);
				case _ifStar:
					verifyArgCount(cons, 2);
					return compIfStar(cons.cadr, cons.caddr, env, val, more);
				case _lambda:
					if (! val) {
						return null;
					} else {
						var f :Closure = compLambda(cons.cadr, cons.cddr, env);
						return seq(
							gen(Instruction.FN, f, null, Printer.toString(cons.cddr)), 
							ifnot(more, gen(Instruction.RETURN)));
					}
				case _defmacro:
					return compAndInstallMacroDefinition(cons.cdr, env, val, more);
 				default:
					return compFuncall(cons.car, cons.cdr, env, val, more);
			}
		}
		
		/** 
		 * Verifies arg count of the expression (list of operands). 
		 * Min and max are inclusive; default value of max (= -1) is a special value,
		 * causes max to be treated as equal to min (ie., tests for arg count == min)
		 */
		private function verifyArgCount (cons :Cons, min :int, max :int = -1) :void {
			max = (max >= 0) ? max : min;  // default value means: max == min
			var count :int = Cons.length(cons.cdr);
			if (count < min || count > max) {
				throw new CompilerError("Invalid argument count in expression " + Printer.toString(cons) +
					": " + count + " supplied, expected in range [" + min + ", " + max + "]");
			}
		}
		
		/** Verifies that the expression is true, throws the specified error otherwise. */
		private function verifyExpression (condition :Boolean, ... messages) :void {
			if (! condition) {
				throw new CompilerError(messages.join(" "));
			}
		}

		/** Returns true if the given value is a macro */
		private function isMacroApplication (x :*) :Boolean {
			return (x is Cons) && 
				(x.car is Symbol) && 
				(x.car as Symbol).pkg.hasMacro(x.car);
		}
		
		/** Performs compile-time macroexpansion, one-level deep */
		public function macroExpand1 (exp :*) :* {
			if (! Cons.isCons(exp) || ! (exp.car is Symbol)) {
				return exp;
			}
			var cons :Cons = exp as Cons;
			var name :Symbol = cons.car as Symbol;	
			var macro :Macro = name.pkg.getMacro(name);
			if (macro == null) {
				return exp;
			}
			var callArgs :Array = [macro.body].concat(Cons.toArray(cons.cdr));
			var result :* = _ctx.vm.run.apply(null, callArgs);
			return result;
		}
		
		/** Performs compile-time macroexpansion, fully recursive */
		public function macroExpandFull (exp :*) :* {
			var result :* = macroExpand1(exp);
			if (! Cons.isCons(result) || ! (result.car is Symbol)) {
				return result;
			}

			var current :Cons = result;
			while (current != null) {
				var elt :Cons = (current is Cons) ? current.car as Cons : null;
				if (elt != null && elt.car is Symbol) {
					var substitute :* = macroExpandFull(elt);
					current.car = substitute;
				}
				current = current.cdr;
			}

			return result;
		}
		
		/** Compiles a variable lookup */
		private function compVar (x :Symbol, env :Environment, val :Boolean, more :Boolean) :Vector.<Instruction> {
			if (! val) {
				return null; 
			} else {
				var p :Vector.<uint> = Environment.getLocation(x, env);
				return seq(
					(p != null ?
						gen(Instruction.LVAR, p[0], p[1], Printer.toString(x)) :
						gen(Instruction.GVAR, x)),
					ifnot(more, gen(Instruction.RETURN)));
			}
		}

		/** Compiles a constant, if it's actually used elsewhere */
		private function compConst (x :*, val :Boolean, more :Boolean) :Vector.<Instruction> {
			if (val) {
				return seq(	
					gen(Instruction.CONST, x),
					ifnot(more, gen(Instruction.RETURN)) );
			} else {
				return null;
			}
		}
		
		/** Compiles a sequence defined by a BEGIN - we pop all values, except for the last one */
		private function compBegin (exps :*, env :Environment, val :Boolean, more :Boolean) :Vector.<Instruction> {
			if (exps == null) {
				return compConst(null, val, more);
			} 
			
			var cons :Cons = exps as Cons;
			verifyExpression(cons != null, "Unexpected value passed to begin block:", exps);

			if (cons.cdr == null) {	// length == 1
				return comp(cons.car, env, val, more);
			} else {
				return seq(
					comp(cons.car, env, false, true), 		// note: not the final expression, set val = f, more = t
					compBegin(cons.cdr, env, val, more));
			}
		}

		/** Compiles a variable set */
		private function compSet (x :Symbol, value :*, env :Environment, val :Boolean, more :Boolean) :Vector.<Instruction> {
			var p :Vector.<uint> = Environment.getLocation(x, env);
			return seq(
				comp(value, env, true, true),
				(p != null ?
						gen(Instruction.LSET, p[0], p[1], Printer.toString(x)) :
						gen(Instruction.GSET, x)),
				ifnot(val, gen(Instruction.POP)),
				ifnot(more, gen(Instruction.RETURN))
				);
		}

		/** Compiles an if statement (fun!) */
		private function compIf (pred :*, then :*, els :*, env :Environment, val :Boolean, more :Boolean) :Vector.<Instruction> {
			// (if #f x y) => y
			if (pred === false) {	
				return comp(els, env, val, more);
			} 
			
			// (if #t x y) => x, or (if 5 ...) or (if "foo" ...)
			var isConst :Boolean = (pred === true) || (pred is Number) || (pred is String);
			if (isConst) {
				return comp(then, env, val, more);
			}
			
			// (if (not p) x y) => (if p y x)
			if (Cons.isList(pred) && 
				Cons.length(pred as Cons) == 2 && 
				pred.car is Symbol &&
				(pred.car as Symbol).fullName == "not")  // TODO: this should make sure it's a const not just a symbol
			{
				return compIf(pred.cadr, els, then, env, val, more);
			}
			
			// it's more complicated...
			var pcode :Vector.<Instruction> = comp(pred, env, true, true);
			var tcode :Vector.<Instruction> = comp(then, env, val, more);
			var ecode :Vector.<Instruction> = els != null ? comp(els, env, val, more) : null;
			
			// (if p x x) => (begin p x)
			if (codeEquals(tcode, ecode)) {
				return seq(comp(pred, env, false, true), ecode);
			}
			
			var l1 :String, l2 :String;
			
			// (if p #f y) => p (TJUMP L2) y L2:
			if (tcode == null) {
				l2 = makeLabel();
				return seq(
					pcode, 
					gen(Instruction.TJUMP, l2),
					ecode,
					gen(Instruction.LABEL, l2),
					ifnot(more, gen(Instruction.RETURN)));
			}
			
			// (if p x) => p (FJUMP L1) x L1:
			if (ecode == null) {
				l1 = makeLabel();
				return seq(
					pcode,
					gen(Instruction.FJUMP, l1),
					tcode,
					gen(Instruction.LABEL, l1),
					ifnot(more, gen(Instruction.RETURN)));
			}
			
			// (if p x y) => p (FJUMP L1) x L1: y 
			//         or    p (FJUMP L1) x (JUMP L2) L1: y L2:
			l1 = makeLabel();
			l2 = (more ? makeLabel() : null);
			return seq(
				pcode,
				gen(Instruction.FJUMP, l1),
				tcode,
				ifnot(more, gen(Instruction.JUMP, l2)),
				gen(Instruction.LABEL, l1),
				ecode,
				ifnot(more, gen(Instruction.LABEL, l2)));
		}
		
		/** Compiles an if* statement */
		private function compIfStar (pred :*, els :*, env :Environment, val :Boolean, more :Boolean) :Vector.<Instruction> {
			
			// (if* x y) will return x if it's not false, otherwise it will return y
			
			// (if* #f x) => x
			if (pred === false) {	
				return comp(els, env, val, more);
			} 
		
			var pcode :Vector.<Instruction> = comp(pred, env, true, true);
			var ecode :Vector.<Instruction> = els != null ? comp(els, env, true, more) : null;
			
			// (if* p x) => p (DUPE) (TJUMP L1) (POP) x L1: (POP?)
			var l1 :String = makeLabel();
			return seq(
				pcode,
				gen(Instruction.DUPE),
				gen(Instruction.TJUMP, l1),
				gen(Instruction.POP),
				ecode,
				ifnot(more || val, gen(Instruction.RETURN)),
				gen(Instruction.LABEL, l1),
				ifnot(val, gen(Instruction.POP)),
				ifnot(more, gen(Instruction.RETURN)));
		}

		/** Compiles code to produce a lambda call */
		private function compLambda (args :*, body :Cons, env :Environment) :Closure {
			var newEnv :Environment = Environment.prepend(makeTrueList(args), env);
			var code :Vector.<Instruction> = seq(
				genArgs(args, 0),
				compBegin(body, newEnv, true, false));
			return new Closure(assemble(code), env, args);
		}
		
		/** Compile a list, leaving all elements on the stack */
		private function compList (exps :Cons, env :Environment) :Vector.<Instruction> {
			return (exps == null) 
				? null 
				: seq(
					comp(exps.car, env, true, true),
					compList(exps.cdr, env));
		}
		
		/** 
		 * Compiles a macro, and sets the given symbol to point to it. NOTE: unlike all other expressions,
		 * which are executed by the virtual machine, this happens immediately, during compilation.
		 */
		private function compAndInstallMacroDefinition (cons :Cons, env :Environment, val :Boolean, more :Boolean) :Vector.<Instruction> {

			// example: (defmacro foo (x) (+ x 1))
			var name :Symbol = cons.car as Symbol;
			var args :Cons = cons.cadr as Cons;
			var bodylist :Cons = cons.cddr as Cons;
			var body :Closure = this.compLambda(args, bodylist, env);
			var macro :Macro = new Macro(name, args, body);
			
			// install it in the package
			name.pkg.setMacro(name, macro);
			return compConst(null, val, more);
		}
		
		/** Compile the application of a function to arguments */
		private function compFuncall (f :*, args :Cons, env :Environment, val :Boolean, more :Boolean) :Vector.<Instruction> {
			if (f is Cons && f.car is Symbol && (f.car as Symbol).fullName == "lambda" && f.cadr == null) {
				// ((lambda () body)) => (begin body)
				verifyExpression(args == null, "Too many arguments supplied!");
				return compBegin(f.cddr, env, val, more);
			} else if (more) {
				// need to save the continuation point
				var k :String = makeLabel("K");
				return seq(
					gen(Instruction.SAVE, k),
					compList(args, env),
					comp(f, env, true, true),
					gen(Instruction.CALLJ, Cons.length(args)),
					gen(Instruction.LABEL, k),
					ifnot(val, gen(Instruction.POP)));
			} else {
				// function call as rename plus goto
				return seq(
					compList(args, env),
					comp(f, env, true, true),
					gen(Instruction.CALLJ, Cons.length(args)));
			}
		}
		
		/** Generates an appropriate ARGS or ARGSDOT sequence, making a new stack frame */
		private function genArgs (args :*, nSoFar :int) :Vector.<Instruction> {
			// recursively detect whether it's a list or ends with a dotted cons, and generate appropriate arg
			if (args == null) {
				return gen(Instruction.ARGS, nSoFar);
			} else if (args is Symbol) {
				return gen(Instruction.ARGSDOT, nSoFar);
			} else if (Cons.isCons(args) && args.car is Symbol) {
				return genArgs(args.cdr, nSoFar + 1);
			} else {
				throw new CompilerError("Invalid argument list");
			}
		}
		
		/** Converts a dotted cons list into a proper non-dotted one */
		private function makeTrueList (dottedList :*) :Cons {
			if (dottedList == null) {
				return null;
			} else if (! Cons.isCons(dottedList)) {
				return new Cons(dottedList, null);
			} else {
				return new Cons(dottedList.car, makeTrueList(dottedList.cdr));
			}
		}
		 
		/** Generates a sequence containing a single instruction */
		private function gen (type :int, first :* = null, second :* = null, debug :* = null) :Vector.<Instruction> {
			return new <Instruction> [ new Instruction(type, first, second, debug) ];
		}
		
		/** Creates a new unique label */
		private function makeLabel (prefix :String = "L") :String {
			var name :String = prefix + String(_labelNum);
			_labelNum ++;
			return name;
		}
		
		/** Merges sequences of instructions into a single sequence */
		private function seq (... elements) :Vector.<Instruction> {
			var results :Vector.<Instruction> = new Vector.<Instruction>();
			for each (var element :* in elements) {
				if (element is Vector.<Instruction>) {
					results = results.concat(element);
				} else if (element == null) {
					// skip it
				} else {
					throw new CompilerError("Unknown seq parameter: " + element);
				}
			}
			return results;
		}
		
		/** Returns the value if the condition is false, null if it's true */
		private function ifnot (condition :Boolean, value :*) :* {
			return (! condition) ? value : null;
		}
		
		/** Compares two code sequences, and returns true if they're equal */
		private function codeEquals (a :Vector.<Instruction>, b :Vector.<Instruction>) :Boolean {
			if (a == null && b == null) {
				return true;
			}
			if (a == null || b == null || a.length != b.length) {
				return false;
			}
			for (var i :int = 0; i < a.length; i++) {
				if (! Instruction.equal(a[i], b[i])) {
					return false;
				}
			}
			return true;
		}

		private const JUMP_TYPES :Vector.<int> = new <int> [
			Instruction.JUMP, Instruction.FJUMP, Instruction.TJUMP, Instruction.SAVE 
		];

		/** 
		 * "Assembles" the compiled code, by resolving label references and converting them to index offsets. 
		 * Modifies the code data structure in place, and returns it back to the caller.
		 */
		private function assemble (code :Vector.<Instruction>) :Vector.<Instruction> {
			var positions :Dictionary = findLabelPositions(code);
			for (var i :uint = 0; i < code.length; i++) {
				var inst :Instruction = code[i];
				if (JUMP_TYPES.indexOf(inst.type) >= 0 && positions[inst.first] != null) {
					code[i] = new Instruction(inst.type, inst.first, positions[inst.first], inst.debug);
				}
			}
			return code;
		}
		
		/** Generates a dictionary from label name to its position in the vector */
		private function findLabelPositions (code :Vector.<Instruction>) :Dictionary {
			var results :Dictionary = new Dictionary();
			for (var i :uint = 0; i < code.length; i++) {
				var inst :Instruction = code[i];
				if (inst.type == Instruction.LABEL) {
					results[inst.first] = i;
				}
			}
			return results;
		}
	}

}