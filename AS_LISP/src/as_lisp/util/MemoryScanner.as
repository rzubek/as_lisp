package as_lisp.util 
{
	import flash.sampler.DeleteObjectSample;
	import flash.sampler.NewObjectSample;
	import flash.sampler.clearSamples;
	import flash.sampler.getSamples;
	import flash.sampler.pauseSampling;
	import flash.sampler.setSamplerCallback;
	import flash.sampler.startSampling;
	import flash.sampler.stopSampling;
	import flash.system.System;
	
	/**
	 * Tracks memory allocation / deallocation between two points in time, 
	 * and prints out information about leaks
	 */
	public class MemoryScanner 
	{
		/** If true, a run has been started, and not yet finished. */
		private var _running :Boolean = false;
		
		/** Number of objects allocated during the last run */
		public var newCount :int;
		
		/** Number of objects deleted during the last run */
		public var deleteCount :int;
		
		/** Total deletion size from the last run, in bytes */
		public var deleteSize :int;
		
		/** Number of objects allocated but not garbage collected during the last run */
		public var leakedCount :int;
		
		/** Total leakage size from the last run, in bytes */
		public var leakedSize :int;
		
		/** Internal storage for deleted objects */
		private var _deleted :Vector.<DeleteObjectSample> = new Vector.<DeleteObjectSample>();
		
		/** Internal storage for leaked objects */
		private var _leaked :Vector.<NewObjectSample> = new Vector.<NewObjectSample>();
		
		/** Last message */
		private var _lastMessage :String;
		
		public function MemoryScanner() {
			setSamplerCallback(samplerCallback);
		}
		
		/** True if a run has been started, and not yet finished. */
		public function get isRunning () :Boolean {
			return _running;
		}
		
		/** Returns the last message from the memory scanner */
		public function get lastMessage () :String {
			return _lastMessage;
		}

		/** Starts or stops the run */
		public function toggle () :void {
			_lastMessage = ("memory scanner: " + (_running ? "off\n" : "on\n"));
			toggleHelper(! _running);
		}
		
		/** Starts or stops the scan. It's incorrect and undefined to start a running one, or stop a stopped one. */
		private function toggleHelper (start :Boolean) :void {
			// two gc's are better than one? :)
			System.gc();
			System.gc();
			
			if (start) {
				clearSamples();
				startSampling();
			} else {
				pauseSampling();
				samplerCallback();
				stopSampling();
				clearSamples();
			}
			
			_running = start;
		}
		
		private function samplerCallback (... args) :void {
			var samples :* = getSamples();

			newCount = 0;
			deleteCount = 0;
			deleteSize = 0;
			leakedCount = 0;
			leakedSize = 0;
			
			_leaked.length = 0;
			_deleted.length = 0;
			
			for each (var sample :* in samples) {
				if (sample is NewObjectSample) {
					newCount++;
					if (sample.object) {
						leakedCount++;
						leakedSize += sample.size;
						_leaked.push(sample);
					}
				} else if (sample is DeleteObjectSample) {
					deleteCount++;
					deleteSize += sample.size;
					_deleted.push(sample);
				} else {
					// trace("sample: " + sample);
				}
			}
			
			// see what remains

			_lastMessage += ("alloc'd " + newCount + " objects\n");
			_lastMessage += ("deleted " + deleteCount + " objects, " + deleteSize + " bytes\n");
			_lastMessage += ("unclaimed " + (newCount - deleteCount) + " objects, " + leakedSize + " bytes\n");
			for each (var leaked :NewObjectSample in _leaked) {
				try {
					var desc :String = String(leaked.object);
				} catch (e:Error) {
					desc = e.message;
				}
				_lastMessage += ("leaked " + leaked.size + " b : " + desc + "\n"); 
			}
		}
		
		
	}

}