/*
 * Cocktail, HTML rendering engine
 * http://haxe.org/com/libs/cocktail
 *
 * Copyright (c) Silex Labs
 * Cocktail is available under the MIT license
 * http://www.silexlabs.org/labs/cocktail-licensing/
*/
package resource;

import cocktail.domElement.ContainerDOMElement;
import cocktail.domElement.ImageDOMElement;
import cocktail.nativeInstance.NativeInstanceManager;
 #if flash9

import flash.display.Loader;
import flash.Lib;
import flash.system.ApplicationDomain;


#end
import cocktail.nativeElement.NativeElementManager;
import cocktail.classInstance.ClassInstance;
import haxe.Log;
import cocktail.domElement.DOMElement;
import utest.Assert;
import utest.Runner;
import utest.ui.Report;


import cocktail.resource.ResourceLoaderManager;

/**
 * Test the cross-platform resource loading
 *@author Yannick DOMINGUEZ & Raphael HARMEL
 */
class ResourceTests 
{
	
	private static var rootDOMElement:ContainerDOMElement;
	
	public static function main()
	{
	
		
		rootDOMElement = new ContainerDOMElement(NativeElementManager.getRoot());
		
		var runner = new Runner();
		runner.addCase(new ResourceTests());
		Report.create(runner);
		runner.run();
		
		#if php
		// display rootDOMElement filled with all tested elements
		untyped __call__('print_r', '<html>' + rootDOMElement.getReferenceToNativeDOM() + '</html>');
		#end
	}
	
	public function new() 
	{
		
	}
	
	/**
	 * Test loading a string (might be plain text, XML JSON...)
	 */
	public function testStringLoad()
	{
		var successCallback:String->Void = Assert.createEvent(onStringLoaded);
		ResourceLoaderManager.loadString("testString.txt", successCallback, onStringLoadError);
	}
	
	/**
	 * Called when the string has been loaded
	 * @param	data the loaded string
	 */
	private function onStringLoaded(data:String):Void
	{
		Assert.same("Hello loaded String !",data);
	}
	
	/**
	 * Called when there is an error while loading string
	 * @param	msg
	 */
	private function onStringLoadError(msg:String):Void
	{
		
	}
	
	
	
	/**
	 * load a class library (.swf in flash, .js in JavaScript, .php in php)
	 */
	public function testLibraryLoad()
	{
		var successCallback:Dynamic->Void = Assert.createEvent(onLibraryLoaded);
		#if flash9
		ResourceLoaderManager.loadLibrary("testLibrary.swf", successCallback, onLibraryError);
		#elseif js
		ResourceLoaderManager.loadLibrary("testLibrary.js", successCallback, onLibraryError);
		#elseif php
		ResourceLoaderManager.loadLibrary("testLibrary.php", successCallback, onLibraryError);
		#end
	}
	
	/**
	 * when the library has been loaded, instantiate one of the loaded classes
	 * @param	data null for a library
	 */
	private function onLibraryLoaded(data:Dynamic):Void
	{
		var nativeInstance:ClassInstance = NativeInstanceManager.getClassInstanceByClassName("LibrarySymbol");
		
		#if flash9
		flash.Lib.current.addChild(nativeInstance.nativeInstance);
		Assert.same(nativeInstance.getField("x"), 0);
		#elseif js
		Assert.same(nativeInstance.callMethod("testMethod", []), "library loaded ok !");
		#elseif php
		Assert.same(nativeInstance.callMethod("testMethod", []), "library loaded ok !");
		#end
	}

	/**
	 * Called when there is an error while loading the library
	 * @param	msg
	 */
	private function onLibraryError(msg:String):Void
	{
		
	}
	

}