package treefortress.sound;
import com.furusystems.events.Signal;
import flash.display.Shape;
import flash.errors.Error;
import flash.events.Event;
import flash.events.IOErrorEvent;
import flash.events.ProgressEvent;
import flash.Lib;
import flash.media.Sound;
import flash.media.SoundLoaderContext;
import flash.net.URLRequest;
import flash.utils.ByteArray;

using Lambda;
class SoundHX
{
	static var instances:Array<SoundInstance> = new Array<SoundInstance>();
	static var instancesBySound:Map<Sound,SoundInstance> = new Map<Sound, SoundInstance>();
	static var instancesByType:Map<String,SoundInstance> = new Map<String, SoundInstance>();
	static var activeTweens:Array<SoundTween> = new Array<SoundTween>();
	
	static var ticker:Shape;
	static var _masterTween:SoundTween;
	
	public static function initialize():Void
	{
		init();
		ticker = new Shape();
	}
	
	
	/**
	 * Dispatched when an external Sound has completed loading. 
	 */
	public static var loadCompleted:Signal<SoundInstance>;
	
	/**
	 * Dispatched when an external Sound has failed loading. 
	 */
	public static var loadFailed:Signal<SoundInstance>;
	
	
	/**
	 * Play audio by type. It must already be loaded into memory using the addSound() or loadSound() APIs. 
	 * @param type
	 * @param volume
	 * @param startTime Starting time in milliseconds
	 * @param loops Number of times to loop audio, pass -1 to loop forever.
	 * @param allowMultiple Allow multiple, overlapping instances of this Sound (useful for SoundFX)
	 * @param allowInterrupt If this sound is currently playing, interrupt it and start at the specified StartTime. Otherwise, just update the Volume.
	 */
	public static function play(type:String, volume:Float = 1, startTime:Float = 0, loops:Int = 0, allowMultiple:Bool = false, allowInterrupt:Bool = true):SoundInstance {
		var si:SoundInstance = getSound(type);
		
		//Sound is playing, and we're not allowed to interrupt it. Just set volume.
		if(!allowInterrupt && si.isPlaying){
			si.volume = volume;
		} 
		//Play sound
		else {
			si.play(volume, startTime, loops, allowMultiple);
		}
		return si;
	}
	
	/**
	 * Convenience function to play a sound that should loop forever.
	 * 
	 */
	public static function playLoop(type:String, volume:Float = 1, startTime:Float = -1):SoundInstance {
		return play(type, volume, startTime, -1, false);
	}
	
	/**
	 * Convenience function to play a sound that can have overlapping instances (ie click or soundFx).
	 * 
	 */
	public static function playFx(type:String, volume:Float = 1, startTime:Float = -1, loops:Int = 0):SoundInstance {
		return play(type, volume, startTime, 0, true);
	}
	
	/**
	 * Resume specific sound 
	 */
	public static function resume(type:String):SoundInstance {
		return getSound(type).resume();
	}
	
	/**
	 * Resume all paused instances.
	 */
	public static function resumeAll():Void {
		for(i in instances){
			i.resume();
		}
	}
	
	/** 
	 * Pause a specific sound 
	 **/
	public static function pause(type:String):SoundInstance {
		return getSound(type).pause();
	}
	
	/**
	 * Pause all sounds
	 */
	public static function pauseAll():Void {
		for(i in instances){
			i.pause();
		}
	}
	
	/**
	 * Stop a specific sound
	 */
	public static function stop(type:String):SoundInstance {
		return getSound(type).stop();
	}
	
	/**
	 * Stop all sounds
	 */
	public static function stopAll():Void {
		for(i in instances){
			i.stop();
		}
	}
	
	/** 
	 * Fade master volume starting at the current value
	 **/
	public static function fadeMasterTo(endVolume:Float = 1, duration:Float = 1000):Void {
		addMasterTween(masterVolume, endVolume, duration);
	}
	
	/** 
	 * Fade specific sound starting at the current volume
	 **/
	public static function fadeTo(type:String, endVolume:Float = 1, duration:Float = 1000):SoundInstance {
		return getSound(type).fadeTo(endVolume, duration);
	}
	
	/**
	 * Fade all sounds starting from their current Volume
	 */
	public static function fadeAllTo(endVolume:Float = 1, duration:Float = 1000):Void {
		for(i in instances){
			i.fadeTo(endVolume, duration);
		}
	}
	
	/** 
	 * Fade specific sound specifying both the StartVolume and EndVolume.
	 **/
	public static function fadeFrom(type:String, startVolume:Float = 0, endVolume:Float = 1, duration:Float = 1000):SoundInstance {
		return getSound(type).fadeFrom(startVolume, endVolume, duration);
	}
	
	/**
	 * Fade all sounds specifying both the StartVolume and EndVolume.
	 */
	public static function fadeAllFrom(startVolume:Float = 0, endVolume:Float = 1, duration:Float = 1000):Void {
		for(i in instances){
			i.fadeFrom(startVolume, endVolume, duration);
		}
	}
	
	/** 
	 * Fade master volume specifying both the StartVolume and EndVolume.
	 **/
	public static function fadeMasterFrom(endVolume:Float = 1, duration:Float = 1000):Void {
		addMasterTween(masterVolume, endVolume, duration);
	}
	
	/**
	 * Mute all instances.
	 */
	public static var mute(default, set):Bool;
	static function set_mute(value:Bool):Bool{
		mute = value;
		for(i in instances){
			i.mute = mute;
		}
		return mute;
	}
	
	/**
	 * Set volume on all instances
	 */
	public static var volume(default, set):Float;
	static function set_volume(value:Float):Float {
		volume = value;
		for(i in instances){
			i.volume = volume;
		}
		return volume;
	}
	
	/**
	 * Returns a SoundInstance for a specific type.
	 */
	public static function getSound(type:String, forceNew:Bool = false):SoundInstance {
		var si:SoundInstance = instancesByType.get(type);
		if(si==null){ throw(new Error("[SoundHX] Sound with type '"+type+"' does not appear to be loaded.")); }
		if(forceNew){
			si = si.clone();	
		} 
		return si;
	}
	
	/**
	 * Preload a sound from a URL or Local Path
	 * @param url External file path to the sound instance.
	 * @param type 
	 * @param buffer
	 * 
	 */
	public static function loadSound(url:String, type:String, buffer:Int = 100):Void {
		//Check whether this Sound is already loaded
		var si:SoundInstance = instancesByType.get(type);
		if(si!=null && si.url == url){ return; }
		
		si = new SoundInstance();
		si.type = type;
		si.url = url; //Useful for looking in case of load error
		si.sound = new Sound(new URLRequest(url), new SoundLoaderContext(buffer, false));
		si.sound.addEventListener(IOErrorEvent.IO_ERROR, onSoundLoadError, false, 0, true);
		//si.sound.addEventListener(ProgressEvent.PROGRESS, onSoundLoadProgress, false, 0, true);
		si.sound.addEventListener(Event.COMPLETE, onSoundLoadComplete, false, 0, true);
		addInstance(si);
	}
	
	/**
	 * Inject a sound that has already been loaded.
	 */
	public static function addSound(type:String, sound:Sound):Void {
		var si:SoundInstance;
		//If the type is already mapped, inject sound into the existing SoundInstance.
		if(instancesByType.exists(type)){
			si = instancesByType.get(type);
			si.sound = sound;
		} 
		//Create a new SoundInstance
		else {
			si = new SoundInstance(sound);	
			si.type = type;
		}
		addInstance(si);
	}
	
	/**
	 * Remove a sound from memory.
	 */
	public static function removeSound(type:String):Void {
		if(instancesByType.get(type) == null){ return; }
		for(i in instances){
			if(i.type == type){
				instancesBySound.set(i.sound, null);
				i.destroy();
				instances.remove(i);
			}
		}
		instancesByType.set(type, null);
	}
	
	/**
	 * Unload all Sound instances.
	 */
	public static function removeAll():Void {
		for(i in instances){
			i.destroy();
		}
		init();
	}
	
	/**
	 * Set master volume, which will me multiplied on top of all existing volume levels.
	 */
	public static var masterVolume(default, set):Float;
	public static function set_masterVolume(value:Float):Float {
		masterVolume = value;
		for(i in instances){
			i.masterVolume = masterVolume;
		}
		return masterVolume;
	}
	
	/**
	 * PRIVATE
	 */
	
	static function init():Void {
		//Create external signals
		if(loadCompleted==null){ loadCompleted = new Signal<SoundInstance>(); }
		if(loadFailed==null){ loadFailed = new Signal<SoundInstance>(); }
		
		//Init collections
		volume = 1;
		masterVolume = 1;
		instances = new Array<SoundInstance>();
		instancesBySound = new Map<Sound, SoundInstance>();
		instancesByType = new Map<String, SoundInstance>();
		activeTweens = new Array<SoundTween>();
	}
	
	static function addMasterTween(startVolume:Float, endVolume:Float, duration:Float = 1000):Void {
		if(_masterTween==null){ _masterTween = new SoundTween(null, 0, 0, true); }
		
		_masterTween.init(startVolume, endVolume, duration);
		
		if(activeTweens.indexOf(_masterTween) == -1){
			activeTweens.push(_masterTween);
		}
		if(!ticker.hasEventListener(Event.ENTER_FRAME)){
			ticker.addEventListener(Event.ENTER_FRAME, onTick);
		}
	}
	
	public static function addTween(type:String, startVolume:Float, endVolume:Float, duration:Float):SoundTween {
		var si:SoundInstance = getSound(type);
		if(startVolume >= 0){ si.volume = startVolume; }
		var tween:SoundTween = new SoundTween(si, endVolume, duration);
		//Kill any active fade
		si.endFade();
		
		//Add tween
		activeTweens.push(tween);
		if(!ticker.hasEventListener(Event.ENTER_FRAME)){
			ticker.addEventListener(Event.ENTER_FRAME, onTick);
		}
		return tween;
	}
	
	static function onTick(event:Event):Void {
		var t:Int = Lib.getTimer();
		for(i in activeTweens){
			if(i.update(t)){
				activeTweens.remove(i);
			}
		}
		if(activeTweens.length == 0){ ticker.removeEventListener(Event.ENTER_FRAME, onTick); }
	}
	
	static function addInstance(si:SoundInstance):Void {
		si.mute = mute;
		if (instances.indexOf(si) == -1) { instances.push(si); }
		instancesBySound.set(si.sound, si);
		instancesByType.set(si.type, si);
	}
	
	static function onSoundLoadComplete(event:Event):Void {
		var sound:Sound = cast event.target;
		loadCompleted.dispatch(instancesBySound.get(sound));	
	}
	
	static function onSoundLoadProgress(event:ProgressEvent):Void { }
	
	static function onSoundLoadError(event:IOErrorEvent):Void {
		var sound:Sound = cast event.target;
		loadFailed.dispatch(instancesBySound.get(sound));
	}
	
	/**
	 * Get the samples of the sound as 44.1 kHz as 32-bit floating-point
	 * @param	type
	 * @return
	 */
	public static function getSoundBytes(type:String):ByteArray
	{
		var si:SoundInstance = instancesByType.get(type);
		if (si == null)
			return null;
		else
			return si.getBytes();
	}
	
}

