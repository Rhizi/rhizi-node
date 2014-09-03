define ['jquery', 'underscore', 'backbone', 'd3', 'cs!views/svgDefs'
  'cs!views/ConnectionAdder', 'cs!views/TrashBin', 'cs!views/DataTooltip', 'cs!views/ZoomButtons', 
  'text!templates/data_tooltip.html', 'text!templates/node-title.html'],
  ($, _, Backbone, d3, svgDefs, ConnectionAdder, TrashBin, DataTooltip, ZoomButtons, popover, nodeTitle) ->
    class GraphView extends Backbone.View
      el: $ '#graph'

      events:
        "contextmenu": "rightClicked"

      # Parameters for display
      maxConnTextLength: 20
      maxNodeBoxHeight: 100 #4 lines
      nodeBoxWidth: 120
      maxInfoBoxHeight: 200
      infoBoxWidth: 120

      initialize: ->
        that = this
        @drawing = true
        @model.on 'init', @backgroundRender, this
        @model.nodes.on 'add remove', @updateForceGraph, this
        @model.connections.on 'add remove', @updateForceGraph, this
        @model.nodes.on 'change', @updateDetails, this
        @model.connections.on 'change', @updateDetails, this

        @model.on 'found:node', @centerOn, this

        @translateLock = false

        width = $(@el).width()
        height = $(@el).height()

        @force = d3.layout.force()
                  .nodes([])
                  .links([])
                  .size([width, height])
                  .charge(-4000)
                  .gravity(0.2)
                  .distance(50)

        zoomed = =>
          return if @translateLock
          @workspace.attr "transform",
            "translate(#{d3.event.translate}) scale(#{d3.event.scale})"
        @zoom = d3.behavior.zoom().on('zoom', zoomed)

        # store the current zoom to undo changes from dragging a node
        @currentZoom = undefined
        @force.drag()
        .on "dragstart", (d) ->
          that.translateLock = true
          that.currentZoom = that.zoom.translate()
        .on "drag", (d) ->
          d3.select(this).classed("fixed", d.fixed = true)
          that.trigger "node:drag", d, d3.event
        .on "dragend", (node) =>
          @trigger "node:dragend", node, d3.event
          @zoom.translate @currentZoom
          @translateLock = false
          @force.stop()

        @svg = d3.select(@el).append("svg:svg")
                .attr("pointer-events", "all")
                .attr('width', width)
                .attr('height', height)
                .call(@zoom)
                .on("dblclick.zoom", null)
        def = @svg.append('svg:defs')
        (new svgDefs).addDefs def, @model.defaultColors

        @workspace = @svg.append("svg:g")

        @workspace.append("svg:g").classed("connection-container", true)
        @workspace.append("svg:g").classed("node-container", true)

        @connectionAdder = new ConnectionAdder
          model: @model
          attributes: {force: @force, graphView: this}

        @trashBin = new TrashBin
          model: @model
          attributes: {graphView: this}

        @dataTooltip = new DataTooltip
          model: @model
          attributes: {graphView: this}

        @zoomButtons = new ZoomButtons
          attributes: {zoom: @zoom, workspace: @workspace}

      loadForce: ->
        nodes = @model.nodes.models
        connections = @model.connections.models
        _.each connections, (c) =>
          c.source = @model.getSourceOf c
          c.target = @model.getTargetOf c
        @force.nodes(nodes).links(connections).start()

      backgroundRender: ->
        @loadForce()
        n = @model.nodes.models.length*@model.nodes.models.length*@model.nodes.models.length+50

        @drawing = false
        for i in [0..n] by 1
          @force.tick()
        @force.stop()
        @drawing = true

        setTimeout () =>
          @updateDetails()
          @force.tick()
        , 10

      updateForceGraph: ->
        @loadForce()
        @updateDetails()
        setTimeout () =>
          @force.stop()
        , 1500

      updateDetails: (incoming) ->
        that = this

        if incoming?
          ignoredList = ['dim','id','_id']
          changedAttrs = (k for k,v of incoming.changed)
          if (_.difference changedAttrs, ignoredList).length is 0 then return
        that = this
        nodes = @model.nodes.models
        connections = @model.connections.models
        # old elements
        connection = d3.select(".connection-container")
          .selectAll(".connection")
          .data(connections, (conn) -> conn.cid)

        # new elements
        connectionEnter = connection.enter().append("g")
          .attr("class", "connection")
          .on "click", (d) =>
            @model.select d
            @model.trigger "conn:clicked", d
          .on "mouseover", (conn)  =>
            @trigger "connection:mouseover", conn
          .on "mouseout", (conn) =>
            if(!$(d3.event.toElement).closest('.connection').length)
              @trigger "connection:mouseout", conn
        connectionEnter.append("line")
          .attr('class', 'select-zone')
        connectionEnter.append("line")
          .attr('class', 'visible-line')
          .attr("marker-end", "url(#arrowhead)")
          .style("stroke", (d) => @getColor d)
        text-group = connectionEnter.append("g")
          .attr('class', 'connection-text')
        text-group.append("text")
          .attr("text-anchor", "middle")
        text-group.append("foreignObject")
          .attr('y', '1')
          .attr('height', @maxInfoBoxHeight)
          .attr('width', @infoBoxWidth)
          .attr('x', '-12')
          .attr('class', 'connection-info')
          .append('xhtml:body')
            .attr('class', 'connection-info-body')

        # old and new elements
        connection.attr("class", "connection")
          .classed('dim', (d) -> d.get('dim'))
          .each (d,i) ->
            line = d3.select(this).select("line.visible-line")
            if !d.get('selected')
              line.style("stroke", (d) -> that.getColor d)
            else 
              line.style("stroke", that.model.selectedColor)
            
            if d.get('color')
              line.attr("marker-end", "url(#arrowhead-"+d.get('color')+")")
            else 
              line.attr("marker-end", "url(#arrowhead)")
            if d.get('selected')
              line.attr("marker-end", "url(#arrowhead-selected)")
          .classed('selected', (d) -> d.get('selected'))
          
            
        connection.select("text")
          .text((d) =>
            if(d.get("name").length < @maxConnTextLength)
              return d.get("name")
            else 
              return d.get("name").substring(0,@maxConnTextLength-3)+"..."
        )
        connection.select('.connection-info-body')
          .html((d) -> _.template(popover, d))

        # move the popover info to align with the left of the text
        for t in connection.select('text')[0]
          dim = t.getBBox()
          info = $(t).parent().find('.connection-info')
          info
            .attr('x',dim.x)

        # remove deleted elements
        connection.exit().remove()

        # old elements
        node = d3.select(".node-container")
          .selectAll(".node")
          .data(nodes, (node) -> node.cid)

        # new elements
        nodeEnter = node.enter().append("g")
        nodeRectangle = nodeEnter.append('rect')
          .attr('x', '-80')
          .attr('y', '-15')
          .attr('width', '20')
          .attr('height', '30')
          .attr('fill', 'transparent')
        nodeText = nodeEnter.append("foreignObject")
          .attr("y", "5")
          .attr("height", @maxNodeBoxHeight) #max height overflow is cut off
          .attr("width", @nodeBoxWidth)
          .attr("x", "-60")
          .attr('class', 'node-title')
        nodeInnerText = nodeText.append('xhtml:body')
          .attr('class', 'node-title-body')
        nodeConnector = nodeEnter.append("circle")
          .attr('r', '5')
          .attr('cx', '-70')
          .attr('cy', '0')
          .attr('class', 'node-connector')
          .attr('fill', '#222') 
        nodeInfoText = nodeEnter.append("foreignObject")
          .attr('y', '12')
          .attr('height', @maxInfoBoxHeight)
          .attr('width', @infoBoxWidth)
          .attr('x', '-21')
          .attr('class', 'node-info')
          .append('xhtml:body')
            .attr('class', 'node-info-body')
        nodeImage = nodeEnter.append("image")
          .attr('height', '50')
          .attr('width', '50')
          .attr('xlink:href', '')
          .attr('x', '-95')
          .attr('y', '-25')
          .attr('class', 'node-image')
          .attr('clip-path', 'url(#clipCircle)')
        
        nodeRectangle
          .on "click", (d) =>
            @model.trigger "node:clicked", d
        nodeConnector
          .on "click", (d) =>
            @model.trigger "node:clicked", d
        nodeInnerText 
          .on "click", (d) =>
            @model.trigger "node:clicked", d
        node
          .on "dblclick", (d) ->
            that.model.select d
            that.model.trigger "node:dblclicked", d
          .on "contextmenu", (node) ->
            d3.event.preventDefault()
            that.trigger('node:right-click', node, d3.event)
          .on "mouseenter", (node) =>
            @trigger "node:mouseenter", node
          .on "mouseout", (node) =>
            # perhaps setting the foreignobject height dynamically would be better.
            if(!$(d3.event.toElement).closest('.node').length)
              @trigger "node:mouseout", node
            node.fixed &= ~4 # unset the extra d3 fixed variable in the third bit of fixed

        # update old and new elements

        node.attr('class', 'node')
          .classed('dim', (d) -> d.get('dim'))
          .classed('selected', (d) -> d.get('selected'))
          .classed('fixed', (d) -> d.fixed & 1) # d3 preserves only first bit of fixed
          .classed('image', (d) -> d.get('image'))
          .call(@force.drag)
        node.select('.node-title-body')
          .html((d) -> _.template(nodeTitle, d))
        node.select('.node-connector')
          .style("fill", (d) => @getColor d)
        node.select('.node-info-body')
          .html((d) -> _.template(popover, d))
        node.select('.node-image')
          .attr('xlink:href', (d) -> d.get('image'))

        node.select('.node-expand-count')
          .each (d) ->
            total = d.get 'neighborCount'
            view = that.model.connections.filter( (conn) =>
              return (conn.source.id == d.id || conn.target.id == d.id)
            ).length
            $(this).text(total-view)

        # move the popover info to align with the left of the text
        # construct the node boxes
        offsetV = 4
        offsetH = 12
        for t in node.select('.node-title')[0]
          el = $(t).find('.node-title-body')
          left = el.width()/2+parseInt(el.css('border-left-width'),10)
          top = el.height()/2+parseInt(el.css('border-bottom-width'),10)

          $(t)
            .attr('y', - top)

          info = $(t).parent().find('.node-info')
          info
            .attr('x',-left)
            .attr('y',top)

        # delete unmatching elements
        node.exit().remove()

        # set-up clickable tags
        $('.tag-link').on "click", (e) =>
          e.preventDefault()
          tag = $(e.currentTarget).attr('data-tag')
          @trigger 'tag:click', tag

        tick = =>
          connection.selectAll("line")
            .attr("x1", (d) => @model.getSourceOf(d).x-(@nodeBoxWidth/2+10))
            .attr("y1", (d) => @model.getSourceOf(d).y)
            .attr("x2", (d) => @model.getTargetOf(d).x-(@nodeBoxWidth/2+10))
            .attr("y2", (d) => @model.getTargetOf(d).y)
          connection.select(".connection-text")
            .attr("transform", (d) => "translate(#{((@model.getSourceOf(d).x-@model.getTargetOf(d).x)/2+@model.getTargetOf(d).x)-(@nodeBoxWidth/2+10)},#{(@model.getSourceOf(d).y-@model.getTargetOf(d).y)/2+@model.getTargetOf(d).y})")
          node.attr("transform", (d) -> "translate(#{d.x},#{d.y})")
          @connectionAdder.tick

        tick()
        @force.on "tick", () =>
          if @drawing then tick()

      rightClicked: (e) ->
        e.preventDefault()
        @connectionAdder.clearDragLine()

      isContainedIn: (node, element) =>
        node.x < element.offset().left + element.outerWidth() &&
        node.x > element.offset().left &&
        node.y > element.offset().top &&
        node.y < element.offset().top + element.outerHeight()

      centerOn: (node) =>
        translateParams = [$(window).width()/2-node.x*@zoom.scale(),$(window).height()/2-node.y*@zoom.scale()]
        #update translate values
        @zoom.translate([translateParams[0], translateParams[1]])
        #translate workspace
        @workspace.transition().ease("linear").attr "transform", "translate(#{translateParams}) scale(#{@zoom.scale()})"

      getColor: (nc) ->
        @model.defaultColors[nc.get('color')]
