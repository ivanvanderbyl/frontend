Backrub =
  _Genuine :
    nameLookup : Handlebars.JavaScriptCompiler.prototype.nameLookup
    mustache : Handlebars.Compiler.prototype.mustache
  #
  # Get a path within the base object (or window if undefined)
  #
  _getPath : (path, base, wrap)->
    wrap = wrap || false
    base = base || window
    prev = base
    throw new Error "Path is undefined or null" if path == null or path is undefined
    parts = path.split(".")
    _.each parts, (p)->
      prev = base
      base = if p is "" then base else base[p]
      if not base?
        throw new Error "cannot find given path '#{path}'"
        return {}
    if typeof( base ) is "function" and wrap
      _.bind( base, prev )
    else
      base

  #
  # Resolve a value properly in the model
  #
  # Backbone models are not plain javascript object so you cannot
  # simply follow the path, you need to call get on the model.
  #
  _resolveValue : (attr, model)->
    parts = attr.split(/\.(.+)?/)
    if parts.length > 1
      model = Backrub._resolveValue(parts[0], model)
      attr = parts[1]
    model_info = Backrub._resolveIsModel attr, model
    if model_info.is_model
      model_info.model.get(model_info.attr)
    else if model_info.is_model is null
      attr
    else
      value = try
        Backrub._getPath model_info.attr, model_info.model, true
      catch error

      if typeof( value ) is "function" then value() else value

  #
  # Determine if the attribute is a model attribute or view attribute
  # If the attribute is preceded by @ it is considered a model attr.
  #
  _resolveIsModel : (attr, model)->
    is_model = false
    attr = if attr and (attr.charAt?(0) is "@")
      is_model = true
      model = model.model
      attr.substring(1)
    else if attr and model and model.get and model.get(attr) isnt undefined
      is_model = true
      attr
    else if attr and model.model and model.model.get and model.model.get(attr) isnt undefined
      is_model = true
      model = model.model
      attr
    else if model[attr] isnt undefined
      attr
    else
      model = null
      is_model = null
      attr

    #
    # return an object with a convenient bind method that check the
    # presence of a model
    #
    is_model: is_model
    attr: attr
    model: model
    bind: (callback)->
      if model and model.bind
        model.bind "change:#{attr}", callback

  #
  # Used by if and unless helpers to render the and listen changes
  #
  _bindIf : (attr, context)->
    if context
      view = Backrub._createBindView( attr, this, context)

      model_info = Backrub._resolveIsModel attr, this

      model_info.bind ->
        if context.data.exec.isAlive()
          view.rerender()
          context.data.exec.makeAlive()
      #setup the render to check for truth of the value
      view.render = ->
        fn = if Backrub._resolveValue( @attr, @model ) then context.fn else context.inverse
        new Handlebars.SafeString @span( fn(@model, {data:context.data}) )

      view.render()
    else
      throw new Error "No block is provided!"


  #
  #
  #
  _bindAttr : (attrs, context, model)->
    id = _.uniqueId('ba')
    outAttrs = []
    self = model || this
    #go thru every attributes in the hash
    _.each attrs, (attr, k)->
      model_info = Backrub._resolveIsModel attr, self
      value = Backrub._resolveValue attr, self
      outAttrs.push "#{k}=\"#{value}\""

      #handle change events
      model_info.bind ->
        if context.data.exec.isAlive()
          el = $("[data-baid='#{id}']")
          if el.length is 0
            model_info.model.unbind "change#{model_info.attr}"
          else
            el.attr k, Backrub._resolveValue attr, self

    if outAttrs.length > 0
      outAttrs.push "data-baid=\"#{id}\""

    new Handlebars.SafeString outAttrs.join(" ")

  #
  # Create a backbone view with the specified prototype.
  # It adds _span_, _live_, _textAttributes_ and _bvid_ attributes
  # to the view.
  #
  _createView : (viewProto, options)->

    v = new viewProto(options)
    throw new Error "Cannot instantiate view" if !v
    v._ensureElement = Backrub._BindView.prototype._ensureElement
    v.span = Backrub._BindView.prototype.span
    v.live = Backrub._BindView.prototype.live
    v.textAttributes = Backrub._BindView.prototype.textAttributes
    v.bvid = "#{_.uniqueId('bv')}"
    return v

  #
  # Create a bind view and parse the hash properly
  #
  _createBindView : (attr, model, context)->
    view = new Backrub._BindView
      attr  : attr
      model : model
      context: context
      prevThis: model
    context.data.exec.addView view

    if context.hash
      view.tagName = context.hash.tag || view.tagName
      delete context.hash.tag
      view.attributes = context.hash

    view

  #
  # Lightweight span based view to encapsulate the different helpers
  # A unique id is used to retrieve the view for update
  #
  _BindView : Backbone.View.extend
    tagName : "span"
    #
    # _ensureElement is a noop to avoid creating tons of elements for nothing while
    # building the template.
    #
    _ensureElement: ->
      null
    live : -> $("[data-bvid='#{@bvid}']")
    initialize: ->
      _.bindAll this, "render", "rerender", "span", "live", "value", "textAttributes"
      @bvid = "#{_.uniqueId('bv')}"
      @attr = @options.attr
      @prevThis = @options.prevThis
      @hbContext = @options.context
    value: ->
      Backrub._resolveValue @attr, @model
    textAttributes: ->
      @attributes = @attributes || @options.attributes || {}
      @attributes.id = @id if !(@attributes.id) && @id
      @attributes.class = @className if !@attributes.class && @className
      Backrub._bindAttr(@attributes, @hbContext, @prevThis || this).string
    span: (inner)->
      "<#{@tagName} #{@textAttributes()} data-bvid=\"#{@bvid}\">#{inner}</#{@tagName}>"
    rerender : ->
      @live().replaceWith @render().string
    render  : ->
      new Handlebars.SafeString @span( @value() )

#
# See handlebars code. This override mustache so that
# it will call the bind helper to resolve single value
# mustaches.
#
Handlebars.Compiler.prototype.mustache = (mustache)->
  if mustache.params.length || mustache.hash
    Backrub._Genuine.mustache.call(this, mustache);
  else
    id = new Handlebars.AST.IdNode(['bind']);
    mustache = new Handlebars.AST.MustacheNode([id].concat([mustache.id]), mustache.hash, !mustache.escaped);
    Backrub._Genuine.mustache.call(this, mustache);

#
# See handlebars code.
#
Handlebars.JavaScriptCompiler.prototype.nameLookup =  (parent, name, type)->
  if type is 'context'
    "\"#{name}\""
  else
    Backrub._Genuine.nameLookup.call(this, parent, name, type)

#
# Call this within the initialize function of your View, Controller, Model.
# It will look at all the attributes for _base_ that have been marked as
# dependent on some _event_ and make sure a change:attribute_name event
# will be trigger on the object defined by the _path_
#
Backbone.dependencies = (onHash, base)->
  base = base || this
  throw new Error "Not a Backbone.Event object" if !base.trigger and !base.bind
  setupEvent = (event, path)->
    parts = event.split(" ")
    attr = parts[0]
    object = Backrub._getPath(path, base)
    for e in parts[1..]
      object?.bind e, ->
        base.trigger "change:#{attr}"

  for event, path of onHash
    setupEvent(event, path)

#
# Setup dependencies in the backbone prototype for nice syntax
#
for proto in [Backbone.Model.prototype, Backbone.Router.prototype, Backbone.Collection.prototype, Backbone.View.prototype]
  _.extend proto, {dependencies: Backbone.dependencies}


Backbone.Backrub = (template)->
  _.bindAll @, "addView", "render", "makeAlive", "isAlive"
  @compiled = Handlebars.compile( template, {data: true, stringParams: true} )
  @_createdViews = {}
  @_aliveViews = {}
  @_alive = false
  return @

_.extend Backbone.Backrub.prototype,
  #
  # Execute a templae given some options
  #
  render: (options)->
    self = this
    @compiled(options, {data:{exec : @}})

  #
  # Make Alive will properly handle the delgation of
  # events based on Backbone conventions. By default,
  # it will use the body element to find created elements
  # but you can also give a base element to query from.
  # This is useful when your template is appended to a
  # DOM element that wasn't inserted into the page yet.
  #
  makeAlive: (base)->
    base = base || $("body")
    query = []
    currentViews = @_createdViews
    @_createdViews = {}

    _.each currentViews, (view, bvid)->
      query.push "[data-bvid='#{bvid}']"

    @_alive = true
    self = @
    $(query.join( "," ), base).each ->
      el = $(@)
      view = currentViews[el.attr( "data-bvid" )]
      view.el = el
      view.delegateEvents()
      view.alive?.call(view)
    #move alive views away for other makeAlive passes
    _.extend @_aliveViews, currentViews


  isAlive: ->
    @_alive

  #
  # Internal API to add view to the context
  #
  addView : (view)->
    @_createdViews[view.bvid] = view

  #
  # Internal API to remove view formt he tracking list
  #
  removeView : (view)->
    delete @_createdViews[view.bvid]
    delete @_aliveViews[view.bvid]
    delete view

#
# A simple Backbone.View to wrap around the Backbone.Backrub API
# You can use this view as any other view within backbone. Call
# render as you would normally
#
Backbone.TemplateView = Backbone.View.extend
  initialize: (options)->
    @template = @template || options.template
    throw new Error "Template is missing" if !@template
    @compile = new Backbone.Backrub(@template)

  render : ->
    try
      $(@el).html @compile.render @
      @compile.makeAlive @el
    catch e
      console.error e.stack
    @el

#
# View helper
# You can reference your backbone views in the template to
# add extra logic and events. Use this helper with the view
# name (as accessible within the window object). You can give it
# a hash with the usual backbone options (model, id, etc.)
# The render method is redefined. A rendered event is sent but
# within the templating loop (elements are not on the document yet)
#
Handlebars.registerHelper "view", (viewName, context)->
  execContext = context.data.exec
  view = Backrub._getPath(viewName)
  resolvedOptions = {}
  for key, val of context.hash
    resolvedOptions[key] = Backrub._resolveValue(val, this) ? val

  v = Backrub._createView view, resolvedOptions
  execContext.addView v
  v.render = ()->
    new Handlebars.SafeString @span( context(@, {data:context.data}) )
  v.render(v)


#
# Bind helper
# Bind a value from the view or the model to the template.
# When the value changes ("change:_attribute_" events) only this part
# of the template will be rerendered. Bind will create a new <span>
# node to keep track of what to refresh.
#
Handlebars.registerHelper "bind", (attrName, context)->
  execContext = context.data.exec
  view = Backrub._createBindView( attrName, this, context )

  model_info = Backrub._resolveIsModel attrName, this
  model_info.bind ->
    if execContext.isAlive()
      view.rerender()
      execContext.makeAlive()
  new Handlebars.SafeString view.render()

#
# Bind attributes helper
# This helper is used to bind attributes to an HTML element in
# your template. Bind attributes will create a data-baid to keep
# track of the element for further updates.
#
Handlebars.registerHelper "bindAttr", (context)->
  _.bind(Backrub._bindAttr, this)(context.hash, context)

#
# Bounded if
# A if/else statement that will listen for changes and update
# accordingly. Uses bind so a <span> will be created
#
Handlebars.registerHelper "if", (attr, context )->
  _.bind(Backrub._bindIf, this)( attr, context)

#
# Bounded unless
# A unless/else statement that will listen for changes and update
# accordingly. Uses bind so a <span> will be created
#
Handlebars.registerHelper "unless", (attr, context)->
  fn = context.fn
  inverse = context.inverse
  context.fn = inverse
  context.inverse = fn

  _.bind(Backrub._bindIf, this)( attr, context )

#
# Bounded each
# A each helper to iterate on a Backbone Collection and
# update any refresh/add/remove events. <span> will be created
# for the overall collection and each of its items to keep track
# of what to refresh.
# Do not know what will happen with sorting...
#
Handlebars.registerHelper "collection", (attr, context)->
  execContext = context.data.exec
  collection = Backrub._resolveValue attr, this
  if not collection.each?
    throw new Error "not a backbone collection!"

  options = context.hash
  colViewPath = options?.colView
  colView = Backrub._getPath(colViewPath) if colViewPath
  colTagName = options?.colTag || "ul"

  itemViewPath = options?.itemView
  itemView = Backrub._getPath(itemViewPath) if itemViewPath
  itemTagName = options?.itemTag || "li"

  # filter col/items arguments
  # TODO would it be possible to use bindAttr for col/item attributes
  colAtts = {}
  itemAtts = {}
  _.each options, (v, k) ->
    return if k.indexOf("Tag") > 0 or k.indexOf("View") > 0
    if k.indexOf( "col") is 0
      colAtts[k.substring(3).toLowerCase()] = v
    else if k.indexOf( "item" ) is 0
      itemAtts[k.substring(4).toLowerCase()] = v

  view = if colView
    Backrub._createView colView,
      model: collection
      attributes: colAtts
      context: context
      tagName : if options?.colTag then colTagName else colView.prototype.tagName
  else
    new Backrub._BindView
      tagName: colTagName
      attributes: colAtts
      attr  : attr
      model : this
      context: context
  execContext.addView view

  views = {}

  #
  # Item view setup closure
  #
  item_view = (m)->
    mview = if itemView
      Backrub._createView itemView,
        model: m
        attributes: itemAtts
        context: context
        tagName : if options?.itemTag then itemTagName else itemView.prototype.tagName
    else
      new Backrub._BindView
        tagName: itemTagName
        attributes: itemAtts
        model: m
        context: context
    execContext.addView mview

    #
    # Render the item view using the template
    #
    mview.render = ()-> @span context(@, {data:context.data})
    return mview

  #
  # Container view setup closure
  #
  setup = (col, mainView, childViews) ->
    # create all childs
    col.each (m)->
      mview = item_view m
      childViews[m.cid] = mview

    #
    # Rendering for the main view simply calls render of the child
    # and wrap this with the container view element.
    #
    mainView.render = ->
      rendered = _.map childViews, (v)->
        v.render()
      new Handlebars.SafeString @span( rendered.join("\n") )

  setup(collection, view, views)

  collection.bind "reset", ()->
    if execContext.isAlive()
      # dump everything and resetup the view
      # Call make alive to keep track of new views.
      views = {}
      setup(collection, view, views)
      view.rerender()
      execContext.makeAlive()
  collection.bind "add", (m)->
    if execContext.isAlive()
      # create the new view as needed
      # Call make alive to keep track of new views.
      mview = item_view m
      views[m.cid] = mview
      if options.prepend isnt undefined
        view.live().prepend(mview.render())
      else
        view.live().append(mview.render())
      execContext.makeAlive()
  collection.bind "remove", (m)->
    if execContext.isAlive()
      # remove the view associated with the model
      # Stop tracking this view.
      mview = views[m.cid]
      mview.live().remove()
      execContext.removeView mview

  view.render()
