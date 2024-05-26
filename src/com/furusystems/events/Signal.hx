package com.furusystems.events;

/**
 * ...
 * @author Andreas Rønning
 */
enum ListenerTypes {
	ONCE;
	NORMAL;
}
class Signal<T>
{
	private var listeners:Array<Listener<T>> ;
	public function new() 
	{
		listeners = new Array<Listener<T>>();
	}
	public inline function add(func:T->Void):Void {
		remove(func);
		listeners.push( new Listener<T>(ListenerTypes.NORMAL, func) );
	}
	public inline function remove(func:T->Void):Void {
		for (l in listeners) 
		{
			if (l.func == func) {
				listeners.remove(l);
				break;
			}
		}
	}
	public inline function addOnce(func:T->Void):Void {
		remove(func);
		listeners.push( new Listener<T>(ListenerTypes.ONCE, func) );
	}
	public inline function removeAll():Void {
		listeners = new Array<Listener<T>>();
	}
	public inline function dispose():Void {
		listeners = null;
	}
	public inline function dispatch(value:T):Void {
		for (i in listeners) 
		{
			i.execute(value);
			if (i.type == ListenerTypes.ONCE) {
				listeners.remove(i);
			}
		}
	}
}
private class Listener<T> {
	public var func:T->Void;
	public var type:ListenerTypes;
	public inline function execute(arg:T):Void {
		func(arg);
	}
	public function new(type:ListenerTypes, func:T->Void) {
		this.type = type;
		this.func = func;
	}
}