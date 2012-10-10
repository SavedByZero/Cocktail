/*
 * Cocktail, HTML rendering engine
 * http://haxe.org/com/libs/cocktail
 *
 * Copyright (c) Silex Labs
 * Cocktail is available under the MIT license
 * http://www.silexlabs.org/labs/cocktail-licensing/
*/
package cocktail.core.layer;

using cocktail.core.utils.Utils;
import cocktail.core.dom.Document;
import cocktail.core.dom.Node;
import cocktail.core.html.HTMLDocument;
import cocktail.core.html.HTMLElement;
import cocktail.core.html.ScrollBar;
import cocktail.core.renderer.ElementRenderer;
import cocktail.core.layout.computer.VisualEffectStylesComputer;
import cocktail.core.css.CoreStyle;
import cocktail.core.layout.LayoutData;
import cocktail.core.geom.Matrix;
import cocktail.core.graphics.GraphicsContext;
import cocktail.core.utils.FastNode;
import cocktail.port.NativeElement;
import cocktail.core.geom.GeomData;
import cocktail.core.css.CSSData;
import haxe.Log;
import haxe.Stack;

/**
 * Each ElementRenderer belongs to a LayerRenderer representing
 * its position in the document in the z axis. LayerRenderer
 * are instantiated by ElementRenderer. Not all ElementRenderer
 * create their own layer, only those which can potentially overlap
 * other ElementRenderer, for instance ElementRenderer with a
 * non-static position (absolute, relative or fixed).
 * 
 * ElementRenderer which don't create their own LayerRenderer use
 * the one of their parent
 * 
 * The created LayerRenderers form the LayerRenderer tree,
 * paralleling the rendering tree.
 * 
 * The LayerRenderer tree manages the rendering order of the rendering tree
 * 
 * Each LayerRenderer has a reference to a graphic context which is passed
 * to each ElementRenderer so that they can paint themselves onto it
 * 
 * The LayerRenderer tree is in charge of managing the stacking contexts
 * of the document which is a representation of the document z-index
 * as a stack of ElementRenderers, ordered by z-index.
 * 
 * LayerRenderer may establish a new stacking context, from the CSS 2.1
 * w3c spec : 
	 *  The order in which the rendering tree is painted onto the canvas 
	 * is described in terms of stacking contexts. Stacking contexts can contain
	 * further stacking contexts. A stacking context is atomic from the point of 
	 * view of its parent stacking context; boxes in other stacking contexts may
	 * not come between any of its boxes.
	 * 
	 * Each box belongs to one stacking context. Each positioned box in
	 * a given stacking context has an integer stack level, which is its position 
	 * on the z-axis relative other stack levels within the same stacking context.
	 * Boxes with greater stack levels are always formatted in front of boxes with
	 * lower stack levels. Boxes may have negative stack levels. Boxes with the same 
	 * stack level in a stacking context are stacked back-to-front according
	 * to document tree order.
	 * 
	 * The root element forms the root stacking context. Other stacking
	 * contexts are generated by any positioned element (including relatively
	 * positioned elements) having a computed value of 'z-index' other than 'auto'.
 * 
 * Ths structure of the LayerRenderer tree mirrors the rendering tree.
 * The stacking contexts are represented as arrays of LayerRenderer
 * ordered by the z-index of its LayerRenderer. To obtain
 * the stacking contexts, before rendering, each LayerRenderer store its child
 * layers in array representing their stacking context. For instance, if a child
 * has a negative z-index, it will be stored in the negative stacking context array.
 * 
 * @author Yannick DOMINGUEZ
 */
class LayerRenderer extends FastNode<LayerRenderer>
{
	/**
	 * A reference to the ElementRenderer which
	 * created the LayerRenderer
	 */
	public var rootElementRenderer(default, null):ElementRenderer;
	
	/**
	 * Holds a reference to all of the child LayerRender which have a z-index computed 
	 * value of 0 or auto, which means that they are rendered in tree
	 * order of the DOM tree.
	 */
	public var zeroAndAutoZIndexChildLayerRenderers(default, null):Array<LayerRenderer>;
	
	/**
	 * Holds a reference to all of the child LayerRenderer which have a computed z-index
	 * superior to 0. They are ordered in this array from least positive to most positive,
	 * which is the order which they must use to be rendered
	 */
	public var positiveZIndexChildLayerRenderers(default, null):Array<LayerRenderer>;
	
	/**
	 * same as above for child LayerRenderer with a negative computed z-index. The array is
	 * ordered form most negative to least negative
	 */
	public var negativeZIndexChildLayerRenderers(default, null):Array<LayerRenderer>;
	
	/**
	 * Holds all the stacking context of the first
	 * parent layer renderer establishing a stacking
	 * context, from most negative to most negative
	 */
	private var _parentStackingContexts:Array<LayerRenderer>;
	
	/**
	 * The graphics context onto which all the ElementRenderers
	 * belonging to this LayerRenderer are painted onto
	 */
	public var graphicsContext(default, null):GraphicsContext;
	
	/**
	 * Store the current width of the window. Used to check if the window
	 * changed size in between renderings
	 */
	private var _windowWidth:Int;
	
	/**
	 * Same as windowWidth for height
	 */
	private var _windowHeight:Int;
	
	/**
	 * A flag determining wether this LayerRenderer has its own
	 * GraphicsContext or use the one of its parent. It helps
	 * to determine if this LayerRenderer is responsible to perform
	 * operation such as clearing its graphics context when rendering
	 */
	public var hasOwnGraphicsContext(default, null):Bool;
	
	/**
	 * A flag determining wether the layer renderer needs
	 * to do any rendering. As soon as an ElementRenderer
	 * from the LayerRenderer needs rendering, its
	 * LayerRenderer needs rendering
	 */
	private var _needsRendering:Bool;
	
	/**
	 * A flag determining wether the layer should
	 * update its graphics context, it is the case for
	 * instance when the layer is attached to the rendering
	 * tree
	 */
	private var _needsGraphicsContextUpdate:Bool;
	
	/**
	 * A flag determining wether the layer should update
	 * its arrays of stacking context before next rendering
	 */
	private var _needsStackingContextUpdate:Bool;
	
	/**
	 * A flag determining for a LayerRenderer which 
	 * has its own graphic context, if the size of the
	 * bitmap data of its grapic context should be updated.
	 * 
	 * It is the case when the size of the viewport changes
	 * of when a new graphics context is created for this 
	 * LayerRenderer
	 */
	private var _needsBitmapSizeUpdate:Bool;
	
	/**
	 * class constructor. init class attributes
	 */
	public function new(rootElementRenderer:ElementRenderer) 
	{
		super();
		
		this.rootElementRenderer = rootElementRenderer;
		zeroAndAutoZIndexChildLayerRenderers = new Array<LayerRenderer>();
		positiveZIndexChildLayerRenderers = new Array<LayerRenderer>();
		negativeZIndexChildLayerRenderers = new Array<LayerRenderer>();
		_parentStackingContexts = new Array<LayerRenderer>();
		
		hasOwnGraphicsContext = false;
		
		_needsRendering = true;
		_needsBitmapSizeUpdate = true;
		_needsGraphicsContextUpdate = true;
		_needsStackingContextUpdate = true;
		
		_windowWidth = 0;
		_windowHeight = 0;
	}
	
	/**
	 * clean up method
	 */
	public function dispose():Void
	{
		zeroAndAutoZIndexChildLayerRenderers = null;
		positiveZIndexChildLayerRenderers = null;
		negativeZIndexChildLayerRenderers = null;
		rootElementRenderer = null;
		graphicsContext = null;
	}
	
	/////////////////////////////////
	// PUBLIC METHOD
	////////////////////////////////
	
	/**
	 * Called by the document when the graphics
	 * context tree needs to be updated. It
	 * can for instance happen when
	 * a layer which didn't have its own
	 * graphic context should now have it
	 */
	public function updateGraphicsContext(force:Bool):Void
	{
		if (_needsGraphicsContextUpdate == true || force == true)
		{
			_needsGraphicsContextUpdate = false;
			
			if (graphicsContext == null)
			{
				attach();
				return;
			}
			else if (hasOwnGraphicsContext != establishesNewGraphicsContext())
			{
				detach();
				attach();
				return;
			}
		}
		
		var child:LayerRenderer = firstChild;
		while(child != null)
		{
			child.updateGraphicsContext(force);
			child = child.nextSibling;
		}
	}
	
	/**
	 * Called by the docuement before rendering when
	 * the stacking context of the layer tree needs to
	 * be updated
	 */
	public function updateStackingContext():Void
	{
		//TODO 1 : for now, need to update all else some
		//that should get updated don't
		//if (_needsStackingContextUpdate == true)
		//{
			_needsStackingContextUpdate = false;
			
			//reset all stacking context
			negativeZIndexChildLayerRenderers.clear();
			zeroAndAutoZIndexChildLayerRenderers.clear();
			positiveZIndexChildLayerRenderers.clear();
			
			//only layer renderer which establish themselve a stacking context
			//can have child stacking context, this excludes layer with an 'auto'
			//z-index
			if (establishesNewStackingContext() == true)
			{
				doUpdateStackingContext(this, negativeZIndexChildLayerRenderers, zeroAndAutoZIndexChildLayerRenderers, positiveZIndexChildLayerRenderers); 
			}
		//}
		
		//traverse all the layer renderer tree
		var child:LayerRenderer = firstChild;
		while(child != null)
		{
			child.updateStackingContext();
			child = child.nextSibling;
		}
	}
	
	/**
	 * Actually update the stacking contexts child of this layer renderer,
	 * by passing its stackinbg contexts array by reference
	 */
	private function doUpdateStackingContext(rootLayerRenderer:LayerRenderer,
	negativeChildContext:Array<LayerRenderer>,
	autoAndZeroChildContext:Array<LayerRenderer>,
	positiveChildContext:Array<LayerRenderer>)
	{
		var child:LayerRenderer = rootLayerRenderer.firstChild;
		while(child != null)
		{
			//check the computed z-index of the ElementRenderer which
			//instantiated the child LayerRenderer
			//to find into which array the child must be inserted
			switch(child.rootElementRenderer.coreStyle.zIndex)
			{
				case KEYWORD(value):
					if (value != AUTO)
					{
						throw 'Illegal value for z-index style';
					}
					//the z-index is 'auto'
					autoAndZeroChildContext.push(child);
					
				case INTEGER(value):
					if (value == 0)
					{
						autoAndZeroChildContext.push(child);
					}
					else if (value > 0)
					{
						insertPositiveZIndexChildRenderer(child, value, positiveChildContext);
					}
					else if (value < 0)
					{
						insertNegativeZIndexChildRenderer(child, value, negativeChildContext);
					}
					
				default:
					throw 'Illegal value for z-index style';
			}
			
			//if the child doesn't establish a stacking context, then its child
			//layers should also be added to this layer renderer
			if (child.establishesNewStackingContext() == false)
			{
				doUpdateStackingContext(child, negativeChildContext, autoAndZeroChildContext, positiveChildContext);
			}
			
			child = child.nextSibling;
		}
	}
	
	/////////////////////////////////
	// PUBLIC INVALIDATION METHOD
	////////////////////////////////
	
	/**
	 * Schedule an update of the graphics context
	 * tree using the document
	 * 
	 * @param force wether the whole graphics context tree
	 * should be updated. Happens when inserting/removing
	 * a compositing layer
	 */
	public function invalidateGraphicsContext(force:Bool):Void
	{
		_needsGraphicsContextUpdate = true;
		var htmlDocument:HTMLDocument = cast(rootElementRenderer.domNode.ownerDocument);
		htmlDocument.invalidationManager.invalidateGraphicsContextTree(force);
	}
	
	/**
	 * Invalidate the rendering of this layer.
	 * If this layer has its own graphic context,
	 * each child layer using the same graphics
	 * context is also invalidated
	 */
	public function invalidateRendering():Void
	{
		_needsRendering = true;
		
		if (hasOwnGraphicsContext == true)
		{
			invalidateChildLayerRenderer(this);
		}
		else
		{
			//if the child has no graphics context, 
			//invalidate instead the first parent which does
			if (parentNode != null)
			{
				var parent = parentNode;
				while(parent.establishesNewGraphicsContext() == false)
				{
					parent = parent.parentNode;
				}
				
				parent.invalidateRendering();
			}
		}
		
		var htmlDocument:HTMLDocument = cast(rootElementRenderer.domNode.ownerDocument);
		htmlDocument.invalidationManager.invalidateRendering();
	}
	
	/**
	 * only invalidate self, used when invalidating
	 * children to prevent infinite loop
	 */
	public function invalidateOwnRendering():Void
	{
		_needsRendering = true;
	}
	
	/**
	 * Schedule an update of the stacking
	 * contexts using the docuement
	 */
	public function invalidateStackingContext():Void
	{	
		negativeZIndexChildLayerRenderers.clear();
		zeroAndAutoZIndexChildLayerRenderers.clear();
		positiveZIndexChildLayerRenderers.clear();
		
		var htmlDocument:HTMLDocument = cast(rootElementRenderer.domNode.ownerDocument);
		htmlDocument.invalidationManager.invalidateStackingContexts();
		
		_needsStackingContextUpdate = true;
	}
	
	/////////////////////////////////
	// PRIVATE INVALIDATION METHOD
	////////////////////////////////
	
	/**
	 * Invalidate all children with
	 * the same graphic context as 
	 * this one
	 */
	private function invalidateChildLayerRenderer(rootLayer:LayerRenderer):Void
	{
		var child:LayerRenderer = rootLayer.firstChild;
		while (child != null)
		{
			if (child.hasOwnGraphicsContext == false)
			{
				child.invalidateOwnRendering();
				invalidateChildLayerRenderer(child);
			}
			child = child.nextSibling;
		}
	}
	
	/////////////////////////////////
	// OVERRIDEN PUBLIC METHODS
	////////////////////////////////
	
	/**
	 * Overriden to schedule updates
	 */ 
	override public function appendChild(newChild:LayerRenderer):Void
	{
		super.appendChild(newChild);
		
		invalidateStackingContext();
		newChild.invalidateStackingContext();
		
		//needs to update graphic context, in case the new child
		//changes it
		//
		//TODO 3 : eventually, it might not be needed to invalidate
		//every time
		newChild.invalidateGraphicsContext(newChild.isCompositingLayer());
	}
	
	/**
	 * Overriden to schedule updates
	 */ 
	override public function insertBefore(newChild:LayerRenderer, refChild:LayerRenderer):Void
	{
		super.insertBefore(newChild, refChild);
		
		//if the refChild is null, then the new child
		//was inserted with appendChild and already invalidated
		if (refChild == null)
		{
			return;
		}
		
		invalidateStackingContext();
		newChild.invalidateStackingContext();
		newChild.invalidateRendering();
		//needs to update graphic context, in case the new child
		//changes it
		//
		//TODO 3 : eventually, it might not be needed to invalidate
		//every time
		newChild.invalidateGraphicsContext(newChild.isCompositingLayer());
	}
	
	/**
	 * Overriden to schedule updates
	 */ 
	override public function removeChild(oldChild:LayerRenderer):Void
	{
		//need to update graphic context after removing a child
		//as it might trigger graphic contex creation/deletion
		oldChild.invalidateGraphicsContext(oldChild.isCompositingLayer());
		oldChild.invalidateStackingContext();
		oldChild.invalidateRendering();
		invalidateStackingContext();
		
		oldChild.detach();

		super.removeChild(oldChild);
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////
	// PUBLIC ATTACHEMENT METHODS
	//////////////////////////////////////////////////////////////////////////////////////////
	
	/**
	 * For a LayerRenderer, attach is used to 
	 * get a reference to a GraphicsContext to
	 * paint onto
	 */
	public function attach():Void
	{
		attachGraphicsContext();

		//attach all its children recursively
		var child:LayerRenderer = firstChild;
		while (child != null)
		{
			child.attach();
			child = child.nextSibling;
		}
	}
	
	/**
	 * For a LayerRenderer, detach is used
	 * to dereference the GraphicsContext
	 */
	public function detach():Void
	{
		var child:LayerRenderer = firstChild;
		while (child != null)
		{
			child.detach();
			child = child.nextSibling;
		}
		
		detachGraphicsContext();
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////
	// PRIVATE ATTACHEMENT METHODS
	//////////////////////////////////////////////////////////////////////////////////////////
	
	/**
	 * Attach a graphics context if necessary
	 */
	private function attachGraphicsContext():Void
	{
		if (parentNode != null)
		{
			createGraphicsContext(parentNode.graphicsContext);
		}
	}
	
	/**
	 * Detach the GraphicContext
	 */
	private function detachGraphicsContext():Void 
	{
		//if this LayerRenderer instantiated its own
		//GraphicContext, it is responsible for disposing of it
		if (hasOwnGraphicsContext == true)
		{
			parentNode.graphicsContext.removeChild(graphicsContext);
			graphicsContext.dispose();
			hasOwnGraphicsContext = false;
		}
		
		graphicsContext = null;
	}
	
	/**
	 * Create a new GraphicsContext for this LayerRenderer
	 * or use the one of its parent
	 */
	private function createGraphicsContext(parentGraphicsContext:GraphicsContext):Void
	{
		if (establishesNewGraphicsContext() == true)
		{
			graphicsContext = new GraphicsContext(this);
			_needsBitmapSizeUpdate = true;
			hasOwnGraphicsContext = true;
			
			//get all the child stacking contexts of the first parent
			//establishing a stacking context, this layer belongs to those
			//stacking contexts
			var parentStackingContexts:Array<LayerRenderer> = getParentStackingContext();
			
			var foundSelf:Bool = false;
			var inserted:Bool = false;
			
			//loop to find the position where to insert this new graphics context, it must
			//be inserted before its first sibling with a superior z-index. The sibling
			//must also establish a new graphics context
			var length:Int = parentStackingContexts.length;
			for (i in 0...length)
			{
				var child:LayerRenderer = parentStackingContexts[i];
				
				if (foundSelf == true)
				{
					if (child.graphicsContext != null)
					{
						if (child.hasOwnGraphicsContext == true)
						{
							parentGraphicsContext.insertBefore(graphicsContext, child.graphicsContext);
							inserted = true;
							break;
						}
							
					}
				}
				
				//when this layer is found, the next layer
				//it will be inserted into the next layer
				//establishing a stacking context
				if (child == this)
				{
					foundSelf = true;
				}
			}
			
			//here the new graphics context is
			//inserted last
			if (inserted == false)
			{
				parentGraphicsContext.appendChild(graphicsContext);
			}
			
		}
		else
		{
			graphicsContext = parentGraphicsContext;
		}
	}
	
	/**
	 * Wether this LayerRenderer should create its
	 * own GraphicsContext
	 */
	private function establishesNewGraphicsContext():Bool
	{
		//layer must establish a stacking context to have
		//own graphic context
		//TODO 2 : not sure about this one, seems to work
		//so far
		if (establishesNewStackingContext() == false)
		{
			return false;
		}
		else if (hasCompositingLayerDescendant(this) == true)
		{
			return true;
		}
		else if (hasCompositingLayerSibling() == true)
		{
			return true;
		}
		
		return false;
	}
	
	/**
	 * Return wether a given layer has a descendant which is
	 * a compositing layer by traversing the layer tree
	 * recursively.
	 * 
	 * If it does, it must then have its own graphic context
	 * to respect z-index when compositing
	 */
	private function hasCompositingLayerDescendant(rootLayerRenderer:LayerRenderer):Bool
	{
		var child:LayerRenderer = rootLayerRenderer.firstChild;
		while (child != null)
		{
			if (child.isCompositingLayer() == true)
			{
				return true;
			}
			else if (child.firstChild != null)
			{
				var hasCompositingLayer:Bool = hasCompositingLayerDescendant(child);
				if (hasCompositingLayer == true)
				{
					return true;
				}
			}
			
			child = child.nextSibling;
		}
		
		return false;
	}
	
	/**
	 * return wether this layer has a sibling stacking
	 * context which
	 * is established by a compositing layer which has a lower z-index
	 * than itself.
	 * 
	 * If the layer has such a sibling, it means it is
	 * composited on top of a compositing layer and
	 * it must have its own graphic context to respect
	 * z-index
	 */
	private function hasCompositingLayerSibling():Bool
	{
		var parentStackingContexts:Array<LayerRenderer> = getParentStackingContext();
		
		var length:Int = parentStackingContexts.length;
		for (i in 0...length)
		{
			var child:LayerRenderer = parentStackingContexts[i];
			//if this layer is found before any compositing layer
			//then it is rendred below and doesn't need a compositing layer
			if (child == this)
			{
				return false;
			}
			else if (child.isCompositingLayer() == true)
			{
				return true;
			}
		}
		
		return false;
	}
	
	/////////////////////////////////
	// PUBLIC HELPER METHODS
	////////////////////////////////
	
	/**
	 * Wether this layer is a compositing layer,
	 * meaning it always have its own graphic context.
	 * For instance, a GPU accelerated video layer is always a
	 * compositing layer
	 */
	public function isCompositingLayer():Bool
	{
		return false;
	}
	
	/////////////////////////////////
	// PUBLIC RENDERING METHODS
	////////////////////////////////
	
	/**
	 * Starts the rendering of this LayerRenderer.
	 * Render all its child layers and its root ElementRenderer
	 * 
	 * @param windowWidth the current width of the window
	 * @param windowHeight the current height of the window
	 */
	public function render(windowWidth:Int, windowHeight:Int ):Void
	{
		//if the graphic context was instantiated/re-instantiated
		//since last rendering, the size of its bitmap data should be
		//updated with the viewport's dimensions
		if (_needsBitmapSizeUpdate == true)
		{
			if (hasOwnGraphicsContext == true)
			{
				initBitmapData(windowWidth, windowHeight);
			}
			_needsBitmapSizeUpdate = false;
			
			//invalidate rendering of this layer and all layers sharing
			//the same graphic context
			invalidateRendering();
		}
		//else update the dimension of the bitmap data if the window size changed
		//since last rendering
		else if (windowWidth != _windowWidth || windowHeight != _windowHeight)
		{
			//only update the GraphicContext if it was created
			//by this LayerRenderer
			if (hasOwnGraphicsContext == true)
			{
				initBitmapData(windowWidth, windowHeight);
				_needsBitmapSizeUpdate = false;
			}
			
			//invalidate if the size of the viewport
			//changed
			invalidateRendering();
		}
		
		_windowWidth = windowWidth;
		_windowHeight = windowHeight;
		
		//only clear if a rendering is necessary
		if (_needsRendering == true)
		{
			//only clear the bitmaps if the GraphicsContext
			//was created by this LayerRenderer
			if (hasOwnGraphicsContext == true)
			{
				//reset the bitmap
				clear();
			}
		}
	
		//init transparency on the graphicContext if the element is transparent. Everything
		//painted afterwards will have an alpha equal to the opacity style
		//
		//TODO 1 : will not work if child layer also have alpha, alpha
		//won't be combined properly. Should GraphicsContext have offscreen bitmap
		//for each transparent layer and compose them when transparency end ?
		if (rootElementRenderer.isTransparent() == true)
		{
			var coreStyle:CoreStyle = rootElementRenderer.coreStyle;
			
			//get the current opacity value
			var opacity:Float = 0.0;
			switch(coreStyle.opacity)
			{
				case NUMBER(value):
					opacity = value;
					
				case ABSOLUTE_LENGTH(value):
					opacity = value;
					
				default:	
			}
			
			graphicsContext.graphics.beginTransparency(opacity);
		}
		
		//render first negative z-index child LayerRenderer from most
		//negative to least negative
		var negativeChildLength:Int = negativeZIndexChildLayerRenderers.length;
		for (i in 0...negativeChildLength)
		{
			negativeZIndexChildLayerRenderers[i].render(windowWidth, windowHeight);
		}
		
		//only render if necessary. This only applies to layer which have
		//their own graphic context, layer which don't always gets re-painted
		if (_needsRendering == true)
		{
			//render the rootElementRenderer itself which will also
			//render all ElementRenderer belonging to this LayerRenderer
			rootElementRenderer.render(graphicsContext);
		}
		
		//render zero and auto z-index child LayerRenderer, in tree order
		var childLength:Int = zeroAndAutoZIndexChildLayerRenderers.length;
		for (i in 0...childLength)
		{
			zeroAndAutoZIndexChildLayerRenderers[i].render(windowWidth, windowHeight);
		}
		
		//render all the positive LayerRenderer from least positive to 
		//most positive
		var positiveChildLength:Int = positiveZIndexChildLayerRenderers.length;
		for (i in 0...positiveChildLength)
		{
			positiveZIndexChildLayerRenderers[i].render(windowWidth, windowHeight);
		}
		
		//stop transparency so that subsequent painted element won't be transparent
		//if they don't themselves have an opacity inferior to 1
		if (rootElementRenderer.isTransparent() == true)
		{
			graphicsContext.graphics.endTransparency();
		}
		
		//scrollbars are always rendered last as they should always be the top
		//element of their layer
		rootElementRenderer.renderScrollBars(graphicsContext, windowWidth, windowHeight);
		
		//only render if necessary
		if (_needsRendering == true)
		{
			//apply transformations to the layer if needed
			if (rootElementRenderer.isTransformed() == true)
			{
				//TODO 2 : should already be computed at this point
				VisualEffectStylesComputer.compute(rootElementRenderer.coreStyle);
				graphicsContext.graphics.transform(getTransformationMatrix(graphicsContext));
			}
		}
		
		//layer no longer needs rendering
		_needsRendering = false;
	}
	
	/////////////////////////////////
	// PRIVATE RENDERING METHODS
	////////////////////////////////
	
	/**
	 * Refresh the size of the graphics context's
	 * bitmap data
	 */
	private function initBitmapData(width:Int, height:Int):Void
	{
		graphicsContext.graphics.initBitmapData(width, height);
	}
	
	/**
	 * Reset the bitmap
	 */
	private function clear():Void
	{
		graphicsContext.graphics.clear();
	}
	
	/**
	 * Compute all the transformation that should be applied to this LayerRenderer
	 * and return it as a transformation matrix
	 */
	private function getTransformationMatrix(graphicContext:GraphicsContext):Matrix
	{
		var relativeOffset:PointVO = rootElementRenderer.getRelativeOffset();
		var concatenatedMatrix:Matrix = getConcatenatedMatrix(rootElementRenderer.coreStyle.usedValues.transform, relativeOffset);
		
		//apply relative positioning as well
		concatenatedMatrix.translate(relativeOffset.x, relativeOffset.y);
		
		return concatenatedMatrix;
	}
	
	/**
	 * Concatenate the transformation matrix obtained with the
	 * transform and transform-origin styles with the current
	 * transformations applied to the root element renderer, such as for 
	 * instance its position in the global space
	 */
	private function getConcatenatedMatrix(matrix:Matrix, relativeOffset:PointVO):Matrix
	{
		var currentMatrix:Matrix = new Matrix();
		var globalBounds:RectangleVO = rootElementRenderer.globalBounds;
		
		//translate to the coordinate system of the root element renderer
		currentMatrix.translate(globalBounds.x + relativeOffset.x, globalBounds.y + relativeOffset.y);
		
		currentMatrix.concatenate(matrix);
		
		//translate back from the coordinate system of the root element renderer
		currentMatrix.translate((globalBounds.x + relativeOffset.x) * -1, (globalBounds.y + relativeOffset.y) * -1);
		return currentMatrix;
	}
	
	/////////////////////////////////
	// PRIVATE LAYER TREE METHODS
	////////////////////////////////
	
	/**
	 * Returns all the stacking contexts of the
	 * parent ordered by z-index
	 */
	private function getParentStackingContext():Array<LayerRenderer>
	{
		//find the first parent establishing a stacking context
		var parentStackingContext:LayerRenderer = parentNode;
		while (parentStackingContext.establishesNewStackingContext() == false)
		{
			parentStackingContext = parentStackingContext.parentNode;
		}
		
		//get all layer in parent stacking context in z-order
		_parentStackingContexts.clear();
		var length:Int = parentStackingContext.negativeZIndexChildLayerRenderers.length;
		for (i in 0...length)
		{
			_parentStackingContexts.push(parentStackingContext.negativeZIndexChildLayerRenderers[i]);
		}
		length = parentStackingContext.zeroAndAutoZIndexChildLayerRenderers.length;
		for (i in 0...length)
		{
			_parentStackingContexts.push(parentStackingContext.zeroAndAutoZIndexChildLayerRenderers[i]);
		}
		length = parentStackingContext.positiveZIndexChildLayerRenderers.length;
		for (i in 0...length)
		{
			_parentStackingContexts.push(parentStackingContext.positiveZIndexChildLayerRenderers[i]);
		}
		
		return _parentStackingContexts;
	}
	
	/**
	 * When inserting a new child LayerRenderer in the positive z-index
	 * child LayerRenderer array, it must be inserted at the right index so that
	 * the array is ordered from least positive to most positive
	 */
	private function insertPositiveZIndexChildRenderer(childLayerRenderer:LayerRenderer, rootElementRendererZIndex:Int, positiveZIndexChildLayerRenderers:Array<LayerRenderer>):Void
	{
		//flag checking if the LayerRenderer was already inserted
		//in the array
		var isInserted:Bool = false;
		
		//loop in all the positive z-index array
		var length:Int = positiveZIndexChildLayerRenderers.length;
		for (i in 0...length)
		{
			//get the z-index of the child LayerRenderer at the current index
			var currentRendererZIndex:Int = 0;
			switch(positiveZIndexChildLayerRenderers[i].rootElementRenderer.coreStyle.zIndex)
			{
				case INTEGER(value):
					currentRendererZIndex = value;
					
				default:	
			}
			
			//if the new LayerRenderer has a least positive z-index than the current
			//child it is inserted at this index
			if (rootElementRendererZIndex < currentRendererZIndex)
			{
				positiveZIndexChildLayerRenderers.insert(i, childLayerRenderer);
				isInserted = true;
				break;
			}
		}
		
		//if the new LayerRenderer wasn't inserted, either
		//it is the first item in the array or it has the most positive
		//z-index
		if (isInserted == false)
		{
			positiveZIndexChildLayerRenderers.push(childLayerRenderer);
		}
	}
	
	/**
	 * Follows the same logic as the method above for the negative z-index child
	 * array. The array must be ordered from most negative to least negative
	 */ 
	private function insertNegativeZIndexChildRenderer(childLayerRenderer:LayerRenderer, rootElementRendererZIndex:Int, negativeZIndexChildLayerRenderers:Array<LayerRenderer>):Void
	{
		var isInserted:Bool = false;
		
		var length:Int = negativeZIndexChildLayerRenderers.length;
		for (i in 0...length)
		{
			var currentRendererZIndex:Int = 0;
			
			switch(negativeZIndexChildLayerRenderers[i].rootElementRenderer.coreStyle.zIndex)
			{
				case INTEGER(value):
					currentRendererZIndex = value;
					
				default:	
			}
			
			if (currentRendererZIndex  > rootElementRendererZIndex)
			{
				negativeZIndexChildLayerRenderers.insert(i, childLayerRenderer);
				isInserted = true;
				break;
			}
		}
		
		if (isInserted == false)
		{
			negativeZIndexChildLayerRenderers.push(childLayerRenderer);
		}
	}
	
	/**
	 * Wether this LayerRenderer establishes a new stacking
	 * context. If it does it is responsible for rendering
	 * all the LayerRenderer in the same stacking context, 
	 * and its child LayerRenderer which establish new
	 * stacking context themselves
	 */
	private function establishesNewStackingContext():Bool
	{
		switch(rootElementRenderer.coreStyle.zIndex)
		{
			case KEYWORD(value):
				if (value == AUTO)
				{
					return false;
				}
				
			default:	
		}
		
		return true;
	}
}