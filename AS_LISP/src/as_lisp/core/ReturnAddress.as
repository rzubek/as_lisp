package as_lisp.core
{
	import as_lisp.data.Closure;
	import as_lisp.data.Environment;

	internal class ReturnAddress {
		public var fn :Closure;
		public var pc :uint;
		public var env :Environment;
		public function ReturnAddress (fn :Closure, pc :uint, env :Environment) {
			this.fn = fn;
			this.pc = pc;
			this.env = env;
		}
	}
}