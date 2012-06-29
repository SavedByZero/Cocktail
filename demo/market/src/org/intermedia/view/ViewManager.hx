package org.intermedia.view;

import haxe.Firebug;
import js.Lib;
import js.Dom;
import org.intermedia.controller.ApplicationController;
import org.intermedia.model.ApplicationModel;
import org.intermedia.model.Feeds;

/**
 * In charge of instantiating the views, listening to the application model changes and communicating with the controller.
 * 
 * @author Raphael Harmel
 */

class ViewManager
{

	// bodyDOMElement
	private var _body:Body;
	
	//Reference to the header of the application, which is always displayed
	private var _header:HeaderView;
	
	// reference to the menu
	private var _menu:MenuListViewText;
	
	//Ref to the container managing the swippable list view
	private var _swippableListView:SwippableListView;
	
	//Ref to the view displaying full article
	private var _detailView:DetailView;
	
	//Ref to the view displayed when there is a loading error
	//private var _errorView:ErrorView;
	//private var _errorView:HtmlDom;
	
	//listen to model change on it
	private var _applicationModel:ApplicationModel;
	
	//proxies interaction with the model
	private var _applicationController:ApplicationController;
	
	// _currentView is used to store the current view
	private var _currentView:ViewBase;
	
	/**
	 * Store ref to application model and controller. Instantiate headerView, loadingView, swippableView then call init().
	 * 
	 * @param	applicationModel
	 * @param	applicationController
	 */
	public function new(applicationModel:ApplicationModel, applicationController:ApplicationController)
	{
		// Store ref to application model and controller
		_applicationModel = applicationModel;
		_applicationController = applicationController;
		
		// Instantiate body, headerView, loadingView, swippableView
		_body = Lib.document.body;
		ViewManagerStyle.setBodyStyle(_body);
		
		_header = new HeaderView();
		_header.data = Constants.HEADER_HOME_TITLE;
		_header.onBackButtonClick = onHeaderBackButtonPressed;
		_body.appendChild(_header.node);
		
		// init menu
		_menu = new MenuListViewText();
		_menu.displayListBottomLoader = false;
		_body.appendChild(_menu.node);
		_menu.data = [Feeds.FEED_1, Feeds.FEED_2, Feeds.FEED_3];
		
		// init swippable view
		_swippableListView = new SwippableListView();
		
		// attach swippable view to body
		_body.appendChild(_swippableListView.node);
		
		// set _currentView
		_currentView = _swippableListView;
		
		// create detail view
		_detailView = new DetailView();

		// onresize callback
		Lib.window.onresize = function (event:Event) { refreshStyles();};
		
		// call init()
		init();
	}
	
	/**
	 * Sets callback on the model to be notified of model changes.
	 * call loadCellData() on the application controller with thedefault cell number (between 5 to 10)
	 */
	private function init():Void
	{
		// Sets callback on the model to be notified of model changes.
		_applicationModel.onModelStartsLoading = onStartLoading;
		_applicationModel.onModelDataLoadError = onLoadingError;
		_applicationModel.onModelCellDataLoaded = onCellDataLoaded;
		_applicationModel.onModelDetailDataLoaded = onDetailDataLoaded;
		
		
		// Sets callback on the view to be notified of user actions.
		// set menu item selelected callback
		_menu.onListItemSelected = onMenuItemSelectedCallback;
		
		// set swippableView callbacks
		_swippableListView.onListItemSelected = onListItemSelectedCallback;
		_swippableListView.onDataRequest = _applicationController.loadCellData;
		_swippableListView.onHorizontalMove = _menu.moveHorizontally;
		_swippableListView.onHorizontalTweenEnd = _menu.horizontalTweenEnd;
		
		// Call loadCellData() on the application controller with the default cell number (between 5 to 10)
		_applicationController.loadCellData(Feeds.FEED_1.url);
		_applicationController.loadCellData(Feeds.FEED_2.url);
		_applicationController.loadCellData(Feeds.FEED_3.url);
		
	}
	
	/**
	 * on menu item item clicked
	 * 
	 * @param	cellData
	 */
	private function onMenuItemSelectedCallback(cellData:CellData):Void
	{
		_swippableListView.resetInitScrollPosition();
		_swippableListView.index = cellData.id;
	}
	
	/**
	 * on list item selected callback
	 */
	private function onListItemSelectedCallback(cellData:CellData):Void
	{
		// remove swippable view touch events listener
		//_swippableListView.unsetTouchEvents();
		// remove swippableListView and menu and add empty detail view
		_body.removeChild(_swippableListView.node);
		_body.removeChild(_menu.node);

		// create detail view and add it to the body
		_detailView = new DetailView();
		_body.appendChild(_detailView.node);
		
		// set _currentView
		_currentView = _detailView;
		
		// request detail view loading to controller
		onDetailDataLoaded(cellData);
	}
	
	/**
	 * Open the listView and / or refresh its data.
	 * 
	 * @param	cellsData
	 */
	public function onCellDataLoaded(listData:ListData):Void
	{
		// if no more data fetched, remove bottom loader
		if (listData.cells.length == 0) _swippableListView.displayListBottomLoader = false;
		
		// update data
		_swippableListView.data = listData;
		
		// update header zIndex using a workaround so it always visible
		updateZIndexes();
	}
	
	/**
	 * Open the detailView and / or refresh its data. Set displayBackButton on the headerView
	 * 
	 * @param	detailData
	 */
	public function onDetailDataLoaded(detailData:DetailData):Void
	{
		// update detail view data
		_detailView.data = detailData;
		
		// update header title
		_header.data = Constants.HEADER_DETAIL_TITLE;
		
		// display header back button
		_header.displayBackButton = true;
		
		// update header zIndex using a workaround
		setZIndexToMax(_header);
		
		// refresh styles
		refreshStyles();
		
		// hide loader
		_detailView.displayLoading = false;
		
	}
	
	/**
	 * set displayLoading to true on the current view
	 */
	public function onStartLoading():Void
	{
		//_currentView.displayLoading = true;
	}
	
	/**
	 * Display the error view
	 */
	public function onLoadingError(error:Dynamic):Void
	{
		trace("Load error: " + Std.string(error));
		haxe.Firebug.trace("Load error: " + Std.string(error));
	}
	
	/**
	 * Call goBackToListView on the application controller.
	 */
	public function onHeaderBackButtonPressed():Void
	{
		// update header title
		_header.data = Constants.HEADER_HOME_TITLE;
		
		// hide header back button
		_header.displayBackButton = false;
		
		// remove detail view and add swippableListView
		_body.removeChild(_detailView.node);
		_body.appendChild(_menu.node);
		_body.appendChild(_swippableListView.node);

		// set _currentView
		_currentView = _swippableListView;

		// update zIndex
		updateZIndexes();

		// remove detailview touch events listener
		//_detailView.unsetTouchEvents();

		// on resize callback is called here to resolve an Android Browser bug, where application width is not refreshed correctly
		_swippableListView.scrollToCurrentList();
		
		// refresh styles
		refreshStyles();
	}
	
	/**
	 * updates header and menu zIndex to the maximum value.
	 * Uses a workaround as zIndex is not implemented yet in Cocktail
	 */
	private function updateZIndexes():Void
	{
		setZIndexToMax(_menu);
		setZIndexToMax(_header);
	}
	
	/**
	 * updates zIndex to the maximum value.
	 * Uses a workaround as zIndex is not implemented yet in Cocktail
	 */
	private function setZIndexToMax(view:ViewBase):Void
	{
		// remove and add dom so it has the higher zIndex
		_body.removeChild(view.node);
		_body.appendChild(view.node);
	}
	
	/**
	 * on rezize callback
	 */
	private function refreshStyles():Void
	{
		// launch needed callbacks depending on the currentView
		if(_currentView == _swippableListView)
		{
			_menu.refreshStyles();
			_swippableListView.refreshStyles();
		}
		else if (_currentView == _detailView)
		{
			_detailView.refreshStyles();		
		}
	}

	
}