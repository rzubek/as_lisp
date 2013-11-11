package as_lisp.data 
{
	/**
	 * Encapsulates a macro and code that runs to expand it.
	 */
	public class Macro 
	{
		public var debugname :String;
		
		public var args :Cons;
		public var body :Closure;
		
		public function Macro (name :Symbol, args :Cons, body :Closure) 
		{
			this.debugname = name.name;
			this.args = args;
			this.body = body;
		}
	}

}