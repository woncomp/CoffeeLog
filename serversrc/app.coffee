http = require("http")
url = require("url")
fs = require("fs")
node_static = require("node-static")
jade = require("jade")

settings = require("./settings")

staticServer = new node_static.Server "./public"

server = http.createServer (req, res)->
	path = url.parse(req.url).pathname
	switch path
		when "/"
			res.writeHead 200, {"Content-Type": "text/html"}
			res.write jade.renderFile("views/index.jade")
			res.end()
		else
			# send404 res
			staticServer.serve req, res


send404 = (res)->
	res.writeHead 404
	res.write "404 Not found."
	res.end()
 
server.listen settings.port
require("./socket").listen(server)