package as_lisp.error 
{
	/**
	 * Class for errors thrown during the compilation phase 
	 */
	public class CompilerError extends Error
	{
		public function CompilerError (message :String) {
			super(message);
		}
	}

}