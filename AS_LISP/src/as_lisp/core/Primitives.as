package as_lisp.core
{
	import flash.utils.Dictionary;
	import flash.utils.getDefinitionByName;
	
	import as_lisp.data.Closure;
	import as_lisp.data.Cons;
	import as_lisp.data.Environment;
	import as_lisp.data.Instruction;
	import as_lisp.data.Package;
	import as_lisp.data.Packages;
	import as_lisp.data.Printer;
	import as_lisp.data.Symbol;
	import as_lisp.error.LanguageError;
	import as_lisp.util.Context;

	public class Primitives
	{
		
		private static var _gensymIndex :int = 1;
		
		/** Performs a left fold on the array: +, 0, [1, 2, 3] => (((0 + 1) + 2) + 3) */
		private static function foldArrayLeft (fn :Function, base :*, elements :Array) :* {
			for (var i :int = 0, len :uint = elements.length; i < len; i++) {
				base = fn(base, elements[i]);
			}
			return base;
		}
		
		/** Performs a right fold on the array: +, 0, [1, 2, 3] => (1 + (2 + (3 + 0))) */
		private static function foldArrayRight (fn :Function, base :*, elements :Array) :* {
			for (var i :int = elements.length - 1; i >= 0; i--) {
				base = fn(elements[i], base);
			}
			return base;
		}
		
		private static var ALL_PRIMITIVES_DICT :Dictionary = new Dictionary();
		private static const ALL_PRIMITIVES_VECTOR :Vector.<Primitive> = new <Primitive> [
			new Primitive("+", 2, 2, function (ctx :Context, a :Number, b :Number) :Number { return a + b; }, true ),
			new Primitive("-", 2, 2, function (ctx :Context, a :Number, b :Number) :Number { return a - b; }, true ),
			new Primitive("*", 2, 2, function (ctx :Context, a :Number, b :Number) :Number { return a * b; }, true ),
			new Primitive("/", 2, 2, function (ctx :Context, a :Number, b :Number) :Number { return a / b; }, true ),
			
			new Primitive("+", 3, uint.MAX_VALUE, function (ctx :Context, ... args) :Number { 
				return foldArrayLeft(function (a: Number, b :Number) :Number { return a + b; }, 0, args)
			}, true ),
			new Primitive("*", 3, uint.MAX_VALUE, function (ctx :Context, ... args) :Number { 
				return foldArrayLeft(function (a: Number, b :Number) :Number { return a * b; }, 1, args)
			}, true ),
			
			new Primitive("=", 2, 2, function (ctx :Context, a :*, b :*) :Boolean { return a == b; } ),
			new Primitive("!=", 2, 2, function (ctx :Context, a :*, b :*) :Boolean { return a != b; } ),
			
			new Primitive("<", 2, 2, function (ctx :Context, a :Number, b :Number) :Boolean { return a < b; } ),
			new Primitive("<=", 2, 2, function (ctx :Context, a :Number, b :Number) :Boolean { return a <= b; } ),
			new Primitive(">", 2, 2, function (ctx :Context, a :Number, b :Number) :Boolean { return a > b; } ),
			new Primitive(">=", 2, 2, function (ctx :Context, a :Number, b :Number) :Boolean { return a >= b; } ),
			
			new Primitive("cons", 2, 2, function (ctx :Context, a :*, b :*) :Cons { return new Cons(a, b); }, true ),
			new Primitive("list", 0, 0, function (ctx :Context) :Cons { return null; } ),
			new Primitive("list", 1, 1, function (ctx :Context, a :*) :Cons { return new Cons(a, null); }, true ),
			new Primitive("list", 2, 2, function (ctx :Context, a :*, b :*) :Cons { return new Cons(a, new Cons(b, null)); }, true ),
			new Primitive("list", 3, uint.MAX_VALUE, function (ctx :Context, ... args) :Cons { return Cons.make.apply(null, args); }, true ),
			new Primitive("append", 2, uint.MAX_VALUE, function (ctx :Context, ... args) :Cons { 
				return foldArrayRight(appendHelper, null, args);
			}),
			new Primitive("length", 1, 1, function (ctx :Context, a :*) :Number { return Cons.length(a); }, true),
			
			new Primitive("not", 1, 1, function (ctx :Context, a :*) :Boolean { return (a === false); } ),
			new Primitive("null?", 1, 1, function (ctx :Context, a :*) :Boolean { return (a === null); } ),
			new Primitive("cons?", 1, 1, function (ctx :Context, a :*) :Boolean { return Cons.isCons(a); } ),
			new Primitive("atom?", 1, 1, function (ctx :Context, a :*) :Boolean { return Cons.isAtom(a); } ),
			new Primitive("string?", 1, 1, function (ctx :Context, a :*) :Boolean { return (a is String); } ),
			new Primitive("number?", 1, 1, function (ctx :Context, a :*) :Boolean { return (a is Number); } ),
			new Primitive("boolean?", 1, 1, function (ctx :Context, a :*) :Boolean { return (a is Boolean); } ),
			
			new Primitive("car", 1, 1, function (ctx :Context, a :*) :* { return (a as Cons).car; } ),
			new Primitive("cdr", 1, 1, function (ctx :Context, a :*) :* { return (a as Cons).cdr; } ),
			new Primitive("cadr", 1, 1, function (ctx :Context, a :*) :* { return (a as Cons).cadr; } ),
			new Primitive("cddr", 1, 1, function (ctx :Context, a :*) :* { return (a as Cons).cddr; } ),
			new Primitive("caddr", 1, 1, function (ctx :Context, a :*) :* { return (a as Cons).caddr; } ),
			new Primitive("cdddr", 1, 1, function (ctx :Context, a :*) :* { return (a as Cons).cdddr; } ),
			
			new Primitive("map", 2, 2, function (ctx :Context, fn :Closure, list :Cons) :Cons {
				return mapHelper(ctx, fn, list);
			}, false, true),
			
			// macroexpansion
			new Primitive("mx1", 1, 1, function (ctx :Context, exp :*) :* {
				var result :* = ctx.compiler.macroExpand1(exp);
				return result;
			}),
			new Primitive("mx", 1, 1, function (ctx :Context, exp :*) :* {
				var result :* = ctx.compiler.macroExpandFull(exp);
				return result;
			}),
			
			// helpers
			new Primitive("trace", 1, uint.MAX_VALUE, function (ctx :Context, ... args) :* { trace(args.join(" ")); return null; }, false, true ),
			new Primitive("gensym", 0, 1, function (ctx :Context, prefix :String = "GENSYM") :Symbol {
				while (true) {
					var name :String = prefix + "-" + _gensymIndex;
					_gensymIndex++;
					if (ctx.parser.current.find(name, false) === undefined) {
						return ctx.parser.current.intern(name);
					}
				};
				return null; // this won't happen :)
			}),
			
			// packages
			new Primitive("package-set", 1, 1, function (ctx :Context, name :String) :* {
				var pkg :Package = Packages.intern(name);
				ctx.parser.current = pkg;
				return name;
			}, false, true),
			new Primitive("package-get", 0, 0, function (ctx :Context) :String {
				return ctx.parser.current.name;
			}, false, true),
			new Primitive("package-import", 1, uint.MAX_VALUE, function (ctx :Context, ... names) :String {
				for each (var name :String in names) {
					ctx.parser.current.addImport(Packages.intern(name));
				}
				return null;
			}, false, true),
			new Primitive("package-imports", 0, 0, function (ctx :Context) :Cons {
				var imports :Array = [];
				for each (var pkg :Package in ctx.parser.current.imports) {
					imports.push(pkg.name);
				}
				return Cons.make.apply(null, imports);
			}, false, true),
			new Primitive("package-export", 1, 1, function (ctx :Context, names :Cons) :String {
				while (names != null) {
					var symbol :Symbol = names.car as Symbol;
					symbol.exported = true;
					names = names.cdr;
				}
				return null;
			}, false, true),
			new Primitive("package-exports", 0, 0, function (ctx :Context) :Cons {
				var exports :Array = ctx.parser.current.listExports();
				return Cons.make.apply(null, exports);
			}, false, true),
			
			// FLASH INTEROP - work in progress, pardon the dust...
			new Primitive("new", 1, uint.MAX_VALUE, function (ctx :Context, path :Cons, ... args) :* {
				var name :String = collapseIntoNativeName(path);
				var def :Class = getDefinitionByName(name) as Class;
				if (def == null) {
					throw new LanguageError("Could not find native class named: " + Printer.toString(path));
				}
				return createNativeInstance(def, args);
			}),
			new Primitive("deref", 2, 2, function (ctx :Context, obj :*, field :Symbol) :* {
				if (! (obj is Object) || ! (obj as Object).hasOwnProperty(field.name)) {
					throw new LanguageError("Invalid dereference: " + obj + " / " + field.name);
				}
				return obj[field.name];
			})
			
		];
		

		/** 
		 * If f is a symbol that refers to a primitive, and it's not shadowed in the local environment,
		 * returns an appropriate instance of Primitive for that argument count.
		 */
		public static function findGlobal (f :*, env :Environment, nargs :uint) :Primitive {
			return ((f is Symbol) && (Environment.getLocation(f as Symbol, env) == null))
			? findNary((f as Symbol).name, nargs)
				: null;
		}
		
		/** Helper function, searches based on name and argument count */
		public static function findNary (symbol :String, nargs :uint) :Primitive {
			var primitives :Vector.<Primitive> = ALL_PRIMITIVES_DICT[symbol];
			for each (var p :Primitive in primitives) {
				if (symbol == p.name && nargs >= p.minargs && nargs <= p.maxargs) { 
					return p;
				}
			}
			return null;
		}
		
		/** Initializes the global package with stub functions for primitives */
		public static function initialize (pkg :Package) :void {
			
			// clear out and reinitialize the dictionary.
			// also, intern all primitives in their appropriate package
			ALL_PRIMITIVES_DICT = new Dictionary();
			
			for each (var p :Primitive in ALL_PRIMITIVES_VECTOR) {
				// dictionary update
				if (ALL_PRIMITIVES_DICT[p.name] == null) {
					ALL_PRIMITIVES_DICT[p.name] = new Vector.<Primitive>();
				}
				var v :Vector.<Primitive> = ALL_PRIMITIVES_DICT[p.name];
				v.push(p);

				// package interning
				var name :Symbol = pkg.intern(p.name);
				name.exported = true;
				var instructions :Vector.<Instruction> = new <Instruction> [
					new Instruction(Instruction.PRIM, p.name, null, null),
					new Instruction(Instruction.RETURN, null, null, null)
				];
				pkg.setBinding(name, new Closure(instructions, null, null, p.name));
			}
		}
		
		/** Performs the append operation on two lists */
		private static function appendHelper (a :Cons, b :Cons) :Cons { 
			var head :Cons = null;
			var current :Cons = null;
			var previous :Cons = null;
			
			// copy all nodes from a, set cdr of the last one to b
			while (a != null) {
				current = new Cons(a.car, null);
				if (head == null) {
					head = current;
				}
				if (previous != null) {
					previous.cdr = current;
				}
				previous = current;
				a = a.cdr;
			}
			
			if (current != null) {
				// a != () => head points to the first new node
				current.cdr = b;
			} else {
				// a == (), we should return b
				head = b;
			}
			
			return head;
		}
		
		/** Maps a function over elements of the list, and returns a new list with the results */
		private static function mapHelper (ctx :Context, fn :Closure, list :Cons) :Cons {
			
			var head :Cons = null;
			var current :Cons = null;
			var previous :Cons = null;
			
			// apply fn over all elements of the list, making a copy as we go
			while (list != null) {
				var input :* = list.car;
				var output :* = ctx.vm.run(fn, input);
				current = new Cons(output, null);
				if (head == null) {
					head = current;
				}
				if (previous != null) {
					previous.cdr = current;
				}
				previous = current;
				list = list.cdr;
			}
			
			return head;
		}
		
		/** Collapses a native path (expressed as a Cons list) into a fully qualified name */
		private static function collapseIntoNativeName (path :Cons) :String {
			var name :String = "";
			while (path != null) {
				if (name.length > 0) {
					name += ".";
				}
				name += (path.car as Symbol).name;
				path = path.cdr;
			}
			return name;
		}
		
		/** Creates a new instance of the native object */
		private static function createNativeInstance (clazz :Class, args :Array) :* {
			// this is unbelievably ugly, but: ActionScript doesn't let you call apply() on a constructor
			switch (args.length) {
				case 0: return new clazz();
				case 1: return new clazz(args[0]);
				case 2: return new clazz(args[0], args[1]);
				case 3: return new clazz(args[0], args[1], args[2]);
				case 4: return new clazz(args[0], args[1], args[2], args[3]);
				case 5: return new clazz(args[0], args[1], args[2], args[3], args[4]);
				case 6: return new clazz(args[0], args[1], args[2], args[3], args[4], args[5]);
				case 7: return new clazz(args[0], args[1], args[2], args[3], args[4], args[5], args[6]);
				case 8: return new clazz(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7]);
				case 9: return new clazz(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8]);
				default:
					// if you're passing 10+ arguments to the constructor, heavens be merciful on your soul
					throw new LanguageError("Too many constructor arguments: " + args.length);
			}
			return null;
		}

	}
}