package as_lisp.data 
{
	import as_lisp.error.LanguageError;
	
	/**
	 * Auxiliary functions for converting data types to human-readable representation
	 */
	public class Printer 
	{
		/** Converts the given value to a string */
		public static function toString (value :*) :String {
			if (value === null) {
				return "()";
			} else if (value is Symbol) {
				return (value as Symbol).fullName;
			} else if (value is Number) {
				return String(value);
			} else if (value is String) {
				return "\"" + value + "\"";
			} else if (value is Boolean) {
				return (value ? "#t" : "#f");
			} else if (value is Cons) {
				return stringifyCons(value as Cons);
			} else if (value is Closure) {
				return "[Closure]";
			} else if (value === undefined) {
				return "[Undefined]";
			} else if (value is Object) {
				return "[Native: " + value.toString() + "]";
			} else {
				throw new LanguageError("Don't know how to print: " + value);
			}
		}
		
		/** Helper function for cons cells */
		private static function stringifyCons (cell :Cons) :String 
		{
			var str :String = "(";
			var val :* = cell;
			while (val != null) {
				var cons :Cons = val as Cons;
				if (cons != null) {
					str += toString(cons.car);
					if (cons.cdr != null) {
						str += " ";
					}
					val = cons.cdr;
				} else {
					str += (". " + toString(val));
					val = null;
				}
			}
			
			str += ")";
			return str;
		}
	}

}