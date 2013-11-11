package as_lisp
{
	import flash.display.Sprite;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.events.Event;
	import flash.utils.setInterval;
	
	import as_lisp.test.Test;
	import as_lisp.util.Context;
	
	/**
	 * Console and REPL demo
	 */
	[SWF(width="800", height="600")]
	public class Main extends Sprite 
	{
		// Should we run unit and integration tests at startup?
		private const RUN_TESTS :Boolean = true;
		
		private var _ctx :Context;
		private var _console :Console;
		
		public function Main () :void 
		{
			if (stage) { init (); }
			else { addEventListener(Event.ADDED_TO_STAGE, init); }
		}
		
		private function init (... args) :void 
		{
			removeEventListener(Event.ADDED_TO_STAGE, init);
			
			stage.align = StageAlign.TOP_LEFT;
			stage.scaleMode = StageScaleMode.NO_SCALE;
			stage.addEventListener(Event.RESIZE, resize);
			
			start();
			var interval :uint = setInterval(function () :void {
				resize(null);
			}, 0);
		}
		
		private function resize (event :Event) :void {
			if (stage.width != stage.stageWidth || stage.height != stage.stageHeight) {
				// trace(stage.width, stage.height, stage.stageWidth, stage.stageHeight);
				if (_console != null) {
					_console.resize(stage.stageWidth, stage.stageHeight);
				}
			}
		}
		
		private function start () :void {
			if (RUN_TESTS) {
				Test.testAll();
			}
			
			_ctx = new Context(null, true);			
			_console = new Console(_ctx);
			stage.addChild(_console);
		}
	}
}