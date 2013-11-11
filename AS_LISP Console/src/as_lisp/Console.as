package as_lisp 
{
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.KeyboardEvent;
	import flash.system.System;
	import flash.text.TextField;
	import flash.text.TextFieldType;
	import flash.text.TextFormat;
	import flash.ui.Keyboard;
	
	import as_lisp.data.Printer;
	import as_lisp.test.Test;
	import as_lisp.util.Context;
	import as_lisp.util.MemoryScanner;
	
	/**
	 * Trivial console that can be added to any display object container;
	 * it provides a REPL for an already initialized execution context.
	 */
	public class Console extends Sprite
	{
		/** Character limit in the output area */
		public static const OUT_CHARS_MAX :int = 2000;
		
		/** Text format for the output field */
		public static const OUT_TEXT :TextFormat = new TextFormat("Consolas", 12, 0xff8080ff);
		
		/** Text format for the output field */
		public static const IN_TEXT :TextFormat = new TextFormat("Consolas", 12, 0xffa0a0ff);

		/** Output area */
		private var _out :TextField;
		
		/** Input area */
		private var _in :TextField;

		/** Last known input */
		private var _previous :String;
		
		/** Execution context */
		private var _ctx :Context;
		
		/** Memory scanner */
		private var _mem :MemoryScanner;
		
		public function Console (ctx :Context) 
		{
			_ctx = ctx;
			_mem = new MemoryScanner();
			
			this.addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
			this.addEventListener(Event.REMOVED_FROM_STAGE, onRemovedFromStage);
		}
		
		private function onAddedToStage (event :Event) :void {
			_out = new TextField();
			_out.multiline = true;
			_out.wordWrap = true;
			_out.type = TextFieldType.DYNAMIC;
			_out.background = true;
			_out.backgroundColor = 0x40404040;
			_out.defaultTextFormat = OUT_TEXT;
			_out.text = "AS_LISP REPL Console\n\n";
			addChild(_out);
			
			_in = new TextField();
			_in.multiline = false;
			_in.wordWrap = true;
			_in.type = TextFieldType.INPUT;
			_in.background = true;
			_in.backgroundColor = 0x40606060;
			_in.defaultTextFormat = IN_TEXT;
			_in.addEventListener(KeyboardEvent.KEY_DOWN, onInputKeyDown);
			addChild(_in);
			
			stage.focus = _in;
		}
		
		private function onRemovedFromStage (event :Event) :void {
			_in.removeEventListener(KeyboardEvent.KEY_DOWN, onInputKeyDown);
			removeChild(_in);
			_in = null;
			
			removeChild(_out);
			_out = null;
		}
		
		/** Accessor for the output text field */
		public function get output () :TextField {
			return _out;
		}
		
		/** Accessor for the input text field */
		public function get input () :TextField {
			return _in;
		}
		
		/** Helper function, resizes this console to fit its container */
		public function resize (w :Number, h :Number) :void {
			this.x = 0;
			this.y = 0;
			this.width = w;
			this.height = h;
			
			var outheight :int = int(this.height * 0.8);
			_out.x = _in.x = 0;
			_out.width = _in.width = this.width;
			_out.y = 0
			_out.height = outheight;
			_in.y = _out.y + outheight;
			_in.height = this.height - outheight;
		}
		
		/** Handles a key down */
		private function onInputKeyDown (event :KeyboardEvent) :void {
			switch (event.keyCode) {
				case Keyboard.ENTER:
					var input :String = _in.text;
					_previous = input;
					var outputs :Array = processSpecialCommand(input);
					if (outputs != null) {
						addToOutput(input, outputs, true);
					} else {
						try {
							outputs = _ctx.execute(input);
						} catch (e :Error) {
							outputs = [ e.message ];
						}
						addToOutput(input, outputs, false);
					}
					break;
				case Keyboard.UP:
					_in.text = _previous;
					break;
			}
		}
		
		/** Handles inputs and outputs */
		private function addToOutput (input :String, outputs :Array, raw :Boolean) :void {
			_out.appendText(input);
			_out.appendText("\n");
			for each (var output :* in outputs) {
				var text :String = (raw ? String(output) : Printer.toString(output));
				_out.appendText(text);
				_out.appendText("\n");
			}
			_out.scrollV = _out.maxScrollV;
			_in.text = "";
		}
		
		/** Handles special commands, such as exiting out of the REPL */
		private function processSpecialCommand (input :String) :Array {
			if (input.length == 0 || input.charAt(0) != "!") {
				return null;
			}
			
			switch (input) {
				case "!ex": 
					System.exit(0);
					return null;
				case "!mem":
					_mem.toggle();
					return [ _mem.lastMessage ];
				case "!help":
					return [ "Special commands:", "  !exit for console exit", "  !mem for memory report", "  !op for opcode debugging" ];
				case "!op":
					return [ "Opcode debugging: " + (toggleDebug() ? "on" : "off") ];
				default:
					return null;
			}
		}
		
		/** Toggles instruction-level debugging */
		private function toggleDebug () :Boolean {
			var logger :Function = (_ctx.vm.debugInstructionLogger != null) ? null : Test.logger;
			_ctx.vm.debugInstructionLogger = logger;
			return (logger != null);
		}
	}

}