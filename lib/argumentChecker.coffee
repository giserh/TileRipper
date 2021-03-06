_ = require 'underscore'
childProcess = require 'child_process'


module.exports = class ArgumentChecker 
	@checkLayerIds: (layerIds) ->
		if not (/^[0-9]+(,[0-9]+){0,}$/.test layerIds)
			throw new Error("Layer IDs string '#{layerIds}' is not in the format 1{,2,3,4}")

	@checkLongitude: (west, east) ->
		if(west > east) then throw new Error("West longitudinal extent #{west} cannot be east of eastern extent #{east}")

	@checkForPackagingTools: () ->
		try
			childProcess.execSync 'mb-util -h'
		catch e
			console.log e
			throw new Error("mb-util not present, but is required for packaging.  Install mb-util first.")
		console.log "mb-util found"



