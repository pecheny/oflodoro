package treefortress.sound;
	import com.furusystems.events.Signal;
	import openfl.errors.Error;
	import openfl.events.Event;
	import openfl.media.Sound;
	import openfl.media.SoundChannel;
	import openfl.media.SoundTransform;
	import openfl.utils.ByteArray;

	class SoundInstance {


		/**
		 * Registered type for this Sound
		 */
		public var type:String;

		/**
		 * URL this sound was loaded from. This is null if the sound was not loaded externally.
		 */
		public var url:String;

		/**
		 * Current instance of Sound object
		 */
		public var sound:Sound;

		/**
		 * Current playback channel
		 */
		public var channel:SoundChannel;

		/**
		 * Dispatched when playback has completed
		 */
		public var soundCompleted:Signal<SoundInstance>;

		/**
		 * Number of times to loop this sound. Pass -1 to loop forever.
		 */
		public var loops:Int;

		/**
		 * Allow multiple concurrent instances of this Sound. If false, only one instance of this sound will ever play.
		 */
		public var allowMultiple:Bool;


		var pauseTime:Float;

		var soundTransform:SoundTransform;
		var currentTween:SoundTween;

		public function new(sound:Sound = null){
			this.sound = sound;
			pauseTime = 0;

			soundCompleted = new Signal<SoundInstance>();
			soundTransform = new SoundTransform();
		}

		/**
		 * Play this Sound 
		 * @param volume
		 * @param startTime Start position in milliseconds
		 * @param loops Number of times to loop Sound. Pass -1 to loop forever.
		 * @param allowMultiple Allow multiple concurrent instances of this Sound
		 */
		public function play(volume:Float = 1, startTime:Float = 0, loops:Int = 0, allowMultiple:Bool = true):SoundInstance {
			this.loops = loops;
			this.allowMultiple = allowMultiple;
			if(allowMultiple){
				channel = sound.play(startTime, loops);
			} else {
				if(channel!=null){
					pauseTime = channel.position;
					stopChannel(channel);
				}
 				channel = sound.play(startTime, loops == -1? 0 : loops);
			}
			if (channel == null)
				return null;
			channel.addEventListener(Event.SOUND_COMPLETE, onSoundComplete);
			this.volume = volume;
			this.mute = mute;
			return this;
		}

		/**
		 * Pause currently playing sound. Use resume() to continue playback.
		 */
		public function pause():SoundInstance {
			if(channel==null){ return this; }
			pauseTime = channel.position;
			channel.stop();
			return this;
		}



		public function resume():SoundInstance {
			if (pauseTime == 0)
				return this;
			play(volume, pauseTime, loops, allowMultiple);
			return this;
		}

		/**
		 * Stop the currently playing sound and set it's position to 0
		 */
		public function stop():SoundInstance {
			pauseTime = 0;
			if (channel!=null)
                channel.stop();
			return this;
		}

		/**
		 * Mute current sound.
		 */
		public var mute(default, set):Bool;
		function set_mute(value:Bool):Bool {
			mute = value;
			if(channel!=null){
				channel.soundTransform = mute? new SoundTransform(0) : soundTransform;
			}
			return mute;
		}

		/**
		 * Fade using the current volume as the Start Volume
		 */
		public function fadeTo(endVolume:Float, duration:Float = 1000):SoundInstance {
			currentTween = SoundHX.addTween(type, -1, endVolume, duration);
			return this;
		}

		/**
		 * Fade and specify both the Start Volume and End Volume.
		 */
		public function fadeFrom(startVolume:Float, endVolume:Float, duration:Float = 1000):SoundInstance {
			currentTween = SoundHX.addTween(type, startVolume, endVolume, duration);
			return this;
		}

		/**
		 * Indicates whether this sound is currently playing.
		 */
		public var isPlaying(get, null):Bool;
		function get_isPlaying():Bool {
			return (channel!=null && channel.position > 0);
		}

		/**
		 * Set position of sound in milliseconds
		 */
		public var position(get, set):Float;
		function get_position():Float { return channel != null ? channel.position : 0; }
		function set_position(value:Float):Float {
			if(channel!=null){
				stopChannel(channel);
			}
			channel = sound.play(value, loops);
			channel.addEventListener(Event.SOUND_COMPLETE, onSoundComplete);
			return value;
		}

		public var normalizedPosition(get, set):Float;
		function get_normalizedPosition():Float { return channel != null ? channel.position / sound.length : 0; }
		function set_normalizedPosition(value:Float) {
			if(channel!=null){
				stopChannel(channel);
			}
			value *= sound.length;
			channel = sound.play(value, loops);
			channel.addEventListener(Event.SOUND_COMPLETE, onSoundComplete);
			return value;
		}


		/**
		 * Value between 0 and 1. You can call this while muted to change volume, and it will not break the mute.
		 */
		public var volume(default, set):Float = 1;
		function set_volume(value:Float):Float {
			//Update the voume value, but respect the mute flag.
			if(value < 0){ value = 0; } else if(value > 1 || Math.isNaN(value)){ value = 1; }
			volume = value;
			//Update actual sound volume
			if(soundTransform==null){ soundTransform = new SoundTransform(); }
			soundTransform.volume = volume * masterVolume;
			if(mute){ return volume; }
			if(channel!=null){
				channel.soundTransform = soundTransform;
			}
			return volume;
		}

		/**
		 * Sets the master volume, which is multiplied with the current Volume level
		 */
		public var masterVolume(default, set):Float = 1;
		function set_masterVolume(value:Float):Float {
			if (masterVolume == value) { return value;  }
			//Update the voume value, but respect the mute flag.
			if(value < 0){ value = 0; } else if(value > 1){ value = 1; }
			masterVolume = value;
			//Call caller setter to update the volume
			volume = volume;
			return masterVolume;
		}
		/**
		 * Create a duplicate of this SoundInstance
		 */
		public function clone():SoundInstance {
			var si:SoundInstance = new SoundInstance(sound);
			return si;
		}


		/**
		 * Dispatched when Sound has finished playback
		 */
		function onSoundComplete(event:Event):Void {
			soundCompleted.dispatch(this);
			if(loops == -1 && event.target == channel){
				play(volume, 0, -1, allowMultiple);
			}
		}

		/**
		 * Unload sound from memory.
		 */
		public function destroy():Void {
			soundCompleted.removeAll();
			try {
				sound.close();
			} catch(e:Error){}
			sound = null;
			soundTransform = null;
			stopChannel(channel);
			endFade();
		}

		/**
		 * Ends the current tween for this sound if it has one.
		 */
		public function endFade(applyEndVolume:Bool = false):SoundInstance {
			if(currentTween==null){ return this; }
			currentTween.end(applyEndVolume);
			currentTween = null;
			return this;
		}

		function stopChannel(channel:SoundChannel):Void {
			if(channel==null){ return; }
			channel.removeEventListener(Event.SOUND_COMPLETE, onSoundComplete);
			try {
				channel.stop();
			} catch(e:Error){};
		}

		/**
		 * Get the samples of the sound as 44.1 kHz as 32-bit floating-point
		 * @return
		 */
		public function getBytes():ByteArray
		{
			throw "N/a";
//			var bytes:ByteArray = new ByteArray();
//			sound.extract(bytes, sound.bytesTotal);
//			sound.b
//			return bytes;
		}

	}