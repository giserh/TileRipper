_ = require 'underscore'
async = require 'async'
request = require 'request'
ArgumentParser = require('argparse').ArgumentParser
fs = require 'fs'
ProgressBar = require 'progress'
Constants = require './lib/constants'
ArgumentChecker = require './lib/argumentChecker'


mapSize = (levelOfDetail) ->
  256 << levelOfDetail

clip = (n, min, max) ->
  return Math.min(Math.max(n, min), max)


#Meters per pixel at given latitude
groundResolution = (latitude, levelOfDetail) ->
  latitude = clip latitude, Constants.MINLATITUDE, Constants.MAXLATITUDE
  Math.cos(latitude * Math.PI / 180) * 2 * Math.PI * Constants.EARTHRADIUS / mapSize(levelOfDetail)

mapScale = (latitude, levelOfDetail, screenDpi) ->
  groundResolution(latitude, levelOfDetail) * screenDpi / 0.0254

# /// <summary>
#         /// Converts a point from latitude/longitude WGS-84 coordinates (in degrees)
#         /// into pixel XY coordinates at a specified level of detail.
#         /// </summary>
#         /// <param name="latitude">Latitude of the point, in degrees.</param>
#         /// <param name="longitude">Longitude of the point, in degrees.</param>
#         /// <param name="levelOfDetail">Level of detail, from 1 (lowest detail)
#         /// to 23 (highest detail).</param>
#   Returns array [pixelx, pixely]
latLongToPixelXY = (latitude, longitude, levelOfDetail) ->
  latitude = clip(latitude, Constants.MINLATITUDE, Constants.MAXLATITUDE)
  longitude = clip(longitude, Constants.MINLONGITUDE, Constants.MAXLONGITUDE)

  x = (longitude + 180) / 360 
  sinLatitude = Math.sin(latitude * Math.PI / 180)
  y = 0.5 - Math.log((1 + sinLatitude) / (1 - sinLatitude)) / (4 * Math.PI)

  mapsize = mapSize(levelOfDetail)
  pixelX = Math.floor clip(x * mapsize + 0.5, 0, mapsize - 1)
  pixelY = Math.floor clip(y * mapsize + 0.5, 0, mapsize - 1)
  [pixelX, pixelY]


# /// <summary>
# /// Converts a pixel from pixel XY coordinates at a specified level of detail
# /// into latitude/longitude WGS-84 coordinates (in degrees).
# /// </summary>
# /// <param name="pixelX">X coordinate of the point, in pixels.</param>
# /// <param name="pixelY">Y coordinates of the point, in pixels.</param>
# /// <param name="levelOfDetail">Level of detail, from 1 (lowest detail)
# /// to 23 (highest detail).</param>
# Return [lat, long]
pixelXYToLatLong = (pixelX, pixelY, levelOfDetail) ->
  mapsize = mapSize(levelOfDetail)
  x = (clip(pixelX, 0, mapsize - 1) / mapsize) - 0.5
  y = 0.5 - (clip(pixelY, 0, mapsize - 1) / mapsize)
  latitude = 90 - 360 * Math.atan(Math.exp(-y * 2 * Math.PI)) / Math.PI
  longitude = 360 * x
  [latitude, longitude]

# /// <summary>
# /// Converts pixel XY coordinates into tile XY coordinates of the tile containing
# /// the specified pixel.
# /// </summary>
# /// <param name="pixelX">Pixel X coordinate.</param>
# /// <param name="pixelY">Pixel Y coordinate.</param>
pixelXYToTileXY = (pixelX, pixelY) ->
  tileX = Math.floor (pixelX / 256)
  tileY = Math.floor (pixelY / 256)
  [tileX, tileY]

# /// <summary>
# /// Converts tile XY coordinates into pixel XY coordinates of the upper-left pixel
# /// of the specified tile.
# /// </summary>
# /// <param name="tileX">Tile X coordinate.</param>
# /// <param name="tileY">Tile Y coordinate.</param>
tileXYToPixelXY = (tileX, tileY) ->
  pixelX = Math.floor (tileX * 256)
  pixelY = Math.floor (tileY * 256)
  [pixelX, pixelY]

# Returns [xmin, ymin, xmax, ymax]
boundingBoxForTile = (tileX, tileY, levelOfDetail) ->

  longMetersPerTile = (Constants.XMAX - Constants.XMIN) / (2 << (levelOfDetail-1))
  latMetersPerTile = (Constants.YMAX - Constants.YMIN) / (2 << (levelOfDetail-1))
  tileAxis = (2 << (levelOfDetail-1))

  minXMeters = Constants.XMIN + (tileX * longMetersPerTile)
  maxXMeters = Constants.XMIN + (tileX * longMetersPerTile) + longMetersPerTile

  maxYMeters = Constants.YMAX - (tileY * latMetersPerTile)
  minYMeters = Constants.YMAX - (tileY * latMetersPerTile) - latMetersPerTile

  [minXMeters, minYMeters, maxXMeters, maxYMeters]


checkOutputDirectory = (path, resume) ->
  if fs.existsSync path
    if resume
      console.log "Resuming tiling into #{path}"
    else
      console.log "Output directory #{path} already exists; refusing to overwrite!"
      process.exit()
  else
    if resume 
      console.log "Warning: you have chosen to resume a tiling operation, but your output directory doesn't exist."
    try
      fs.mkdirSync path
    catch e
      console.log "Couldn't create an output directory at #{path}: ", e
      process.exit()    

mapserviceType = null

parser = new ArgumentParser
  version: '0.0.3'
  addHelp:true
  description: 'TileRipper - grab Web Mercator tiles from ESRI Dynamic, Image, and Tiled Map Services'

parser.addArgument [ '-m', '--mapservice' ], { help: 'Url of the map service to be cached', metavar: "MAPSERVICEURL", required: true }
#parser.addArgument [ '-l', '--layers'], {help: 'List of layers (in ESRI URL format) to capture: \"1,2,4\"', metavar: "LAYERSTRING", required: true }
parser.addArgument [ '-o', '--output' ], { help: 'Location of generated tile cache', metavar: "OUTPUTFILE", required: true}
parser.addArgument [ '-r', '--resume'] , {help: "Resume ripping or add tiles to an existing tile directory", nargs : 0, defaultValue: false, action: 'storeTrue'}
parser.addArgument [ '-z', '--minzoom' ], { help: 'Minimum zoom level to cache', metavar: "ZOOMLEVEL", defaultValue: 1 }
parser.addArgument [ '-Z', '--maxzoom' ], { help: 'Maximum zoom level to cache', metavar: "ZOOMLEVEL" , defaultValue: 23}
parser.addArgument [ '-x', '--westlong' ], { help: 'Westernmost decimal longitude', metavar: "LONGITUDE", required: true }
parser.addArgument [ '-X', '--eastlong' ], { help: 'Easternmost decimal longitude', metavar: "LONGITUDE", required: true }
parser.addArgument [ '-y', '--southlat' ], { help: 'Southernmost decimal latitude', metavar: "LATITUDE", required: true }
parser.addArgument [ '-Y', '--northlat' ], { help: 'Northernmost decimal latitude', metavar: "LATITUDE", required: true }
parser.addArgument [ '-c', '--concurrentops' ], { help: 'Max number of concurrent tile requests (default is 8)', metavar: "REQUESTS", defaultValue: 8 }
parser.addArgument [ '-n', '--noripping' ], { help: "Skip the actual ripping of tiles; just do the tile analysis and report", nargs: 0, defaultValue: false, action: 'storeTrue'}
parser.addArgument [ '-l', '--layerids'], {help: "Ids of the sublayers to include in the tiles (default is all}", defaultValue: 'all'}

args = parser.parseArgs()

request.get args.mapservice + '?f=json', (err, response, body) ->
  if err then throw err
  if body.singleFusedMapCache
    console.log 'ESRI tiled map service found'
    mapserviceType = 'tiled'
  else if /MapServer\/*$/.test args.mapservice
    mapserviceType = 'dynamic'
    console.log "ESRI dynamic map service found"
  else if /ImageServer\/*$/.test args.mapservice
    mapserviceType = 'image'
    console.log "ESRI image service found"
  else
    console.log "Map service #{args.mapservice} is not a recognized type of service."
    process.exit -1

  args.westlong = parseFloat args.westlong
  args.eastlong = parseFloat args.eastlong
  args.northlat = parseFloat args.northlat
  args.southlat = parseFloat args.southlat
  args.minzoom = parseInt args.minzoom
  args.maxzoom = parseInt args.maxzoom
  if args.resume then console.log "Resuming tiling operation"

  unless (args.layerids is 'all') 
    ArgumentChecker.checkLayerIds args.layerids
  ArgumentChecker.checkLongitude args.westlong, args.eastlong


  zoomLevel = args.minzoom
  totalTiles = 0
  missingTiles = 0
  nDownloaded = 0
  while zoomLevel <= args.maxzoom
    console.log "Calculating level #{zoomLevel}"

    nw = latLongToPixelXY args.northlat, args.westlong,  zoomLevel
    ne = latLongToPixelXY args.northlat, args.eastlong,  zoomLevel
    sw = latLongToPixelXY args.southlat, args.westlong,  zoomLevel
    se = latLongToPixelXY args.southlat, args.eastlong,  zoomLevel

    nwtile = pixelXYToTileXY nw[0], nw[1]
    netile = pixelXYToTileXY ne[0], ne[1]
    swtile = pixelXYToTileXY sw[0], sw[1]
    setile = pixelXYToTileXY se[0], se[1]

    ntiles = (setile[0] - nwtile[0] + 1) * (setile[1] - nwtile[1] + 1)
    totalTiles += ntiles

    if args.resume
      for xtile in [nwtile[0]..netile[0]]
        for ytile in [nwtile[1]..swtile[1]]
          if not fs.existsSync "#{args.output}/#{zoomLevel}/#{xtile}/#{ytile}.png" then missingTiles += 1

    zoomLevel = zoomLevel += 1

  if args.resume then console.log "Total tiles for cache: #{totalTiles} Number missing from cache: #{missingTiles}"
  else console.log "Total tiles to rip: #{totalTiles}"

  if args.noripping then process.exit()
  if args.resume and (missingTiles <= 0) then process.exit()

  checkOutputDirectory args.output, args.resume

  bar = new ProgressBar('   Downloading tiles [:bar] :percent estimated time remaining: :etas', 
    total: totalTiles or missingTiles 
    incomplete: ' '
    width: 40
    );

  uri = args.mapservice
  if mapserviceType is 'dynamic'
    uri = uri + '/export'
  else if mapserviceType is 'image'
    uri = uri + '/exportImage'
  else if mapserviceType is 'tiled'
    uri = uri + '/tile'
  queue = async.queue (task, callback) ->
      if mapserviceType is 'tiled'
        urithis = uri + '/' + task.zoomLevel + '/' + task.ytile + '/' + task.xtile
      else
        bbox = boundingBoxForTile task.xtile, task.ytile, task.zoomLevel
        urithis = uri + "?bbox=#{bbox[0]},#{bbox[1]},#{bbox[2]},#{bbox[3]}"
        urithis = urithis + "&bboxSR=3857"
        if mapserviceType is 'dynamic'
          unless (args.layerids is 'all')
            urithis = urithis + "&layers=show:#{args.layerids}"
        urithis = urithis + "&size=256,256&imageSR=3857"
        urithis = urithis + "&format=png8&transparent=false&dpi=96&f=image"
        #console.log urithis
      path = "#{args.output}/#{task.zoomLevel}/#{task.xtile}/#{task.ytile}.png"
      #console.log path
      r = request(urithis)
      r.on "end", () ->
        #console.log "End called"
        bar.tick 1
        callback()
      r.pipe(fs.createWriteStream(path))

    , args.concurrentops

  queue.drain = () ->
    console.log "Queue drained of all tasks"

  zoomLevel = args.minzoom
  while zoomLevel <= args.maxzoom
    console.log "Tiling level #{zoomLevel}"
    if not fs.existsSync "#{args.output}/#{zoomLevel}" then fs.mkdirSync "#{args.output}/#{zoomLevel}"

    nw = latLongToPixelXY args.northlat, args.westlong,  zoomLevel
    ne = latLongToPixelXY args.northlat, args.eastlong,  zoomLevel
    sw = latLongToPixelXY args.southlat, args.westlong,  zoomLevel
    se = latLongToPixelXY args.southlat, args.eastlong,  zoomLevel
    nwtile = pixelXYToTileXY nw[0], nw[1]
    netile = pixelXYToTileXY ne[0], ne[1]
    swtile = pixelXYToTileXY sw[0], sw[1]
    setile = pixelXYToTileXY se[0], se[1]

    for xtile in [nwtile[0]..netile[0]]
      if not fs.existsSync "#{args.output}/#{zoomLevel}/#{xtile}" then fs.mkdirSync "#{args.output}/#{zoomLevel}/#{xtile}"
      for ytile in [nwtile[1]..swtile[1]]
        if not fs.existsSync "#{args.output}/#{zoomLevel}/#{xtile}/#{ytile}.png"
          queue.push {xtile: xtile, ytile:ytile, zoomLevel:zoomLevel}, (err) ->
            if err
              console.log err
              process.exit()


    zoomLevel = zoomLevel += 1
