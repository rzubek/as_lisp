package as_lisp.util 
{
	import as_lisp.core.Compiler;
	import as_lisp.core.Machine;
	import as_lisp.core.Parser;
	import as_lisp.core.Primitives;
	import as_lisp.data.Closure;
	import as_lisp.data.Packages;
	import as_lisp.libs.Libraries;
	
	/**
	 * Binds together an instance of a compiler, parser, and executor.
	 */
	public class Context 
	{
		public var parser :Parser;
		public var compiler :Compiler;
		public var vm :Machine;
		
		public function Context (logger :Function, initialize :Boolean) 
		{
			this.parser = new Parser(this);
			this.compiler = new Compiler(this);
			this.vm = new Machine(this);
			
			// vm.debugInstructionLogger = logger;
			
			Primitives.initialize(Packages.core);
			
			if (initialize) {
				Libraries.loadStandardLibraries(this); 
			}

			vm.debugInstructionLogger = logger;
		}
		
		/** Processes the input as a string, and returns an array of results */
		public function execute (input :String) :Array {
			var outputs :Array = [];
			
			parser.addString(input);
			var parseResults :Array = parser.parseAll();
				
			for each (var result :* in parseResults) {
				var cl :Closure = compiler.compile(result);
				var output :* = vm.run(cl);
				outputs.push(output);
			}

			return outputs;
		}
	}

}