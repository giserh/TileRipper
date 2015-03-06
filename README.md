TileRipper
==========

grab Web Mercator tiles from an ESRI Dynamic, Image or Tiled Map Service

```
Optional arguments:
  -h, --help            Show this help message and exit.
  -v, --version         Show program's version number and exit.
  -m MAPSERVICEURL, --mapservice MAPSERVICEURL
                        Url of the ArcGIS Dynamic/Image Map Service to be cached
  -o OUTPUTFILE, --output OUTPUTFILE
                        Location of generated tile cache
  -r, --resume          Resume ripping or add tiles to an existing tile 
                        directory
  -z ZOOMLEVEL, --minzoom ZOOMLEVEL
                        Minimum zoom level to cache
  -Z ZOOMLEVEL, --maxzoom ZOOMLEVEL
                        Maximum zoom level to cache
  -x LONGITUDE, --westlong LONGITUDE
                        Westernmost decimal longitude
  -X LONGITUDE, --eastlong LONGITUDE
                        Easternmost decimal longitude
  -y LATITUDE, --southlat LATITUDE
                        Southernmost decimal latitude
  -Y LATITUDE, --northlat LATITUDE
                        Northernmost decimal latitude
  -c REQUESTS, --concurrentops REQUESTS
                        Max number of concurrent tile requests
  -n, --noripping       Skip the actual ripping of tiles; just do the tile 
                        analysis and report
  -l, --layerids        Ids of the sublayers to include in the tiles (default 
                        is all)
  -p, --package         Create a ZIP package of tile data and metadata
  ```


TileRipper generates a map tile set from any available ESRI dynamic, image, or tiled map service.  It doesn't work for ESRI feature services, since they serve vector and not raster data.  The resulting tile set directory can be converted into MBTiles format using MBUtil (https://github.com/mapbox/mbutil), or if you use the packaging option (-p), TileRipper will attempt to package the tiles into a MBTiles file for you.  

Example:

 ```coffee -- tileripper.coffee -m http://egisws02.nos.noaa.gov/ArcGIS/rest/services/RNC/NOAA_RNC/MapServer -n -o tiledir -x -125.0 -X -119.0 -y 33.0 -Y 40.0 -z 0 -Z 1```
