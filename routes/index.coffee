express = require 'express'
router = express.Router()

utils = require './utils'
nodes = require './nodes'
connections = require './connections'
documents = require './documents'
search = require './search'

# load up the user model
User = require '../models/user.coffee'

#defines a function to extract parameters using regex's
router.param utils.paramExtract
integerRegex = /^\d+$/
router.param 'id', integerRegex
router.param 'docId', integerRegex

router.get '/new', utils.isLoggedIn, (request, response) ->
  documents.addBlank request.user._id, (savedDocument) ->
    User.findById request.user._id, (err, user) ->
      user.addDocument savedDocument._id
    response.redirect "/#{savedDocument._id}"

router.get '/:id', (request, response) ->
  documents.prefetch request, response, (prefetched) ->
    if request.isAuthenticated()
      prefetched.isAuthenticated = true
      prefetched.user = request.user
    else
      prefetched.isAuthenticated = false
      prefetched.user = {}
    response.render 'index.jade', prefetched

router.get /^\/mobile\/(\d*)$/, (request, response) ->
  response.render('mobile.jade')

router.get '/landing', (request, response)->
  documents.helper.getAll (docs) ->
    response.render 'landing.jade', {docs:docs}

router.get '/errors/missingDocument', (request, response)->
  response.render('errors/missingDocument.jade')

# Documents
router.post     '/document',           documents.create
router.get      '/document/:id',       documents.read
router.get      '/document',           documents.getAll
router.put      '/document/:id',       documents.update
router.delete   '/document/:id',       documents.destroy

# Analytics
router.get      '/document/:id/analytics', documents.analytics
router.get      '/document/:id/fullgraph', documents.fullgraph

# Nodes
router.post     '/document/:docId/nodes',                      nodes.create
router.get      '/document/:docId/nodes/:id',                  nodes.read
router.get      '/document/:docId/nodes',                      nodes.getAll
router.get      '/document/:docId/nodes/:id/neighbors/',       nodes.getNeighbors
router.get      '/document/:docId/nodes/:id/spokes/',          nodes.getSpokes
router.post     '/document/:docId/nodes/:id/get_connections/', nodes.getConnections
router.put      '/document/:docId/nodes/:id',                  nodes.update
router.delete   '/document/:docId/nodes/:id',                  nodes.destroy

# Connections
router.post     '/document/:docId/connections',       connections.create
router.get      '/document/:docId/connections/:id',   connections.read
router.get      '/document/:docId/connections',       connections.getAll
router.put      '/document/:docId/connections/:id',   connections.update
router.delete   '/document/:docId/connections/:id',   connections.destroy

# Search
router.get      '/document/:docId/nodes/names',       search.getNodeNames
router.get      '/document/:docId/getNodeByName',     search.getNodeByName
router.get      '/document/:docId/getNodesByTag',     search.getNodesByTag
router.get      '/document/:docId/tags',              search.getTagNames

module.exports = router
