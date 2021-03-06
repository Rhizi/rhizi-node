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
  documents.addBlank request.user.local.name, (savedDocument) ->
    User.findById request.user._id, (err, user) ->
      user.addDocument savedDocument._id
    response.redirect "/#{request.user.local.name}/document/#{savedDocument._id}"

sendGraphDoc = (request, response) ->
  request.params.id = [request.params[1]]
  documents.prefetch request, response, (prefetched) ->
    if request.isAuthenticated()
      prefetched.isAuthenticated = true
      prefetched.user = request.user
      if prefetched.theDocument.createdBy
        prefetched.isOwner = request.user.local.nameLower is (prefetched.theDocument.createdBy).toLowerCase()
      else
        prefetched.isOwner = false
    else
      prefetched.isAuthenticated = false
      prefetched.user = {}
      prefetched.isOwner = false
    if (prefetched.theDocument.publicEdit != 0 or prefetched.isOwner) && prefetched.isAuthenticated
      response.render 'graph-content-edit.jade', prefetched
    else if prefetched.theDocument.publicView != 0
      response.render 'graph-content-view.jade', prefetched
    else
      response.render 'errors/missingDocument.jade'

router.get /^(?:\/(\w+)\/document)?\/(\d+)\/?(?:search\/(\w+))?\/?$/, (request, response) ->
  sendGraphDoc request, response

router.get /^(?:\/(\w+)\/document)?\/(\d+)\/?(?:view\/(\d+))?\/?$/, (request, response) ->
  sendGraphDoc request, response

router.get /^\/mobile\/(\d*)$/, (request, response) ->
  response.render('mobile.jade')

router.get '/errors/missingDocument', (request, response)->
  response.render('errors/missingDocument.jade')

router.get '/account', (req, res) ->
  if req.isAuthenticated()
    username = req.user.local.nameLower
    User.findOne { 'local.nameLower' :  username }, (err, profiledUser) ->
      if err or not(profiledUser?) then res.redirect "/"
      else
        res.render "account.jade",
          user: profiledUser      # get the user out of session and pass to template
          isAuthenticated: true
  else 
    res.redirect "/"

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
router.get      '/document/:docId/nodes/names',        search.getNodeNames
router.get      '/document/:docId/getNodeByName',      search.getNodeByName
router.get      '/document/:docId/getNodesByTag',      search.getNodesByTag
router.get      '/document/:docId/getConnsByName',     search.getConnsByName
router.get      '/document/:docId/tags',               search.getTagNames

# User's Public  Page (needs to come last as the fallback route)
router.get /^\/(\w+)\/?$/, (req, res) ->
  username = req.params[0].toLowerCase()
  User.findOne { 'local.nameLower' :  username }, (err, profiledUser) ->
    if err or not(profiledUser?) then res.redirect "/"
    else
      documents.helper.getByIds profiledUser.documents, (usersDocs) ->
        if req.isAuthenticated() and username is req.user.local.nameLower
          # show all the documents if this is the profile for the logged in user
          privateDocs = (d for d in usersDocs when d.publicView isnt 2)
          publicDocs = (d for d in usersDocs when d.publicView is 2)
          ownProfile = req.user.local.name is profiledUser.local.name
        else # otherwise show only their public documents
          publicDocs = (d for d in usersDocs when d.publicView is 2)
          privateDocs = []
          ownProfile = false
        res.render "profile.jade",
          ownProfile: ownProfile  # checks to see if you are looking at your own profile
          user: profiledUser      # get the user out of session and pass to template
          publicDocs: publicDocs     # prefetch the users private documents
          privateDocs: privateDocs
          isAuthenticated: req.isAuthenticated()

module.exports = router
