define [], () ->
  class svgDefs

    addDefs: (def, defaultColors) ->
      # DragLine Arrowhead
      def
        .append('svg:marker')
          .attr('id', 'draghead')
          .attr('viewBox', '0 -5 10 10')
          .attr('refX', '5')
          .attr('refY', '0')
          .attr('markerWidth', '3')
          .attr('markerHeight', '3')
          .attr('orient', 'auto')
          .attr('fill', 'black')
          .append('svg:path')
            .attr('d',"M0,-5L10,0L0,5")
      # Connection Arrowhead
      def
        .append('svg:marker')
          .attr('id', 'arrowhead')
          .attr('viewBox', '0 -5 10 10')
          .attr('refX', '8')
          .attr('refY', '0')
          .attr('markerWidth', '5')
          .attr('markerHeight', '5')
          .attr('orient', 'auto')
          .attr('fill', 'black')
          .append('svg:path')
            .attr('d',"M0,-3L8,0L0,3")
      # Selected Connection Arrowhead
      def
        .append('svg:marker')
          .attr('id', 'arrowhead-selected')
          .attr('viewBox', '0 -5 10 10')
          .attr('refX', '8')
          .attr('refY', '0')
          .attr('markerWidth', '5')
          .attr('markerHeight', '5')
          .attr('orient', 'auto')
          .attr('fill', '#3498db')
          .append('svg:path')
            .attr('d',"M0,-3L8,0L0,3")
      # Image Circles
      def
        .append('svg:clipPath')
          .attr('id', 'clipCircle')
          .append('circle')
            .attr('r', '18')
            .attr('cx', '-70')
            .attr('cy', '0')
      # Colored Connection Arrowheads
      for color,hex of defaultColors
          def
            .append('svg:marker')
              .attr('id', 'arrowhead-'+color)
              .attr('viewBox', '0 -5 10 10')
              .attr('refX', '8')
              .attr('refY', '0')
              .attr('markerWidth', '5')
              .attr('markerHeight', '5')
              .attr('orient', 'auto')
              .attr('fill', hex)
              .append('svg:path')
                .attr('d',"M0,-3L8,0L0,3")
