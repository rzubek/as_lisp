package as_lisp.data 
{
	import flash.utils.Dictionary;
	
	/**
	 * Packages class contains static functions for managing the list of packages defined by the runtime.
	 */
	public class Packages 
	{
		/** Global package, unnamed */
		public static const NAME_GLOBAL :String = null;
		
		/** Special keywords package */
		public static const NAME_KEYWORDS :String = "";
		
		/** Core package with all the built-in primitives */
		public static const NAME_CORE :String = "core";

		/** Dictionary of packages, keyed by package name */
		private static var _packages :Dictionary = new Dictionary();
		
		{
			_packages[NAME_GLOBAL] = new Package(NAME_GLOBAL);
			_packages[NAME_KEYWORDS] = new Package(NAME_KEYWORDS);
			_packages[NAME_CORE] = new Package(NAME_CORE);
			
			(_packages[NAME_GLOBAL] as Package).addImport(_packages[NAME_CORE]);
		}
		
		/** Helper function, returns the global package */
		public static function get global () :Package {
			return find(NAME_GLOBAL);
		}
		
		/** Helper function, returns the keywords package */
		public static function get keywords () :Package {
			return find(NAME_KEYWORDS);
		}

		/** Helper function, returns the core package with all primitives */
		public static function get core () :Package {
			return find(NAME_CORE);
		}

		/** Finds a package by name (creating a new one if necessary) and returns it */
		public static function intern (name :String) :Package {
			var pkg :Package = _packages[name];
			if (pkg == null) {
				pkg = _packages[name] = new Package(name);
				pkg.addImport(Packages.core); // every package imports core
			}
			return pkg;
		}
		
		/** Gets a package by name, if it exists, but does not intern it */
		public static function find (name :String) :Package {
			return _packages[name];
		}
		
		/** Adds a new package */
		public static function add (pkg :Package) :void {
			_packages[pkg.name] = pkg;
		}
		
		/** Removes the package and returns true if successful. */
		public static function remove (pkg :Package) :Boolean {
			if (_packages[pkg.name] != null) {
				delete _packages[pkg.name];
				return true;
			} else {
				return false;
			}
		}
	}

}