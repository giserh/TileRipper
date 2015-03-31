ChildProcess = require 'child_process'
Archiver = require 'archiver'
fs = require 'fs'


_build_json_metadata = (args, type, version, ntiles) ->
	json = {}
	json.time = new Date()
	json.mapservice = args.mapservice
	json.minZoom = args.minZoom
	json.maxZoom = args.maxZoom
	json.westLong = args.westlong
	json.eastLong = args.eastlong
	json.southLat = args.southlat
	json.northLat = args.northlat
	json.mapServiceType = type
	json.tileRipperVersion = version
	json.nTiles = ntiles
	json.commandLine = process.argv.toString().replace /,/g, ' '
	json


_build_mbtiles_file = (input_dir, output_filename, cb) ->

	fs.unlink output_filename, (err) ->
		if err then return cb err
		child = ChildProcess.spawn "mb-util", [input_dir, output_filename], {}

		child.stdout.on 'data', (buf) ->
			console.log buf.toString()


		child.stderr.on 'data', (buf) ->
			console.log buf.toString()

		child.on 'close', (code) ->
			console.log "mb-util exited with code #{code}"
			if not (code is 0) then throw new Error("Could not convert raw tiles to a .mbtiles file: #{code}")
			else return cb output_filename
	

module.exports.packageTiles = (args, type, version, ntiles, cb) ->
	console.log "Packaging tiles & metadata..."
	metadata = _build_json_metadata args, type, version, ntiles
	prefix = "tiles_" + new Date().getTime()

	_build_mbtiles_file args.output, 'data.mbtiles', (mbtiles_filename) ->

		archiver = Archiver.create('zip')
		zipstream = archiver.pipe fs.createWriteStream(prefix + '.zip')
		archiver.append JSON.stringify(metadata, null, 4), {name: "metadata.json"}
		archiver.file mbtiles_filename, {name: "data.mbtiles"}
		archiver.finalize()
		
		zipstream.on 'end', () ->
			console.log "Packaging complete."
			cb()




	






