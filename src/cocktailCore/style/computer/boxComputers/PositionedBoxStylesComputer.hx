/*
	This file is part of Cocktail http://www.silexlabs.org/groups/labs/cocktail/
	This project is © 2010-2011 Silex Labs and is released under the GPL License:
	This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License (GPL) as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version. 
	This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
	To read the license please visit http://www.gnu.org/copyleft/gpl.html
*/
package cocktailCore.style.computer.boxComputers;

import cocktailCore.style.abstract.AbstractStyle;
import cocktailCore.style.computer.BoxStylesComputer;
import cocktail.style.StyleData;
import cocktailCore.style.StyleData;
import haxe.Log;

/**
 * ...
 * @author Yannick DOMINGUEZ
 */
class PositionedBoxStylesComputer extends BoxStylesComputer
{

	public function new() 
	{
		super();
	}
	

	override private function measurePositionOffsets(style:AbstractStyle, containingDOMElementData:ContainingDOMElementData):Void
	{
		super.measurePositionOffsets(style, containingDOMElementData);
		
		if (style.width == DimensionStyleValue.auto)
		{
			if (style.left != PositionOffsetStyleValue.auto && style.right != PositionOffsetStyleValue.auto)
			{
				var computedStyle:ComputedStyleData = style.computedStyle;
				style.computedStyle.width = containingDOMElementData.width - computedStyle.left - computedStyle.right - computedStyle.paddingLeft - computedStyle.paddingRight - computedStyle.marginLeft - computedStyle.marginRight; 
			}
		}
		
		if (style.height == DimensionStyleValue.auto)
		{
			if (style.top != PositionOffsetStyleValue.auto && style.bottom != PositionOffsetStyleValue.auto)
			{
				var computedStyle:ComputedStyleData = style.computedStyle;
				style.computedStyle.height = containingDOMElementData.height - computedStyle.top - computedStyle.bottom - computedStyle.paddingTop - computedStyle.paddingBottom - computedStyle.marginTop - computedStyle.marginBottom;

			}
		}
		
	}
	
}