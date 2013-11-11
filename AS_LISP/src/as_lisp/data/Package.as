package as_lisp.data 
{
	import flash.utils.Dictionary;
	
	import as_lisp.error.LanguageError;
	
	/**
	 * Package is a storage for symbols. When the parser reads out symbols from the stream,
	 * it retrieves the appropriate symbol from the package, or if one hasn't been seen before,
	 * it interns a new one.
	 */
	public class Package 
	{
		/** Name of this package */
		private var _name :String; 
		
		/** Map from symbol name (string) to instance (Symbol) */
		private var _symbols :Dictionary;
		
		/** Map from symbol (Symbol) to its value (*) */
		private var _bindings :Dictionary;
		
		/** Map from macro name (Symbol) to the actual macro body */
		private var _macros :Dictionary;
		
		/** 
		 * Vector of other packages imported into this one. 
		 * Symbol lookup will use these packages, if the symbol is not found here. 
		 */
		private var _imports :Vector.<Package>;
		
		public function Package (name :String) {
			_name = name;
			_symbols = new Dictionary();
			_bindings = new Dictionary();
			_macros = new Dictionary();
			_imports = new Vector.<Package>();
		}
		
		/** Name of this package */
		public function get name () :String { return _name; }
		
		/** 
		 * Returns a symbol with the given name if one was interned, undefined otherwise.
		 * If deep is true, it will also search through all packages imported by this one. 
		 */
		public function find (name :String, deep :Boolean) :* {
			var result :* = _symbols[name];
			if (result !== undefined) {
				return result;
			}
			
			if (deep) {
				for each (var pkg :Package in _imports) {
					result = pkg.find(name, deep);
					if (result !== undefined) {
						return result;
					}
				}
			}
			
			return undefined;
		}
		
		/** 
		 * Interns the given name. If a symbol with this name already exists, it is returned.
		 * Otherwise a new symbol is created, added to internal storage, and returned.
		 */
		public function intern (name :String) :Symbol {
			var result :Symbol = _symbols[name] as Symbol;
			if (result == null) {
				result = _symbols[name] = new Symbol(name, this);
			}
			return result;
		}
		
		/** 
		 * Uninterns the given symbol. If a symbol existed with this name, it will be removed,
		 * and the function returns true; otherwise returns false.
		 */
		public function unintern (symbol :Symbol) :Boolean {
			if (_symbols[symbol.name] != null) {
				delete _symbols[symbol.name];
				return true;
			} else {
				return false;
			}
		}
		
		/** Retrieves the binding for the given symbol, also traversing the import list. */
		public function getBinding (symbol :Symbol) :* {
			if (symbol.pkg != this) {
				throw new LanguageError("Unexpected package in getBinding: " + symbol.pkg.name);
			}

			var val :* = _bindings[symbol];
			if (val !== undefined) {
				return val;
			}
			
			// try imports
			for each (var pkg :Package in _imports) {
				var local :Symbol = pkg.find(symbol.name, false);
				if (local != null && local.exported) {
					val = pkg._bindings[local];
					if (val !== undefined) {
						return val;
					}
				}
			}
			
			return undefined;
		}
		
		/** Sets the binding for the given symbol. If null, deletes the binding. */
		public function setBinding (symbol :Symbol, value :*) :void {
			if (symbol.pkg != this) {
				throw new LanguageError("Unexpected package in setBinding: " + symbol.pkg.name);
			}
			
			if (value == null) {
				delete _bindings[symbol];
			} else {
				_bindings[symbol] = value;
			}
		}
		
		/** Returns true if this package contains the named macro */
		public function hasMacro (symbol :Symbol) :Boolean {
			return getMacro(symbol) != null;
		}
		
		/** Retrieves the macro for the given symbol, potentially null */
		public function getMacro (symbol :Symbol) :Macro {
			if (symbol.pkg != this) {
				throw new LanguageError("Unexpected package in getBinding: " + symbol.pkg.name);
			}

			var val :* = _macros[symbol];
			if (val !== undefined) {
				return val;
			}

			// try imports
			for each (var pkg :Package in _imports) {
				var s :Symbol = pkg.find(symbol.name, false);
				if (s != null && s.exported) {
					val = pkg._macros[s];
					if (val !== undefined) {
						return val;
					}
				}
			}

			return undefined;
		}
		
		/** Sets the macro for the given symbol. If null, deletes the macro. */
		public function setMacro (symbol :Symbol, value :Macro) :void {
			if (symbol.pkg != this) {
				throw new LanguageError("setMacro called with invalid package");
			}
			
			if (value == null) {
				delete _macros[symbol];
			} else {
				_macros[symbol] = value;
			}
		}

		/** Adds a new import */
		public function addImport (pkg :Package) :void {
			if (pkg == this) {
				throw new LanguageError("Package cannot import itself!");
			}
			
			if (_imports.indexOf(pkg) == -1) {
				_imports.push(pkg);
			}
		}
		
		/** Returns the vector of imports. NOTE: do not modify! */
		public function get imports () :Vector.<Package> {
			return _imports;
		}
		
		/** Returns a new vector of all symbols interned in this package */
		public function listExports () :Array {
			var results :Array = [];
			for each (var sym :Symbol in _symbols) {
				if (sym.exported) {
					results.push(sym);
				}
			}
			return results;
		}
	}

}