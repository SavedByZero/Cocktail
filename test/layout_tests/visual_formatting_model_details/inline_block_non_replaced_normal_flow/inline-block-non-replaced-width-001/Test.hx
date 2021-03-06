/*
 * Cocktail, HTML rendering engine
 * http://haxe.org/com/libs/cocktail
 *
 * Copyright (c) Silex Labs
 * Cocktail is available under the MIT license
 * http://www.silexlabs.org/labs/cocktail-licensing/
*/

package ;
import js.Lib;

/**
 * TODO : doesn't work because inline block is not wrapped in container block, 
 * works without the "p" element
 */
class Test 
{
	public static function main()
	{	
		new Test();
	}
	
	public function new()
	{
		var test = '<div><p>Test passes if there is no red visible on the page.</p>';
		test += '<div style="background-color:red; display:inline-block; color:blue; font-size:1in; width:auto;">X';
		test += '</div></div>';
		
		Lib.document.body.innerHTML = test;
	}
}