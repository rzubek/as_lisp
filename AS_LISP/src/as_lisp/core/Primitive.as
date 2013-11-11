package as_lisp.core 
{
	import as_lisp.util.Context;
	
	/**
	 * Built-in primitive functions, which all live in the core package.
	 */
	public class Primitive 
	{
		public var name :String;
		public var minargs :uint;
		public var maxargs :uint;
		public var fn :Function;
		public var alwaysNotNull :Boolean;
		public var hasSideEffects :Boolean;
		
		public function Primitive (name :String, minargs :uint, maxargs :uint, fn :Function, alwaysNotNull :Boolean = false, hasSideEffects :Boolean = false) 
		{
			this.name = name;
			this.minargs = minargs;
			this.maxargs = maxargs;
			this.fn = fn;
			this.alwaysNotNull = alwaysNotNull;
			this.hasSideEffects = hasSideEffects;
		}
		
		/** Calls the primitive function with argn operands from the stack */
		public function applySelf (ctx :Context, argn :int, stack :Array) :* {
			var first :*, second :*, third :*;
			switch (argn) {
				case 0: 
					return fn(ctx);
				case 1:
					first = stack.pop();
					return fn(ctx, first);
				case 2:
					second = stack.pop();
					first = stack.pop();
					return fn(ctx, first, second);
				default:
					var args :Array = [ctx].concat(stack.splice(stack.length - argn, argn));
					return fn.apply(null, args);
			}
		}
	}

}