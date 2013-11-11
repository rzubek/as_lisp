package as_lisp.data 
{
	/**
	 * Immutable symbol, interned in a specific package.
	 * Interned symbols are unique, so we can test for equality using simple ==
	 */
	public class Symbol 
	{
		/** String name of this symbol */
		private var _name :String;
		
		/** Package in this symbol is interned */
		private var _pkg :Package;

		/** Full (package-prefixed) name of this symbol */
		private var _fullName :String;

		/** If true, this symbol is visible outside of its package. This can be adjusted later. */
		public var exported :Boolean = false;
		
		public function Symbol (name :String, pkg :Package) {
			_name = name;
			_pkg = pkg;
			
			_fullName = (_pkg != null && _pkg.name != null) ? (_pkg.name + ":" + _name) : _name;
		}
		
		/** String name of this symbol */
		public function get name () :String { return _name; }
		
		/** Package in which this symbol is interned */
		public function get pkg () :Package { return _pkg; }
		
		/** Returns the full name, including package prefix */
		public function get fullName () :String { return _fullName; }
		
		/** @inheritDoc */
		public function toString () :String {
			return "[Symbol " + fullName + "]";
		}
	}

}