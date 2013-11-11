package as_lisp.data 
{
	import as_lisp.error.LanguageError;
	
	/**
	 * An Environment instance binds variables to their values.
	 * Variable names are for compilation only - they're not used at runtime
	 * (except for debugging help).
	 */
	public class Environment 
	{
		/** Parent environment */
		private var _parent :Environment;
		
		/** Symbols defined in this environment */
		private var _symbols :Vector.<Symbol>;
		
		/** Values defined for each symbol */
		private var _values :Vector.<*>;
		
		public function Environment (count :uint, parent :Environment) {
			_symbols = new Vector.<Symbol>(count);
			_values = new Vector.<*>(count);
			_parent = parent;
		}

		/** Creates a new environment from a cons'd list */
		public static function prepend (list :Cons, parent :Environment) :Environment {
			var count :int = Cons.length(list);
			var env :Environment = new Environment(count, parent);
			
			var i :int = 0;
			while (i < count) {
				env.setSymbol(i, list.car as Symbol);
				env.setValue(i, null);
				list = list.cdr;
				i++;
			}
			
			return env;
		}
		
		/** Parent environment */
		public function get parent () :Environment {
			return _parent;
		}

		/** Retrieves symbol at the given index */
		public function getSymbol (i :uint) :Symbol {
			return _symbols[i];
		}
		
		/** Sets symbol at the given index */
		private function setSymbol (i :uint, symbol :Symbol) :void {
			_symbols[i] = symbol;
		}
		
		/** Retrieves value at the given index */
		public function getValue (i :uint) :* {
			return _values[i];
		}
		
		/** Sets value at the given index */
		public function setValue (i :uint, value :*) :void {
			_values[i] = value;
		}
		
		/** Returns the number of slots defined in this environment */
		public function get length () :uint {
			return _symbols.length;
		}
		
		/** 
		 * Returns coordinates of a symbol, relative to the given environment, or null if not present.
		 * First element of the vector is the index of the environment, in the chain,
		 * and the second element is the index of the variable itself. 
		 */
		public static function getLocation (symbol :Symbol, frame :Environment) :Vector.<uint> {
			var frameIndex :uint = 0;
			while (frame != null) {
				var symbolIndex :int = frame._symbols.indexOf(symbol);
				if (symbolIndex >= 0) {
					return new <uint> [ frameIndex, symbolIndex ];
				} else {
					frame = frame._parent;
					frameIndex ++;
				}
			}
			return null;
		}
		
		/** Retrieves the symbol at the given coordinates, relative to the current environment. */
		public static function getSymbolAt (frameIndex :uint, symbolIndex :uint, frame :Environment) :Symbol {
			return getFrame(frameIndex, frame).getSymbol(symbolIndex);
		}
		
		/** Sets the symbol at the given coordinates, relative to the current environment. */
		public static function setSymbolAt (frameIndex :uint, symbolIndex :uint, symbol :Symbol, frame :Environment) :void {
			return getFrame(frameIndex, frame).setSymbol(symbolIndex, symbol);
		}

		/** Retrieves the value at the given coordinates, relative to the current environment. */
		public static function getValueAt (frameIndex :uint, symbolIndex :uint, frame :Environment) :* {
			return getFrame(frameIndex, frame).getValue(symbolIndex);
		}
		
		/** Sets the value at the given coordinates, relative to the current environment. */
		public static function setValueAt (frameIndex :uint, symbolIndex :uint, value :*, frame :Environment) :void {
			return getFrame(frameIndex, frame).setValue(symbolIndex, value);
		}

		/** Returns the specified frame, relative to the current environment */
		private static function getFrame (frameIndex :uint, frame :Environment) :Environment {
			for (var i :int = 0; i < frameIndex; i++) {
				frame = frame._parent;
				if (frame == null) {
					throw new LanguageError("Invalid frame coordinates detected");
				}
			}
			return frame;
		}
	}

}