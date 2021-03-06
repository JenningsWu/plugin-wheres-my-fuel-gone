{React, ReactDOM} = window
{join} = require 'path-extra'
Promise = require 'bluebird'
fs = Promise.promisifyAll(require 'fs-extra')
{Nav, NavItem} = ReactBootstrap

window.wheresMyFuelGoneWindow = remote.getCurrentWindow()
handleWindowMoveResize = ->
  b1 = window.wheresMyFuelGoneWindow.getBounds()
  setTimeout((->
    b2 = window.wheresMyFuelGoneWindow.getBounds()
    if JSON.stringify(b2) == JSON.stringify(b1)
      config.set 'plugin.WheresMyFuelGone.bounds', b2
  ), 5000)
window.wheresMyFuelGoneWindow.on 'move', handleWindowMoveResize
window.wheresMyFuelGoneWindow.on 'resize', handleWindowMoveResize

{TabMain} = require './tab_main'
{TabBookmarks} = require './tab_bookmarks'
{RecordManager} = require './records'
{portRuleList} = require './filter_selector'

PluginMain = React.createClass
  getInitialState: ->
    fullRecords: []
    filterList: {}
    nowNav: 1

  filterListPath: ->
    join window.pluginRecordsPath(), 'filters.json'

  componentDidMount: ->
    window.addEventListener 'game.response', @handleResponse

  componentWillUnmount: ->
    @recordManager?.stopListening()
    window.removeEventListener 'game.response', @handleResponse

  handleResponse: (e) ->
    if !@recordManager && window._nickNameId
      fs.ensureDirSync window.pluginRecordsPath()
      @readFiltersFromJson()
      @recordManager = new RecordManager()
      @recordManager.onRecordUpdate @handleRecordsUpdate
      @setState
        nickNameId: window._nickNameId

  handleRecordsUpdate: ->
    @setState
      fullRecords: (@recordManager?.records() || [])

  onChangeFilterName: (time, name) ->
    {filterList} = @state
    if !filterList[time]
      return false
    filterList[time].name = name
    @setState {filterList}
    @saveFiltersToJson()

  onRemoveFilter: (time) ->
    {filterList} = @state
    delete filterList[time]
    @setState {filterList}
    @saveFiltersToJson()

  onAddFilter: (filter) ->
    {filterList} = @state
    filter =
      rules: cloneByJson filter
      name: __('New filter')
    filterList[Date.now()] = filter
    @setState {filterList}
    @saveFiltersToJson()

  readFiltersFromJson: ->
    fs.readJsonAsync @filterListPath(), {throws: false}
    .then (filterList) =>
      if filterList
        for time, filter of filterList
          filter.rules = portRuleList filter.rules
          delete filter.time
        @setState {filterList}, @saveFiltersToJson
    .catch (->)

  saveFiltersToJson: ->
    fs.writeFile @filterListPath(), JSON.stringify @state.filterList

  handleNav: (key) ->
    @setState
      nowNav: key

  render: ->
    decideNavShow = (key) =>
      if key == @state.nowNav
        {}
      else
        {display: 'none'}
    <div id='main-wrapper'>
      <Nav bsStyle="tabs" activeKey={@state.nowNav} onSelect={@handleNav}>
        <NavItem eventKey=1>{__ 'Table'}</NavItem>
        <NavItem eventKey=2>{__ 'Bookmarks'}</NavItem>
      </Nav>
      {
        if @state.nickNameId && @recordManager
          [
           <div style={decideNavShow(1)} key=1>
             <TabMain
               onAddFilter={@onAddFilter}
               fullRecords={@state.fullRecords} />
           </div>
           <div style={decideNavShow(2)} key=2>
             <TabBookmarks
               filterList={@state.filterList}
               onChangeFilterName={@onChangeFilterName}
               onRemoveFilter={@onRemoveFilter}
               fullRecords={@state.fullRecords} />
           </div>
          ]
      }
    </div>

ReactDOM.render <PluginMain />, $('main')
