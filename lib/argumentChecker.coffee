_ = require 'underscore'


module.exports = class ArgumentChecker 
	@checkLayerIds: (layerIds) ->
		if not (/^[0-9]+(,[0-9]+){0,}$/.test layerIds)
			throw new Error("Layer IDs string '#{layerIds}' is not in the format 1{,2,3,4}")

	@checkLongitude: (west, east) ->
		if(west > east) then throw new Error("West longitudinal extent #{west} cannot be east of eastern extent #{east}")


