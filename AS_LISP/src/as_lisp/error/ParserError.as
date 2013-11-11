package as_lisp.error 
{
	/**
	 * Class for errors encountered during the parsing phase
	 */
	public class ParserError extends Error
	{
		public function ParserError (message :String) {
			super(message);
		}
	}

}