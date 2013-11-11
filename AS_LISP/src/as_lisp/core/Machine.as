package as_lisp.core 
{
	import as_lisp.data.Closure;
	import as_lisp.data.Cons;
	import as_lisp.data.Environment;
	import as_lisp.data.Instruction;
	import as_lisp.data.Symbol;
	import as_lisp.error.LanguageError;
	import as_lisp.util.Context;

	/**
	 * Virtual machine that will interpret compiled bytecode
	 */
	public class Machine 
	{
		/** If set, instructions will be logged to this function as they're executed. */
		public var debugInstructionLogger :Function = null;
		
		/** Internal execution context */
		private var _ctx :Context = null;
		
		/** Maps from instruction enum to a function that runs the body of this instruction */
		private var _ops :Vector.<Function> = new Vector.<Function>(Instruction.TYPE_COUNT);
		
		public function Machine (ctx :Context) 
		{
			_ctx = ctx;
		}
		
		/** Runs the given piece of code, and returns the value left at the top of the stack. */
		public function run (fn :Closure, ... args) :* {
			var i :Instruction = null;
			var value :*;
			var symbol :Symbol;

			var st :State = new State();
			st.fn = fn;
			st.code = fn.instructions;
			st.env = fn.env;
			for each (var arg :* in args) {
				st.stack.push(arg);
			}
			st.nargs = args.length;
			
			while (! st.done) {
				if (st.pc >= st.code.length) {
					throw new LanguageError("Runaway opcodes!");
				}
				
				// fetch instruction
				i = st.code[st.pc];
				st.pc ++;
				
				if (debugInstructionLogger != null) {
					debugInstructionLogger(st.stack.length, "] ", st.pc, ":", Instruction.printInstruction(i));
				}

				// and now a big old switch statement. not handler functions - this is much, much faster,
				// especially now that the new AS compiler knows how to optimize switch statements into jumps
				switch (i.type) {
					case Instruction.LABEL: 
						// no op :)
						break;
					case Instruction.CONST:
						st.stack.push(i.first);
						break;
					case Instruction.LVAR:
						st.stack.push(Environment.getValueAt(i.first, i.second, st.env));
						break;
					case Instruction.LSET:
						value = st.stack[st.stack.length - 1];
						Environment.setValueAt(i.first, i.second, value, st.env);
						break;
					case Instruction.GVAR:
						symbol = i.first as Symbol;
						value = symbol.pkg.getBinding(symbol);
						st.stack.push(value);
						break;
					case Instruction.GSET:
						symbol = i.first as Symbol;
						value = st.stack[st.stack.length - 1];
						symbol.pkg.setBinding(symbol, value);
						break;
					case Instruction.POP:
						st.stack.pop();
						break;
					case Instruction.TJUMP:
						value = st.stack.pop();
						if (value) {
							st.pc = getLabelPosition(i, st);
						}
						break;
					case Instruction.FJUMP:
						value = st.stack.pop();
						if (! value) {
							st.pc = getLabelPosition(i, st);
						}
						break;
					case Instruction.JUMP:
						st.pc = getLabelPosition(i, st);
						break;
					case Instruction.ARGS:
						if (st.nargs != i.first) { throw new LanguageError("Argument count error, expected " + i.first + ", got " + st.nargs); }
						st.env = new Environment(st.nargs, st.env);
						for (var ii :int = i.first - 1; ii >= 0; ii--) {
							st.env.setValue(ii, st.stack.pop());
						}
						break;
					case Instruction.ARGSDOT:
						if (st.nargs < i.first) { throw new LanguageError("Argument count error, expected " + i.first + " or more, got " + st.nargs); }
						var argc :int = st.nargs - i.first;
						st.env = new Environment(i.first + 1, st.env);
						for (var cc :int = argc - 1; cc >= 0; cc--) {
							var arg1 :* = st.stack.pop();
							st.env.setValue(i.first, new Cons(arg1, st.env.getValue(i.first)));
						}
						for (var iii :int = i.first - 1; iii >= 0; iii--) {
							st.env.setValue(iii, st.stack.pop());
						}
						break;
					case Instruction.DUPE:
						if (st.stack.length == 0) {
							throw new LanguageError("Cannot duplicate on an empty stack!");
						}
						st.stack.push(st.stack[st.stack.length - 1]);
						break;
					case Instruction.CALLJ:
						st.env = st.env.parent; // discard the top frame
						var top :* = st.stack.pop();
						var closure :Closure = top as Closure;
						if (closure == null) {
							throw new LanguageError("Unknown function during function call!");
						}
						st.fn = closure;
						st.code = closure.instructions;
						st.env = closure.env;
						st.pc = 0;
						st.nargs = i.first;
						break;
					case Instruction.SAVE:
						st.stack.push(new ReturnAddress(st.fn, getLabelPosition(i, st), st.env));
						break;
					case Instruction.RETURN:
						// we'll deal with this more properly later
						if (st.stack.length > 1) {
							var retval :* = st.stack.pop();
							var retaddr :ReturnAddress = st.stack.pop();
							st.stack.push(retval);
							st.fn = retaddr.fn;
							st.code = retaddr.fn.instructions;
							st.env = retaddr.env;
							st.pc = retaddr.pc;
						} else {
							st.done = true;	// this will force the virtual machine to finish up
						}
						break;
					case Instruction.FN:
						st.stack.push(new Closure((i.first as Closure).instructions, st.env, null));
						break;
					case Instruction.PRIM:
						var argn :int = i.second is Number ? i.second : st.nargs;
						var prim :Primitive = Primitives.findNary(i.first, argn);
						if (prim == null) {
							throw new LanguageError("Invalid argument count to primitive " + i.first + ", count of " + argn);
						} 
						var result :* = prim.applySelf(this._ctx, argn, st.stack);
						st.stack.push(result);
						break;
					default:
						throw new LanguageError("Unknown instruction type: " + i.type);
						break;
				}
			}
			
			// return whatever's on the top of the stack
			if (st.stack.length == 0) {
				throw new LanguageError("Stack underflow!"); 
			} 
			
			return st.stack[st.stack.length - 1];
		}
		
		/** Very naive helper function, finds the position of a given label in the instruction set */
		private function getLabelPosition (inst :Instruction, st :State) :uint {
			if (inst.second != null) {
				return uint(inst.second);
			} else {
				throw new LanguageError("Unknown jump label: " + inst.first);
			}
		}
	}

}
