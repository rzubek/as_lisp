package as_lisp.libs 
{
	import as_lisp.data.Closure;
	import as_lisp.core.Parser;
	import as_lisp.util.Context;
	import flash.utils.ByteArray;

	/**
	 * Manages standard libraries
	 */
	public class Libraries 
	{
		[Embed(source="core.txt",mimeType="application/octet-stream")]
		private static const CORE :Class;
		
		[Embed(source="final.txt",mimeType="application/octet-stream")]
		private static const FINAL :Class;

		/** All libraries as a list */
		private static const ALL_LIBS :Vector.<Class> = new <Class> [ 
			CORE,
			FINAL 
			];
		
		/** Loads all standard libraries into an initialized machine instance */
		public static function loadStandardLibraries (ctx :Context) :void {
			for each (var lib :Class in ALL_LIBS) {
				var libBytes :ByteArray = new lib() as ByteArray;
				var libText :String = libBytes.toString();
				loadLibrary(ctx, libText);
			}
		}
		
		/** Loads a single string into the execution context */
		private static function loadLibrary (ctx :Context, lib :String) :void {
			ctx.parser.addString(lib);
			var result :* = null;
			while ((result = ctx.parser.parseNext()) != Parser.EOF) {
				var cl :Closure = ctx.compiler.compile(result);
				var output :* = ctx.vm.run(cl);
				// and we drop the output on the floor... for now... :)
			}
		}
		
	}

}