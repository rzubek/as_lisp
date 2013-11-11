package as_lisp.util
{
	/**
	 * Simple stream-like wrapper, into which we can add strings, and then peek or pop characters.
	 */
	public class Stream 
	{
		/** Internal string storage */
		private var _buffer :String;
		
		/** Current position in the buffer */
		private var _index :uint;
		
		/** Optional saved state */
		private var _saved :StreamState;
		
		public function Stream() 
		{
			_buffer = "";
		}
		
		/** Appends more data to the stream */
		public function add (str :String) :void {
			_buffer += str;
		}
		
		/** Returns true if empty, false if we still have characters in the buffer */
		public function get isEmpty () :Boolean {
			return _index >= _buffer.length;
		}
		
		/** Returns the current character in the stream without removing it; null if empty. */
		public function peek () :String {
			return (_index >= _buffer.length) ? null : _buffer.charAt(_index);
		}
		
		/** Returns and removes the current character in the stream; null if empty. */
		public function read () :String {
			var result :String = null;
			if (_index < _buffer.length) {
				result = _buffer.charAt(_index);
				_index++;
			}
			// if we reached end of the buffer, clear out internal storage
			if (_index >= _buffer.length && _index > 0) {
				_buffer = "";
				_index = 0;
			}
			return result;
		}
		
		/** Saves the state of the stream into an internal register. Each save overwrites the previous one. */
		public function save () :void {
			_saved = new StreamState(this._buffer, this._index);
		}
		
		/** 
		 * Restores (and deletes) a saved stream state, and returns true. 
		 * If one did not exist, it does not change existing state, and returns false.
		 */
		public function restore () :Boolean {
			if (_saved == null) {
				return false;
			}
			
			this._index = _saved.index;
			this._buffer = _saved.buffer;
			this._saved = null;
			return true;
		}
	}
}

internal class StreamState {
	public var index :int;
	public var buffer :String;
	public function StreamState (buffer :String, index :int) {
		this.index = index;
		this.buffer = buffer;
	}
}