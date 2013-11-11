package as_lisp.core 
{
	import as_lisp.data.Cons;
	import as_lisp.data.Package;
	import as_lisp.data.Packages;
	import as_lisp.data.Symbol;
	import as_lisp.error.ParserError;
	import as_lisp.util.Context;
	import as_lisp.util.Stream;

	/**
	 * Parser reads strings, and spits out s-expressions
	 */
	public class Parser 
	{
		/** Full list of reserved keywords - no symbol can be named as one of these */
		private static const RESERVED :Vector.<String> = new < String > [ "quote", "begin", "set!", "if", "if*", "lambda", "defmacro", "." ];
		
		/** Special "end of stream" constant */
		public static const EOF :String = "!eof";
		
		/** Internal execution context */
		private var _ctx :Context = null;
		
		/** Internal stream */
		private var _stream :Stream = new Stream();

		/** Current package, used to intern symbols */
		private var _current :Package;
		
		/** Global unnamed package, used for symbols like "quote" */
		private var _global :Package;

		public function Parser (ctx :Context) :void {
			_ctx = ctx;
			_global = Packages.global; 
			_current = Packages.global; // current one is the global one to start with
		}

		/** Returns the current package */
		public function get current () :Package {
			return _current;
		}
		
		/** Sets the current package */
		public function set current (value :Package) :void {
			_current = value;
		}
		
		/** Adds a new string to the parse buffer */
		public function addString (str :String) :void {
			_stream.add(str);
		}

		/** Parses and returns all the elements it can from the stream */
		public function parseAll () :Array {
			var results :Array = [];
			var result :* = parseNext();
			while (result != EOF) {
				results.push(result);
				result = parseNext();
			}
			return results;
		}
		
		/** 
		 * Parses the next element out of the stream (just one, if the stream contains more). 
		 * Returns EOF and restores the stream, if no full element has been found.
		 */
		public function parseNext () :* {
			_stream.save();
			var result :* = parse(_stream);
			if (result != EOF) {
				// trace("==> " + Printer.toString(result));
				return result;
			}
			
			_stream.restore();
			return EOF;
		}
		
		/** 
		 * Parses an expression out of the stream. 
		 * If the stream contains more than one expression, stops after the first one.
		 * If the stream did not contain a full expression, returns null (not NIL!)
		 */
		private function parse (stream :Stream, backquote :Boolean = false) :*
		{
			// pull out the first character, we'll dispatch on it 
			if (stream.isEmpty) {
				return EOF;
			}
			
			// remove leading whitespace
			consumeWhitespace(stream);
			
			// check for special forms
			var result :* = EOF;
			var c :String = stream.peek();
			switch (c) {
				case ";":
					consumeTillEndOfLine(stream);
					result = parse(stream, backquote);
					break;
				case "(":
					// parseList will take care of the list, including the closing paren
					result = parseList(stream, backquote);
					break;
				case ")":
					// well that was unexpected
					throw new ParserError("Unexpected closed parenthesis!");
					break;
				case "\"":
					// parseString will take care of the string, including the closing quote
					result = parseString(stream);
					break;
				case "\'":
					// 'foo => (quote foo)
					stream.read();
					result = parse(stream, backquote);
					result = Cons.make(_global.intern("quote"), result);
					break;
				case "\`": 
					// `foo => (` foo) => converted value
					stream.read();
					result = parse(stream, true);
					result = Cons.make(_global.intern("`"), result);
					result = convertBackquote(result as Cons);
					break;
                case ',':
                    // ,foo => (, foo) 
                    // except that 
                    // ,@foo => (,@ foo)
					stream.read();
					if (! backquote) {
						throw new ParserError("Unexpected unquote!");
					}
					var atomicUnquote :Boolean = true;
					if (stream.peek() == "@") {
						stream.read();
						atomicUnquote = false;
					}
					result = parse(stream, false);
					result = Cons.make(_global.intern(atomicUnquote ? "," : ",@"), result);
					break;
				default:
					// just a value. pick how to parse
					result = parseAtom(stream, backquote);
					break;
			}
			
			// consume trailing whitespace
			consumeWhitespace(stream);
			
			return result;
		}
		
		/** Is this one of the standard whitespace characters? */
		private function isWhitespace (char :String) :Boolean {
			return (char == " " || char == "\t" || char == "\n" || char == "\r");
		}
		
		/** Eats up whitespace, nom nom */
		private function consumeWhitespace (stream :Stream) :void {
			var c :String = stream.peek();
			while (isWhitespace(c)) {
				stream.read();
				c = stream.peek();
			}
		}

		/** Eats up everything till end of line */
		private function consumeTillEndOfLine (stream :Stream) :void {
			var c :String = stream.peek();
			while (c != "\n" && c != "\r") {
				stream.read();
				c = stream.peek();
			}
		}

		private static const SPECIAL_ELEMENTS :Vector.<String> = new < String > [ "(", ")", "\"", "'", "`" ];

		/** Special elements are like whitespace - they interrupt tokenizing */
		private function isSpecialElement (elt :String, insideBackquote :Boolean) :Boolean {
			var idx :int = SPECIAL_ELEMENTS.indexOf(elt);
			if (idx >= 0) {
				return true;
			}
			if (insideBackquote && elt == ",") {
				return true;
			}
			return false;
		}
		
		private static const ZERO_CHAR_CODE :Number = "0".charCodeAt(0);
		private static const NINE_CHAR_CODE :Number = "9".charCodeAt(0);
		private function isDigit (elt :String) :Boolean {
			var code :Number = elt.charCodeAt(0);
			return code >= ZERO_CHAR_CODE && code <= NINE_CHAR_CODE;
		}
		
        /** 
         * Parses a single element (token), based on following rules:
         *   - if it's #t, it will be converted to a boolean true
         *   - otherwise if it starts with #, it will be converted to a boolean false
         *   - otherwise if it starts with +, -, or a digit, it will be converted to a number 
         *     (assuming parsing validation passes)
         *   - otherwise it will be returned as a symbol
         */
		private function parseAtom (stream :Stream, backquote :Boolean) :* {
			
			// tokenizer loop
			var str :String = "";
			var char :String;
			while ((char = stream.peek()) != null) {
				if (isWhitespace(char) || isSpecialElement(char, backquote)) {
					break; // we're done here, don't touch the special character
				}
				str += char;
				stream.read(); // consume and advance to the next one
			}
			
			// did we fail?
			if (str.length == 0) {
				return EOF;
			}
			
			// #t => true, #(anything) => false
			var c0 :String = str.charAt(0);
			if (c0 == "#") {
				if (str.length == 2 && str.charAt(1).toLowerCase() == "t") {
					return true;
				} else {
					return false;
				}
			}
			
            // parse if it starts with -, +, or a digit, but fall back if it causes a parse error
            if (c0 == "-" || c0 == "+" || isDigit(c0)) {
				try {
					var value :Number = Number(str);
					if (! isNaN(value)) {
						return value;
					}
				} catch (e :Error) {
					// do nothing, it's not a number
				}
			}
			
			// parse as symbol
			return parseSymbol(str);
		}
		
		/** Parses as a symbol, taking into account optional package prefix */
		private function parseSymbol (name :String) :* {
			// if this is a reserved keyword, always using global namespace
			if (RESERVED.indexOf(name) >= 0) {
				return _global.intern(name);
			}
			
			// figure out the package. default to current package.
			var colon :int = name.indexOf(":");
			var p :Package = _current;						

			// reference to a non-current package - let's look it up there
			if (colon >= 0) {
				name.substr(0, colon);
				p = Packages.intern(name.substr(0, colon));	// we have a specific package name, look there instead
				if (p == null) {
					throw new ParserError("Unknown package: " + name.substr(0, colon));
				}
				name = name.substr(colon + 1);
			}
			
			// do we have the symbol anywhere in that package or its imports?
			var result :* = p.find(name, true);
			if (result !== undefined) {
				return result;
			}
			
			// never seen it before - intern it!
			return p.intern(name);
		}
		
		/** 
		 * Starting with an opening double-quote, it will consume everything up to and including closing double quote.
		 * Any characters preceded by backslash will be escaped.
		 */
		private function parseString (stream :Stream) :* {

			var str :String = "";
			var char :String = null;
			
			stream.read(); // consume the opening quote

			while (true) {
				char = stream.read();
				if (char == null) {
					throw new ParserError("String not properly terminated: " + str);
				}
			
				if (char == "\"") {
					// we've consumed the closing double-quote, we're done.
					break;
				}
				
				if (char == "\\") {
					// we got the escape - just consume the next character, whatever it is
					char = stream.read();
				}
				
				str += char;
			} 
			
			return str;
		}

        /** 
         * Starting with an open paren, recursively parse everything up to the matching closing paren,
         * and then return it as a sequence of conses.
         */
		private function parseList(stream :Stream, backquote :Boolean) :* {
			
			var values :Array = [];			
			var char :String = stream.read(); // consume opening paren
			consumeWhitespace(stream);
			
			while ((char = stream.peek()) != ")" && char != null) {
				var val :* = parse(stream, backquote);
				values.push(val);
			}
			
			stream.read(); // consume the closing paren
			consumeWhitespace(stream);
			
			return Cons.make.apply(null, values);
		}
		
		/**
		 * Converts a backquote expression according to the following rules:
		 * (` e) where e is atomic => (quote e)
		 * (` (, e)) => e
		 * (` (a ...)) => (append [a] ...) where
		 *   [(, a)] => (list a)
		 *   [(,@ a)] => a
		 *   [a] => (list (` a)) converted further recursively
		 */
		private function convertBackquote (cons :Cons) :* {
			var first :Symbol = cons.car as Symbol;
			if (first == null || first.name != "`") {
				throw new ParserError("Unexpected symbol " + first + " in place of backquote");
			}
			
			// (` e) where e is atomic => e
			if (Cons.isAtom(cons.cadr)) {
				return Cons.make(_global.intern("quote"), cons.cadr);
			}
			
			var second :Cons = cons.cadr as Cons;
			
			// (` (, e)) => e
			if (isNamedSymbol(second.car, ",")) {
				return second.cadr;
			}
			
			// we didn't match any special forms, just do a list match
			// (` (a ...)) => (append [a] ...) 
			var forms :Array = []
			var vv :* = second;
			while (vv is Cons) {
				forms.push(convertBracket((vv as Cons).car));
				vv = (vv as Cons).cdr;
			}
			
			var result :Cons = new Cons(_global.intern("append"), Cons.make.apply(null, forms));
			
			// now do a quick optimization: if the result is of the form:
			// (append (list ...) (list ...) ...) where all entries are known to be lists,
			// convert this to (list ... ... ...)
			result = tryOptimizeAppend(result);
			return result;
		}
		
		/** 
		 * Performs a single bracket substitution for the backquote:
		 * 
		 * [(, a)] => (list a)
		 * [(,@ a)] => a
		 * [a] => (list (` a))
		 */
		private function convertBracket (value :*) :* {
			if (value is Cons) {
				var cons :Cons = value as Cons;
				if (cons.car is Symbol) {
					var sym :Symbol = cons.car as Symbol;
					switch (sym.name) {
						case ",":
							// [(, a)] => (list a)
							return new Cons(_global.intern("list"), cons.cdr);
						case ",@":
							// [(,@ a)] => a
							return cons.cadr;
					}
				}
			}
			
			// [a] => (list (` a))
			return Cons.make(_global.intern("list"), convertBackquote(Cons.make(_global.intern("`"), value)));
		}
		
		/** 
		 * If the results form follows the pattern (append (list a b) (list c d) ...)
		 * it will be converted to a simple (list a b c d ...)
		 */
		private function tryOptimizeAppend (value :Cons) :* {
			if (! isNamedSymbol(value.car, "append")) {
				return value;
			}
			
			var results :Array = [];
			var rest :* = value.cdr;
			while (rest != null) {
				if (! (rest is Cons)) {
					return value; // not a proper list
				}
				var first :Cons = (rest as Cons).car as Cons;
				if (first == null) {
					return value; // not all elements are lists themselves
				}
				if (! isNamedSymbol(first.car, "list")) {
					return value; // not all elements are of the form (list ...)
				}
				var ops :* = first.cdr;
				while (ops is Cons) {
					results.push((ops as Cons).car);
					ops = (ops as Cons).cdr;
				}
				rest = (rest as Cons).cdr;				
			}
			
			// we've reassembled the bodies, return them in the form (list ...)
			return new Cons(_global.intern("list"), Cons.make.apply(null, results));
		}
		
		/** Convenience function: checks if the value is of type Symbol, and has the specified name */
		private function isNamedSymbol (value :*, fullName :String) :Boolean {
			var symbol :Symbol = value as Symbol;
			return (symbol != null) && (symbol.fullName == fullName);
		}

	}	
}