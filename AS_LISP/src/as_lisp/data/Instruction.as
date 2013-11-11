package as_lisp.data 
{
	/**
	 * Enum of instructions produced by the compiler
	 */
	public class Instruction 
	{
		// instructions that control vm logic
		
		/** Just a label, doesn't do anything */
		public static const LABEL :int = 0;
		/** CONST x - pushes x onto the stack */
		public static const CONST :int = 1;
		/** LVAR i, j - push local variable onto the stack */
		public static const LVAR :int = 2;
		/** LSET i, j - set local variable from what's on top of the stack */
		public static const LSET :int = 3;
		/** GVAR x - push global variable onto the stack */
		public static const GVAR :int = 4;
		/** GSET x - set global variable from what's on top of the stack */
		public static const GSET :int = 5;
		/** POP - pops the top value from the stack */
		public static const POP :int = 6;
		/** TJUMP l - jump to l and pop stack if top of stack is true */
		public static const TJUMP :int = 7;
		/** FJUMP l - jump to l and pop stack if top of stack is not true */
		public static const FJUMP :int = 8;
		/** JUMP l - jump to l without modifying or looking up the stack */
		public static const JUMP :int = 9;
		/** ARGS n - make a new frame, move n values from stack onto it, and push on the env list */
		public static const ARGS :int = 10;
		/** ARGSDOT n - make a new frame with n-1 entries and one for varargs, move values from stack onto it, and push on the env list */
		public static const ARGSDOT :int = 11;
		/** DUP - duplicates (pushes a second reference to) the topmost value on the stack */
		public static const DUPE :int = 12;
		/** CALLJ n - go to the function on top of the stack, not saving return point; n is arg count */
		public static const CALLJ :int = 13;
		/** Save continuation point on the stack */
		public static const SAVE :int = 14;
		/** RETURN - return to the return point (second on the stack) */
		public static const RETURN :int = 15;
		/** FN fn - create a closure fn from arguments and current environment, and push onto the stack */
		public static const FN :int = 16;
		/** PRIM name - performs a primitive function call right off of the stack, and stores return on the stack */
		public static const PRIM :int = 17;
		// more here...
		// finally:
		public static const TYPE_COUNT :int = 18;

		/** Array of human readable names for all constants */
		private static const _NAMES :Vector.<String> = new <String> [
			"LABEL", "CONST", "LVAR", "LSET", "GVAR", 
			"GSET", "POP", "TJUMP", "FJUMP", "JUMP",
			"ARGS", "ARGSDOT", "DUP", "CALLJ", "SAVE", 
			"RETURN", "FN", "PRIM"
			];
			
		{
			if (_NAMES.length != TYPE_COUNT) {
				throw new Error("Invalid Instruction type count!");
			}
		}
		
		/** Instruction type, one of the constants in this class */
		private var _type :int;
		
		/** First instruction parameter (context-sensitive) */
		private var _first :*;
		
		/** Second instruction parameter (context-sensitive) */
		private var _second :*;
		
		/** Debug information (printed to the user as needed) */
		private var _debug :String;
		
		public function Instruction (type :int, first :*, second :*, debug :String) {
			_type = type;
			_first = first;
			_second = second;
			_debug = debug;
		}
		
		/** Instruction type, one of the constants in this class */
		public function get type () :int { return _type; }
		
		/** First instruction parameter (context-sensitive) */
		public function get first () :* { return _first; }
		
		/** Second instruction parameter (context-sensitive) */
		public function get second () :* { return _second; }
		
		/** Debug information (printed to the user as needed) */
		public function get debug () :String { return _debug; }

		/** Converts an instruction to a string */
		public static function printInstruction (instruction :Instruction) :String {
			var str :String = _NAMES[instruction.type];
			if (instruction._first != null) {
				str = str.concat("\t", Printer.toString(instruction._first));
			}
			if (instruction._second != null) {
				str = str.concat("\t", Printer.toString(instruction._second));
			}
			if (instruction._debug != null) {
				str = str.concat("\t; ", instruction._debug);
			}
			return str;
		}
		
		/** Converts a set of instructions to a string */
		public static function printInstructions (instructions :Vector.<Instruction>, indentLevel :int = 1) :String {
			var str :String = "";
			for each (var instruction :Instruction in instructions) {

				// tab out and print current instruction
				var tabs :int = indentLevel + (instruction.type == Instruction.LABEL ? -1 : 0);
				for (var tt :int = 0; tt < tabs; tt++) {
					str = str.concat("\t");
				}
				str = str.concat(printInstruction(instruction), "\n");

				if (instruction.type == FN) {
					// if function, recurse
					var closure :Closure = instruction.first as Closure;
					str = str.concat(printInstructions(closure.instructions, indentLevel + 1));
				}
			}
			return str;
		}

		/** Returns true if two instructions are equal */
		public static function equal (a :Instruction, b :Instruction) :Boolean {
			return a.type == b.type &&
				a.first == b.first &&
				a.second == b.second;
		}
	}

}