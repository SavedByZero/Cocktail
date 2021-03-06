/*
	This file is part of Cocktail http://www.silexlabs.org/groups/labs/cocktail/
	This project is © 2010-2011 Silex Labs and is released under the GPL License:
	This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License (GPL) as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version. 
	This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
	To read the license please visit http://www.gnu.org/copyleft/gpl.html
*/
package cocktail.core.html;
import cocktail.core.dom.Attr;
import cocktail.core.event.Event;
import cocktail.core.event.EventConstants;
import cocktail.core.event.UIEvent;
import cocktail.core.renderer.ObjectRenderer;
import cocktail.core.resource.AbstractResource;
import cocktail.core.resource.ResourceManager;
import cocktail.plugin.Plugin;
import cocktail.plugin.swf.SWFPlugin;
import cocktail.core.renderer.ImageRenderer;
import cocktail.core.renderer.RendererData;
import cocktail.port.NativeHttp;

/**
 * The object element can represent an external resource,
 * which, depending on the type of the resource,
 * will either be treated as an image, as a nested browsing
 * context, or as an external resource to be processed by a plugin.
 * 
 * TODO 1 IMPORTANT : for now only support embedding of flash movies, which are hard-code. Should
 * be able to display any plugin as well as regular picture like .jpg.
 * There is currently no easy way to add a third-party plugin
 * 
 * @author Yannick DOMINGUEZ
 */
class HTMLObjectElement extends EmbeddedElement
{

	//the intrinsic dimensions of an object tag, they are always the same and do not
	//depend on the displayed content
	
	private static inline var HTML_OBJECT_INTRISIC_WIDTH:Float = 300;
	
	private static inline var HTML_OBJECT_INTRINSIC_HEIGHT:Float = 150;
	
	/**
	 * Extension of a flash movie file
	 */
	private static inline var SWF_FILE_EXTENSION:String = ".swf";
	
	//////////////////////////////////////////////////////////////////////////////////////////
	// IDL attributes
	//////////////////////////////////////////////////////////////////////////////////////////
	
	/**
	 * The data attribute specifies the address of the resource.
	 */
	public var data(get_data, set_data):String;
	
	//////////////////////////////////////////////////////////////////////////////////////////
	// attributes
	//////////////////////////////////////////////////////////////////////////////////////////
	
	/**
	 * A reference to the plugin instantiated
	 * by this HTMLElement. It might be null,
	 * if the resource is a native one, like
	 * a picture or if not enough data are
	 * provided to determine which plugin
	 * to instantiate
	 */
	public var plugin(default, null):Plugin;
	
	/**
	 * A flag determining wheter the plugin is
	 * ready to be used. The plugin, after
	 * being instantiate call a callback to
	 * signal that it is ready to be used
	 */
	private var _pluginReady:Bool;
	
	/**
	 * class constructor
	 */
	public function new() 
	{
		super(HTMLConstants.HTML_OBJECT_TAG_NAME);
		
		_pluginReady = false;
		intrinsicHeight = HTML_OBJECT_INTRINSIC_HEIGHT;
		intrinsicWidth = HTML_OBJECT_INTRISIC_WIDTH;
		intrinsicRatio = intrinsicWidth / intrinsicHeight;
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////
	// OVERRIDEN PUBLIC METHODS
	//////////////////////////////////////////////////////////////////////////////////////////
	
	override public function setAttribute(name:String, value:String):Void
	{
		if (name == HTMLConstants.HTML_DATA_ATTRIBUTE_NAME)
		{
			data = value;
		}
		else
		{
			super.setAttribute(name, value);
		}
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////
	// PUBLIC RENDERING TREE METHODS
	//////////////////////////////////////////////////////////////////////////////////////////
	
	/**
	 * Overriden, as when attached, the plugin might need to
	 * be instantiated.
	 * 
	 * Plugins instantiated via an object tag are considered
	 * visual and are only instantiated if the object
	 * element is supposed to be rendered
	 */
	override public function attach(recursive:Bool):Void
	{
		super.attach(recursive);
		
		//check that the object tag should be rendered.
		//Don't check if element renderer is not null, as
		//the element renderer for this is only created when
		//the plugin is ready
		if (isRendered() == true)
		{
			createPlugin();
		}
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////
	// OVERRIDEN PUBLIC DOM METHODS
	//////////////////////////////////////////////////////////////////////////////////////////

	/**
	 * overriden as when aded to the DOM,
	 * if a data attribute is given, the resource
	 * is fetched
	 */
	override private function addedToDOM():Void
	{
		super.addedToDOM();
		
		if (data != null)
		{
			//for now only SWF files are supported
			if (data.indexOf(SWF_FILE_EXTENSION) != -1)
			{
				//start loading the resource, the resource
				//need to be completely loaded before
				//the plugin is instantiated
				ResourceManager.getSWFResource(data);
			}
		}
	}
	
	
	/**
	 * Overriden as when removed from DOM, the plugin
	 * might need to be destroyed.
	 * 
	 * If the plugin is only removed from rendering
	 * tree, for instance by setting its 'display' style
	 * to 'none', it is not deleted as it is assumed
	 * that it might be shown again
	 */
	override public function removedFromDOM():Void
	{
		super.removedFromDOM();
		deletePlugin();
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////
	// PRIVATE PLUGIN METHODS
	//////////////////////////////////////////////////////////////////////////////////////////
	
	/**
	 * Instantiate a third-party
	 * plugin if necessary
	 */
	private function createPlugin():Void
	{
		//prevent re-instantiating a plugin
		if (plugin != null)
		{
			return;
		}
		
		//an url for the resource must be provided
		if (data != null)
		{
			//check that the url contain swf file, for now
			//this is the only supported type
			if (data.indexOf(SWF_FILE_EXTENSION) != -1)
			{
				//retrieve the resource the plugin will use
				var resource:NativeHttp = ResourceManager.getSWFResource(data);
				
				//if it couldn't be loaded, don't create the plugin
				if (resource.error == true)
				{
					return;
				}
				//if the resource is not yet loaded, 
				//wait for its load end
				if (resource.complete == false)
				{
					resource.addEventListener(EventConstants.LOAD, onPluginResourceLoaded);
					return;
				}
				
				var params:Hash<String> = new Hash<String>();
				
				//retrive all the name/value of the child param tags
				var length:Int = childNodes.length;
				for (i in 0...length)
				{
					var child:HTMLElement = childNodes[i];
					if (child.tagName == HTMLConstants.HTML_PARAM_TAG_NAME)
					{
						var name:String = child.getAttribute(HTMLConstants.HTML_NAME_ATTRIBUTE_NAME);
						var value:String = child.getAttribute(HTMLConstants.HTML_VALUE_ATTRIBUTE_NAME);
						
						if (name != null && value != null)
						{
							params.set(name, value);
						}
					}
				}
				
				//retrive all the attributes of this HTMLElement
				var elementAttributes:Hash<String> = new Hash<String>();
				for (i in 0...attributes.length)
				{
					var attr:Attr<HTMLElement> = attributes.item(i);
					elementAttributes.set(attr.name, attr.value);
				}
				
				//instantiate the plugin, for now hard-coded SWF plugin
				plugin = new SWFPlugin(elementAttributes, params, onLoadComplete, onLoadError);
			}
		}
	}
	
	/**
	 * Dispose of the plugin
	 * 
	 * TODO 2:  for now, only deleted
	 * when node removed from DOM, should
	 * add more conditions, like for instance
	 * change of data attribute value
	 */
	private function deletePlugin():Void
	{
		//no need to delete the plugin
		//if the node is still attached to
		//the DOM
		if (parentNode != null)
		{
			return;
		}
		
		if (plugin != null)
		{
			_pluginReady = false;
			plugin.dispose();
			plugin = null;
		}
	}
	
	/**
	 * called when the resource necessary
	 * to instantiate the plugin was loaded
	 */
	private function onPluginResourceLoaded(e:Event):Void
	{
		e.target.removeEventListener(EventConstants.LOAD, onPluginResourceLoaded);
		//try to create the plugin now that the resource is ready
		createPlugin();
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////
	// OVERRIDEN PRIVATE RENDERING METHODS
	//////////////////////////////////////////////////////////////////////////////////////////
	
	/**
	 * Instantiate an object specific renderer, if the plugin
	 * is ready to be used
	 * 
	 * TODO 2 : should display fallback content if plugin
	 * not ready
	 */
	override private function createElementRenderer():Void
	{
		if (_pluginReady == true)
		{
			elementRenderer = new ObjectRenderer(this);
		}
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////
	// PRIVATE LOADING METHOD
	//////////////////////////////////////////////////////////////////////////////////////////
	
	/**
	 * Called by the plugin when it is ready
	 */
	private function onLoadComplete():Void
	{
		_pluginReady = true;
		
		//set the element renderer to be updated,
		//now that the plugin is ready, it can be created
		invalidateElementRenderer();
		
		var loadEvent:UIEvent = new UIEvent();
		loadEvent.initUIEvent(EventConstants.LOAD, false, false, null, 0.0);
		dispatchEvent(loadEvent);
	}
	
	/**
	 * Called by the plugin when there
	 * was an error preventing it
	 * from working
	 */
	private function onLoadError():Void
	{
		_pluginReady = false;
		
		var errorEvent:UIEvent = new UIEvent();
		errorEvent.initUIEvent(EventConstants.ERROR, false, false, null, 0.0);
		dispatchEvent(errorEvent);
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////
	// IDL SETTERS/GETTERS
	//////////////////////////////////////////////////////////////////////////////////////////
	
	private function set_data(value:String):String
	{
		super.setAttribute(HTMLConstants.HTML_DATA_ATTRIBUTE_NAME, value);
		return value;
	}
	
	private function get_data():String
	{
		return getAttribute(HTMLConstants.HTML_DATA_ATTRIBUTE_NAME);
	}
	
}