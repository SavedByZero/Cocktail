/*
	This file is part of Cocktail http://www.silexlabs.org/groups/labs/cocktail/
	This project is © 2010-2011 Silex Labs and is released under the GPL License:
	This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License (GPL) as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version. 
	This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
	To read the license please visit http://www.gnu.org/copyleft/gpl.html
*/
package cocktail.core.graphics;

import cocktail.core.geom.Matrix;
import cocktail.core.html.HTMLDocument;
import cocktail.core.layer.LayerRenderer;
import cocktail.core.renderer.ElementRenderer;
import cocktail.port.NativeBitmapData;
import cocktail.port.NativeElement;

import cocktail.core.geom.GeomData;
import cocktail.core.layout.LayoutData;
import cocktail.core.css.CSSData;
import cocktail.port.NativeLayer;

/**
 * This is the base class for classes which 
 * actually implements the platform specific
 * API calls to draw and build the native display
 * list of the target platform.
 * 
 * It is implemented for each graphic target platform
 * 
 * @author Yannick DOMINGUEZ
 */
class AbstractGraphicsContextImpl
{
	/**
	 * A reference to a native layer
	 */
	public var nativeLayer(get_nativeLayer, null):NativeLayer;
	
	/**
	 * A reference to a native bitmap data object of the 
	 * underlying platform
	 */
	public var nativeBitmapData(get_nativeBitmapData, null):NativeBitmapData;
	
	/**
	 * A flag determining wether to use the specified alpha when drawing
	 * bitmap
	 */
	private var _useTransparency:Bool;
	
	/**
	 * The current used alpha when transparency is activated,
	 * as defined by the _useTransparency flag
	 */
	private var _alpha:Float;

	/**
	 * class constructor
	 */
	public function new()
	{
		_useTransparency = false;
		_alpha = 0.0;
	}
	
	/**
	 * Init the bitmap data with a given size
	 */
	public function initBitmapData(width:Int, height:Int):Void
	{
		//abstract
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////
	// PUBLIC METHODS
	//////////////////////////////////////////////////////////////////////////////////////////
	
	/**
	 * Attach the native layer to the native display list
	 * 
	 * @param	graphicsContext the graphic context containing
	 * the native layer where this native layer should be attached
	 * @param	index the index of the graphic context owning this
	 * graphic context implemention in its parent's children list
	 */
	public function attach(graphicsContext:GraphicsContext, index:Int):Void
	{
		//abstract
	}
	
	/**
	 * Detach the native from the native display list
	 */
	public function detach(graphicsContext:GraphicsContext):Void
	{
		//abstract
	}
	
	/**
	 * Attach the native layer to the root
	 * of the native display list, used for
	 * the root graphics context
	 */
	public function attachToRoot():Void
	{
		//abstract
	}
	
	/**
	 * Detach the native layer from
	 * the root of the native display list
	 */
	public function detachFromRoot():Void
	{
		//abstract
	}
	
	/**
	 * clean-up method, free memory used
	 * by graphics context
	 */
	public function dispose():Void
	{
		//abstract
	}
	
	/**
	 * Apply a transformation matrix to the layer
	 */
	public function transform(matrix:Matrix):Void
	{
		//abstract
	}
	
	/**
	 * Clears the bitmap data
	 */
	public function clear():Void
	{
		//abstract
	}
	
	/**
	 * When called, all subsequent calls to bitmap
	 * drawing methods draw transparent bitmap with
	 * the provided alpha, until endTransparency is called
	 */
	public function beginTransparency(alpha:Float):Void
	{
		_useTransparency = true;
		_alpha = alpha;
	}
	
	/**
	 * End the use of transparency when drawing 
	 * bitmaps
	 */
	public function endTransparency():Void
	{
		_useTransparency = false;
	}
	
	/**
	 * Draw bitmap data onto the bitmap surface. Alpha is preserved 
	 * for transparent bitmap
	 * @param	bitmapData the source  bitmap data
	 * @param	matrix a transformation matrix to apply yo the bitmap data when drawing to 
	 * to the bitmap.
	 * @param	sourceRect defines the zone from the source bitmap data that must be copied onto the 
	 * native graphic dom element.
	 */
	public function drawImage(bitmapData:NativeBitmapData, matrix:Matrix, sourceRect:RectangleVO):Void
	{
		//abstract
	}
	
	/**
	 * fast pixel manipulation method used when no transformation is applied to the image
	 * @param	bitmapData the pixels to copy
	 * @param	sourceRect the area of the source bitmap data to use
	 * @param	destPoint the upper left corner of the rectangular aeaa where the new
	 * pixels are placed
	 */
	public function copyPixels(bitmapData:NativeBitmapData, sourceRect:RectangleVO, destPoint:PointVO):Void
	{
		//abstract
	}
	
	/**
	 * Fill a rect with the specified color
	 * @param rect the rectangle to fill
	 * @param color the rectangle's color
	 */
	public function fillRect(rect:RectangleVO, color:ColorVO):Void
	{
		//abstract
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////
	// GETTER
	//////////////////////////////////////////////////////////////////////////////////////////
	
	private function get_nativeBitmapData():NativeBitmapData
	{
		return null;
	}
	
	private function get_nativeLayer():NativeLayer
	{
		return null;
	}
	
}