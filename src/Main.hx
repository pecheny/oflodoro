package;

import haxe.Json;
import openfl.ui.Keyboard;
import openfl.events.KeyboardEvent;
import openfl.utils.Assets;
import treefortress.sound.SoundHX;
import lime.media.AudioSource;
import openfl.events.MouseEvent;
import openfl.media.Sound;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFormat;
import openfl.text.TextField;
import haxe.Timer;
import openfl.events.Event;
import openfl.display.Sprite;

class Main extends Sprite {
    var label:TextField;

    public function new() {
        super();
        var wnd = openfl.Lib.application.window;
        wnd.x = 64;
        wnd.y = 200;

        SoundHX.addSound("tick", Assets.getSound("Assets/tick-2.wav"));
        SoundHX.addSound("bong", Assets.getSound("Assets/bong-2.wav"));
        // tick.loops = -1;
        label = new TextField();
        label.mouseEnabled = false;
        label.defaultTextFormat = new TextFormat("Helvetica", 64, 0xffffff);
        label.autoSize = TextFieldAutoSize.LEFT;
        label.text = "00:00";
        label.x = 20;
        label.y = 20;

        addChild(label);
        addEventListener(Event.ENTER_FRAME, onEnterFrame);
        stage.addEventListener(MouseEvent.CLICK, start);
        stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
        reset();
    }

    var remains:Float;

    function onKeyDown(e:KeyboardEvent) {
        switch e.keyCode {
            case Keyboard.SPACE:
                if (!running) {
                    if (endTime < 0) {
                        start(null);
                        return;
                    }
                    endTime = remains + Timer.stamp();
                    SoundHX.playLoop("tick");
                } else {
                    SoundHX.stopAll();
                }
                running = !running;
            case Keyboard.R:
                reset();
        }
    }

    var running = false;
    var endTime:Float;

    function start(e) {
        if (running)
            return;
        var duration = 45;
        try {
            var data = sys.io.File.getContent("config.json");
            var config = Json.parse(data);
            if (Std.isOfType(config.duration, Int))
                duration = config.duration;
        } catch (e:Dynamic) {}
        sys.io.File.saveContent("session", DateTools.format(Date.now(), "%T"));
        SoundHX.playLoop("tick");
        endTime = Timer.stamp() + (60 * duration);
        running = true;
    }

    var skip = 10;

    function reset() {
        endTime = -1;
        running = false;
        SoundHX.stop("tick");
        label.text = "00:00";
    }

    function onEnterFrame(e) {
        if (!running)
            return;
        remains = endTime - Timer.stamp();
        if (remains <= 0) {
            reset();
            // bong.play();
            SoundHX.play("bong");
            return;
        }

        if (skip == 10) {
            label.text = "" + minutes(remains) + ":" + seconds(remains);
            skip = 0;
        }
        skip++;
    }

    inline function minutes(ticks:Float) {
        return Std.int(ticks / (60));
    }

    inline function seconds(ticks:Float) {
        return Std.int((ticks) - minutes(ticks) * 60);
    }
}
