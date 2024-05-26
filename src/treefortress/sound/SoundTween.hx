package treefortress.sound;
import flash.Lib;
	
class SoundTween {
	
	public var startTime:Int;
	public var startVolume:Float;
	public var endVolume:Float;
	public var duration:Float;
	public var sound:SoundInstance;
	
	var isMasterFade:Bool;
	var _isComplete:Bool;
	
	public function new(si:SoundInstance, endVolume:Float, duration:Float, isMasterFade:Bool = false) {
		if(si!=null){
			sound = si;
			startVolume = sound.volume;
		}
		this.isMasterFade = isMasterFade;
		init(startVolume, endVolume, duration);
	}
	
	public function update(t:Int):Bool {
		if(_isComplete){ return _isComplete; }
		
		if(isMasterFade){
			if(t - startTime < duration){
				SoundHX.masterVolume = easeOutQuad(t - startTime, startVolume, endVolume - startVolume, duration);
			} else {
				SoundHX.masterVolume = endVolume;
			}
			_isComplete = SoundHX.masterVolume == endVolume;
			
		} else {
			if(t - startTime < duration){
				sound.volume = easeOutQuad(t - startTime, startVolume, endVolume - startVolume, duration);
			} else {
				sound.volume = endVolume;
			}
			_isComplete = sound.volume == endVolume;
		}
		return _isComplete;
		
	}
	
	public function init(startVolume:Float, endVolume:Float, duration:Float):Void {
		this.startTime = Lib.getTimer();
		this.startVolume = startVolume;
		this.endVolume = endVolume;
		this.duration = duration;
		_isComplete = false;
	}
	
	public function end(applyEndVolume:Bool = false):Void {
		_isComplete = true;
		if(applyEndVolume){
			sound.volume = endVolume;
		}
	}
	
	/**
	 * Equations from the man Robert Penner, see here for more:
	 * http://www.dzone.com/snippets/robert-penner-easing-equations
	 */
	static inline function easeOutQuad(position:Float, startValue:Float, change:Float, duration:Float):Float {
		return -change *(position/=duration)*(position-2) + startValue;
	}
	
	static inline function easeInOutQuad(position:Float, startValue:Float, change:Float, duration:Float):Float {
		if ((position/=duration/2) < 1){
			return change/2*position*position + startValue;
		}
		return -change/2 * ((--position)*(position-2) - 1) + startValue;
	}
	
	public var isComplete(get, null):Bool;
	private function get_isComplete():Bool 
	{
		return _isComplete;
	}


	
}