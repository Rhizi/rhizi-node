define ['backbone'], (Backbone) ->

  class NodeModel extends Backbone.Model
    defaults:
      name: ''
      tags: []
      description: ''
      url: ''
      size: ''
      color: ''
      in_DB: false

    schema:
      name:
        type: 'Text'
        validators: ['required']
      url:
        type: 'Text'
        validators: [type: 'regexp', regexp: /((www|http|https)([^\s]+))|([a-z0-9!#$%&'+\/=?^_`{|}~-]+(?:.[a-z0-9!#$%&'+\/=?^_`{|}~-]+)*@(?:a-z0-9?.)+a-z0-9?)/ ]
      description:
        type: 'TextArea'
      tags:
        type: 'List'
        itemType: 'Text'

    validate: ->
      if !@get('name')
        'Your node must have a name.'
