package;

import away3d.animators.*;
import away3d.containers.*;
import away3d.controllers.*;
import away3d.entities.*;
import away3d.events.*;
import away3d.library.*;
import away3d.library.assets.*;
import away3d.lights.*;
import away3d.loaders.parsers.*;
import away3d.materials.*;
import away3d.materials.lightpickers.*;
import away3d.materials.methods.*;
import away3d.primitives.*;
import away3d.utils.Cast;

import openfl.display.*;
import openfl.events.*;
import openfl.filters.*;
import openfl.geom.*;
import openfl.text.*;
import openfl.ui.*;
import openfl.utils.ByteArray;

import openfl.Assets;

import utils.*;
import events.*;
import widgets.*;

class Main extends Sprite
{

	//Perelith Knight model
	public static var PKnightModel:ByteArray;

	private var _knightMaterial:TextureMaterial;

	//engine variables
	private var _view:View3D;
	private var _cameraController:HoverController;

	//light objects
	private var _light:DirectionalLight;
	private var _lightPicker:StaticLightPicker;

	//material objects
	private var _floorMaterial:TextureMaterial;
	private var _shadowMapMethod:FilteredShadowMapMethod;

	//scene objects
	private var _floor:Mesh;
	private var _mesh:Mesh;

	//navigation variables
	private var _move:Bool;
	private var _lastPanAngle:Float;
	private var _lastTiltAngle:Float;
	private var _lastMouseX:Float;
	private var _lastMouseY:Float;
	private var _keyUp:Bool;
	private var _keyDown:Bool;
	private var _keyLeft:Bool;
  private var _keyRight:Bool;
	private var _keySpace:Bool;
	private var _lookAtPosition:Vector3D;
	private var _animationSet:VertexAnimationSet;
  private var _vertexAnimator:VertexAnimator;
	public var _joystick:Joystick;
	public var _joystickMove:Bool;
	public var _joystickX:Float;
	public var _joystickY:Float;

	/**
	 * Constructor
	 */
	public function new()
	{
		super();

		_move = false;
		_lookAtPosition = new Vector3D();

		stage.scaleMode = StageScaleMode.NO_SCALE;
		stage.align = StageAlign.TOP_LEFT;

		//setup the view
		_view = new View3D();
		addChild(_view);

		//setup the camera for optimal rendering
		_view.camera.lens.far = 5000;


		//setup the lights for the scene
		_light = new DirectionalLight(-0.5, -1, -1);
		_light.ambient = 1;
		_lightPicker = new StaticLightPicker([_light]);
		_view.scene.addChild(_light);

		//setup parser to be used on AssetLibrary
		PKnightModel = Assets.getBytes('embeds/pknight/pknight.md2');
		Asset3DLibrary.loadData(PKnightModel, null, null, new MD2Parser());
		Asset3DLibrary.addEventListener(Asset3DEvent.ASSET_COMPLETE, onAssetComplete);
		Asset3DLibrary.addEventListener(LoaderEvent.RESOURCE_COMPLETE, onResourceComplete);

		//create a global shadow map method
		#if !ios
		_shadowMapMethod = new FilteredShadowMapMethod(_light);
		#end

		//setup floor material
		_floorMaterial = new TextureMaterial(Cast.bitmapTexture("embeds/floor_diffuse.jpg"));
		_floorMaterial.lightPicker = _lightPicker;
		_floorMaterial.specular = 0;
		_floorMaterial.ambient = 1;
		#if !ios
		_floorMaterial.shadowMethod = _shadowMapMethod;
		#end
		_floorMaterial.repeat = true;

		//setup Perelith Knight materials
		_knightMaterial = new TextureMaterial(Cast.bitmapTexture("embeds/pknight/pknight1.png"));
		//_knightMaterial.normalMap = Cast.bitmapTexture(BitmapFilterEffects.normalMap(bitmapData));
		//_knightMaterial.specularMap = Cast.bitmapTexture(BitmapFilterEffects.outline(bitmapData));
		_knightMaterial.lightPicker = _lightPicker;
		_knightMaterial.gloss = 30;
		_knightMaterial.specular = 1;
		_knightMaterial.ambient = 1;
		#if !ios
		_knightMaterial.shadowMethod = _shadowMapMethod;
		#end


		//setup the floor
		_floor = new Mesh(new PlaneGeometry(5000, 5000), _floorMaterial);
		_floor.geometry.scaleUV(5, 5);

		//setup the scene
		_view.scene.addChild(_floor);

		//add listeners
		stage.addEventListener(KeyboardEvent.KEY_UP, onKeyUp);
		stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
		stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
		stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp);
		stage.addEventListener(Event.MOUSE_LEAVE, onMouseUp);
		stage.addEventListener(MouseEvent.MOUSE_WHEEL, onMouseWheel);
		stage.addEventListener(Event.RESIZE, onResize);
		onResize();

    //stats
    this.addChild(new away3d.debug.AwayFPS(_view, 10, 10, 0xffffff, 3));



	}


	/**
	 * Navigation and render loop
	 */
	private function onEnterFrame(event:Event)
	{
		// if (_move) {
		// 	_cameraController.panAngle = 0.3*(stage.mouseX - _lastMouseX) + _lastPanAngle;
		// 	_cameraController.tiltAngle = 0.3*(stage.mouseY - _lastMouseY) + _lastTiltAngle;
		// }

		if (_keyUp)
			_mesh.x += 10;
		if (_keyDown)
			_mesh.x -= 10;
		if (_keyLeft)
			_lookAtPosition.z -= 10;
		if (_keyRight)
			_lookAtPosition.z += 10;

		if (_joystickMove) {
			_mesh.x += _joystickX * 10;
			_mesh.z -= _joystickY * 10;
			_mesh.rotationY = Math.atan2(_joystickY, _joystickX) * 180 / Math.PI;
		}

		//_cameraController.lookAtPosition = _lookAtPosition;

		_view.render();
	}

	/**
	 * Listener function for asset complete event on loader
	 */
	private function onAssetComplete(event:Asset3DEvent)
	{
		if (event.asset.assetType == Asset3DType.MESH) {
			_mesh = cast(event.asset, Mesh);

			//adjust the ogre mesh
			_mesh.y = 120;
			_mesh.scale(5);

		} else if (event.asset.assetType == Asset3DType.ANIMATION_SET) {
			_animationSet = cast(event.asset, VertexAnimationSet);
		}
	}

	/**
	 * Listener function for resource complete event on loader
	 */
	private function onResourceComplete(event:LoaderEvent)
	{

    _mesh.x = 0;
		_mesh.z = 0;
		_mesh.castsShadows = true;
		_mesh.material = _knightMaterial;
		_view.scene.addChild(_mesh);

		//create animator
		_vertexAnimator = new VertexAnimator(_animationSet);

		//play specified state
		_vertexAnimator.play('stand');
		_mesh.animator = _vertexAnimator;


    for( animation in _animationSet.animationNames ) {
      trace(animation);
    }



		//setup controller to be used on the camera
		// _cameraController = new FollowController(_view.camera, _mesh, 20, 400);
		_cameraController = new HoverController(_view.camera, _mesh, 180, 20, 400);


		_view.setRenderCallback(onEnterFrame);

		// init joystick
		stage.addEventListener(JoystickEvent.JOYSTICK_ADDED, onJoystickAdded );
		stage.addEventListener(JoystickEvent.JOYSTICK_MOVED, onJoystickMove );
		stage.addEventListener(JoystickEvent.JOYSTICK_REMOVED, onJoystickRemoved );
		Joystick.start();
	}

  private function changeAnimation(event:AnimatorEvent)
  {
    _vertexAnimator.play('stand');

    _vertexAnimator.removeEventListener(AnimatorEvent.CYCLE_COMPLETE, changeAnimation);
  }

	public function onJoystickAdded(event:JoystickEvent) : Void
	{
		trace(event.joystick.x, event.joystick.y);
		_vertexAnimator.play('run');
	}

	public function onJoystickMove(event:JoystickEvent) : Void
	{
		trace(event.joystick.x, event.joystick.y);
		_joystickMove = true;
		_joystickX = event.joystick.x;
		_joystickY = event.joystick.y;
	}

	public function onJoystickRemoved(event:JoystickEvent) : Void
	{
		trace(event.joystick.x, event.joystick.y);
		_joystickMove = false;
		_vertexAnimator.play('stand');
	}

	function getAngle (x1:Float, y1:Float, x2:Float, y2:Float):Float
	{
	    var dx:Float = x2 - x1;
	    var dy:Float = y2 - y1;
	    return Math.atan2(dy,dx);
	}

	/**
	 * Key down listener for animation
	 */
	private function onKeyDown(event:KeyboardEvent)
	{
		switch (event.keyCode) {
			case Keyboard.UP, Keyboard.W, Keyboard.Z: //fr
				_keyUp = true;
				_vertexAnimator.play('run');
				_vertexAnimator.addEventListener(AnimatorEvent.CYCLE_COMPLETE, changeAnimation);
			case Keyboard.DOWN, Keyboard.S:
				_keyDown = true;
			case Keyboard.LEFT, Keyboard.A, Keyboard.Q: //fr
				_keyLeft = true;
			case Keyboard.RIGHT, Keyboard.D:
				_keyRight = true;
      case Keyboard.SPACE:
        _vertexAnimator.play('jump');
        _vertexAnimator.addEventListener(AnimatorEvent.CYCLE_COMPLETE, changeAnimation);
		}
	}

	/**
	 * Key up listener
	 */
	private function onKeyUp(event:KeyboardEvent)
	{
		switch (event.keyCode) {
			case Keyboard.UP, Keyboard.W, Keyboard.Z: //fr
				_keyUp = false;
			case Keyboard.DOWN, Keyboard.S:
				_keyDown = false;
			case Keyboard.LEFT, Keyboard.A, Keyboard.Q: //fr
				_keyLeft = false;
			case Keyboard.RIGHT, Keyboard.D:
				_keyRight = false;
		}
	}

	/**
	 * Mouse down listener for navigation
	 */
	private function onMouseDown(event:MouseEvent)
	{
		// _lastPanAngle = _cameraController.panAngle;
		// _lastTiltAngle = _cameraController.tiltAngle;
		_lastMouseX = stage.mouseX;
		_lastMouseY = stage.mouseY;
		_move = true;
	}

	/**
	 * Mouse up listener for navigation
	 */
	private function onMouseUp(event:Event)
	{
		_move = false;
	}

	/**
	 * Mouse wheel listener for navigation
	 */
	private function onMouseWheel(ev:MouseEvent)
	{
		// _cameraController.distance -= ev.delta * 5;
		//
		// if (_cameraController.distance < 100)
		// 	_cameraController.distance = 100;
		// else if (_cameraController.distance > 2000)
		// 	_cameraController.distance = 2000;
	}

	/**
	 * Stage listener for resize events
	 */
	private function onResize(event:Event = null)
	{
		_view.width = stage.stageWidth;
		_view.height = stage.stageHeight;
	}
}
