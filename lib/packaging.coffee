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
	json


_build_mbtiles_file = (input_dir, output_filename, cb) ->
	child = ChildProcess.exec "mb-util #{input_dir} #{output_filename}", (err, stdout, stderr) ->
		if err then throw new Error("Could not convert raw tiles to a .mbtiles file: #{err.message}")
		cb output_filename



module.exports.packageTiles = (args, type, version, ntiles) ->
	console.log "Packaging tiles & metadata..."
	metadata = _build_json_metadata args, type, version, ntiles
	prefix = "tiles_" + new Date().getTime()

	_build_mbtiles_file args.output, 'data.mbtiles', (mbtiles_filename) ->

		archiver = Archiver.create('zip')
		archiver.append JSON.stringify(metadata, null, 4), {name: "#{prefix}/metadata.json"}
		archiver.file mbtiles_filename, {name: "#{prefix}/data.mbtiles"}
		archiver.pipe fs.createWriteStream(prefix + '.zip')
		archiver.finalize()



	console.log "Packaging complete."






