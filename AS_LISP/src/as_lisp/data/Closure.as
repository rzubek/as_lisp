package as_lisp.data 
{
	/**
	 * Encapsulates everything needed for a function call
	 */
	public class Closure 
	{
		/** Compiled sequence of instructions */
		public var instructions :Vector.<Instruction>;
		
		/** Environment in which we're running */
		public var env :Environment;
		
		/** List of arguments this function expects */
		public var args :Cons;
		
		/** Optional closure name, for debugging purposes only */
		public var name :String;
		
		public function Closure (instructions :Vector.<Instruction>, env :Environment, args :Cons, name :String = null) 
		{
			this.instructions = instructions;
			this.env = env;
			this.args = args;
			this.name = name;
		}
	}

}