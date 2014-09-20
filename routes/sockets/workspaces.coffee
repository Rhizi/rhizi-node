url = process.env['GRAPHENEDB_URL'] || 'http://localhost:7474'
neo4j = require '../../node_modules/neo4j'
graphDb = new neo4j.GraphDatabase url
utils = require '../utils'

WorkspaceHelper = require '../helpers/WorkspaceHelper'
serverWorkspace = new WorkspaceHelper(graphDb)

# CREATE
exports.create = (data, callback, socket) ->
  console.log 'create workspace query requested'
  newWorkspace = data
  serverWorkspace.create newWorkspace, (savedWorkspace) ->
    socket.emit('workspace:create', savedWorkspace)
    callback(null, savedWorkspace)

# READ
exports.read = (data, callback, socket) ->
  id = data._id
  graphDb.getNodeById id, (err, node) ->
    # checks to make sure that the node is a workspace
    # as only workspaces have the .nodeTags property
    if err or not node._data.data.nodeTags?
      socket.emit 'workspace:read', err
      callback null, {err:true, errText:err}
    else
      parsed = utils.parseNodeToClient node._data.data
      socket.emit 'workspace:read', parsed
      callback null, parsed

# DELETE
exports.destroy = (data, callback, socket) ->
  id = parseInt data
  graphDb.getNodeById id, (err, node) ->
    node.delete () ->
      parsed = node._data.data
    , true
