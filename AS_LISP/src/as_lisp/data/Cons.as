package as_lisp.data 
{
	import as_lisp.error.LanguageError;

	/**
	 * Cons cell, contains car and cdr elements.
	 */
	public class Cons
	{
		/** First value of this cons cell */
		public var car :*;
		
		/** Second value of this cons cell */
		public var cdr :*;
		
		public function Cons (car :* = null, cdr :* = null) {
			this.car = car;
			this.cdr = cdr;
		}

		/** Shorthand for the second element of the list */
		public function get cadr () :* {
			return (cdr as Cons).car;
		}
		
		/** Shorthand for the third element of the list */
		public function get caddr () :* {
			return (cddr as Cons).car;
		}

		/** Shorthand for the sublist after the second element (so third element and beyond) */
		public function get cddr () :* {
			return (cdr as Cons).cdr;
		}
		
		/** Shorthand for the sublist after the third element (so fourth element and beyond) */
		public function get cdddr () :* {
			return (cddr as Cons).cdr;
		}

		/** 
		 * Helper function: converts an array of arguments to a cons list.
		 * Whether it's null-terminated or not depends on the existence of a "." in the penultimate position.
		 */
		public static function make (... values) :* {
			var len :uint = values.length;
			var dotted :Boolean = (len >= 3 && values[len - 2] is Symbol && (values[len - 2] as Symbol).fullName == ".");
			
			// the tail should be either the last value, or a cons containing the last value
			var result :* = 
				dotted ? values[len - 1] 
					: (len >= 1 ? new Cons(values[len - 1], null) : null);
			var iterlen :uint = dotted ? len - 3 : len - 2;
			for (var i :int = iterlen; i >= 0; i--) {
				result = new Cons(values[i], result);
			}
			return result;
		}
		
		/** 
		 * Helper function: converts a cons list into an array 
		 */
		public static function toArray (cons :*) :Array {
			var results :Array = [];
			while (cons != null) {
				if (! (cons is Cons)) {
					throw new LanguageError("Only null-terminated lists can be converted to arrays!");
				}
				results.push(cons.car);
				cons = cons.cdr;
			}
			return results;
		}

		/** Returns true if the value is null */
		public static function isNull (value :*) :Boolean {
			return value == null;
		}
		
		/** Returns true if the value is a cons */
		public static function isCons (value :*) :Boolean {
			return value is Cons;
		}
		
		/** Returns true if the value is an atom, not a cons */
		public static function isAtom (value :*) :Boolean {
			return ! isCons(value);
		}
		
		/** Returns true if the value is a properly nil-terminated cons list */
		public static function isList (value :*) :Boolean {
			if (value == null) {
				return true;
			}
			var cons :Cons = value as Cons;
			while (cons != null) {
				if (cons.cdr == null) {
					return true; // found our terminating null
				}
				cons = (cons.cdr as Cons);
			}
			return false;
		}
		
		/** Returns the number of cons cells in the list, starting at value. O(n) operation. */
		public static function length (value :*) :int {
			var result :int = 0;
			while (value is Cons) {
				result++;
				value = (value as Cons).cdr;
			}
			return result;
		}
	}
}