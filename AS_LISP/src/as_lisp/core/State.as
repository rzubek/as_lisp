package as_lisp.core
{
	import as_lisp.data.Closure;
	import as_lisp.data.Environment;
	import as_lisp.data.Instruction;

	internal class State {
		/** Array of instructions we're executing */
		public var code :Vector.<Instruction> = null;
		/** Reference back to the closure in which these instructions live */
		public var fn :Closure = null;
		/** Program counter; index into the code array */
		public var pc :uint = 0;
		/** Reference to the current environment (head of the chain of environments) */
		public var env :Environment = null;
		/** Stack of heterogeneous values (numbers, symbols, strings, closures, etc) */
		public var stack :Array = [];
		/** Argument count register, used when calling functions */
		public var nargs :uint = 0;
		/** Helper flag, stops the REPL */
		public var done :Boolean = false;
	}
}