package as_lisp.error 
{
	/**
	 * Class for errors related to the language engine, not specific to a particular pass.
	 */
	public class LanguageError extends Error
	{
		public function LanguageError (message :String) {
			super(message);
		}
	}

}