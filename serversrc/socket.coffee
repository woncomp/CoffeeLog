

settings = require("./settings")

`
splitParams = function(str, count){
	var result = [];
	var remain = str;
	for(var _i=0;_i<count-1;++_i){
		var pos = remain.indexOf(",");
		if(pos >= 0){
			result.push(remain.substring(0, pos));
			remain = remain.substring(pos+1);
		}
	}
	result.push(remain);
	return result;
}

Array.prototype.remove = function(obj) {
	for(var i in this) {
		if(this[i] === obj){
			this.splice(i, 1);
			return;
		}
	}
};

Date.prototype.format = function (fmt) { //author: meizz 
    var o = {
        "M+": this.getMonth() + 1, //月份 
        "d+": this.getDate(), //日 
        "h+": this.getHours(), //小时 
        "m+": this.getMinutes(), //分 
        "s+": this.getSeconds(), //秒 
        "q+": Math.floor((this.getMonth() + 3) / 3), //季度 
        "S": this.getMilliseconds() //毫秒 
    };
    if (/(y+)/.test(fmt)) fmt = fmt.replace(RegExp.$1, (this.getFullYear() + "").substr(4 - RegExp.$1.length));
    for (var k in o)
    if (new RegExp("(" + k + ")").test(fmt)) fmt = fmt.replace(RegExp.$1, (RegExp.$1.length == 1) ? (o[k]) : (("00" + o[k]).substr(("" + o[k]).length)));
    return fmt;
}

`

class Client
	constructor: (@socket, @isWeb) ->
		@id = @socket.id

class GameClient extends Client
	constructor: (socket, @authorization) ->
		super(socket, false)
		@title = new Date().format("yyyy-MM-dd hh:mm:ss")
		@logs = []
		@webClients = []

	getLog: (logId)->
		@logs.push(null) until @logs.length > logId
		if @logs[logId] == null
			@logs[logId] = {id: logId, type:'_', message:null, trace:null}
		return @logs[logId]

	addLog: (logId, logType, logMessage) ->
		log = @getLog(logId)
		log.type = logType
		log.message = logMessage
		webClient.emitLog log for webClient in @webClients

	addTrace: (logId, logTrace) ->
		log = @getLog(logId)
		log.trace = logTrace

	toEssential: ()->
		return {id:@id, authorization:@authorization, title:@title}

class WebClient extends Client
	constructor: (socket) ->
		super(socket, true)
		@currentSession = null

	emitLog: (log)->
		l = log
		@socket.emit "log", {id:l.id, type:l.type, message:l.message}

	startInspect: (session)->
		@currentSession = session
		@currentSession.webClients.push(this)
		@socket.emit "ready", ({id:l.id, type:l.type, message:l.message} for l in @currentSession.logs when l isnt null)

	stopInspect: ()->
		return if @currentSession == null
		@currentSession.webClients.remove(this)
		@currentSession = null

	notifySessionBorn: (session)->
		@socket.emit "born", session.toEssential()

	notifySessionDied: (session)->
		@socket.emit "died", session.id

exports.listen = (server) ->
	activeAuthorizations = {}
	activeAuthorizations[name] = null for name in settings.authorizations
	clients = {}
	allSessions = []
	activeWebs = []
	activeSessions = []

	addActiveSession = (socketId)->
		allSessions.push(socketId)
		activeSessions.push(socketId)
		session = clients[socketId]
		clients[webClientId].notifySessionBorn(session) for webClientId in activeWebs

	removeActiveSession = (socketId)->
		activeSessions.remove(socketId)
		session = clients[socketId]
		clients[webClientId].notifySessionDied(session) for webClientId in activeWebs

	addActiveWeb = (socketId)->
		activeWebs.push(socketId)

	removeActiveWeb = (socketId)->
		activeWebs.remove(socketId)
		webClient = clients[socketId]
		webClient.stopInspect()
		delete clients[webClient]

	io = require("socket.io").listen(server)
	io.set('log level', 2)
	io.sockets.on "connection", (socket)->
		console.log "Connection " + socket.id + " accepted."
		socket.on "message", (message)->
			socketId = socket.id
			verb = splitParams(message, 2)
			switch verb[0]
# ================= GAME CLIENT ================
				when "CONNECT"
					authorization = verb[1]
					if authorization in settings.authorizations and activeAuthorizations[authorization] is null
						activeAuthorizations[authorization] = socketId
						client = clients[socketId] = new GameClient(socket, authorization)
						addActiveSession(socketId)
						socket.send "AS"
						# socket.send "AN"
					else
						socket.send "RN"
				when "LOG"
					client = clients[socketId]
					client.addLog splitParams(verb[1], 3)...
				when "TRACE"
					client = clients[socketId]
					client.addTrace splitParams(verb[1], 2)...
# ================= WEB CLIENT ================
				when "WEB"
					client = clients[socketId] = new WebClient(socket)
					addActiveWeb(socketId)

					clientData = {}
					clientData.authorizations = settings.authorizations
					clientData.sessions = (clients[tempId].toEssential() for tempId in allSessions)
					clientData.activeSessions = activeSessions
					socket.emit "init", clientData
				when "INSPECT"
					client = clients[socketId]
					client.startInspect(clients[verb[1]])
# ==================== ERROR ===================
				else
					console.log "Unknown message verb: [" + verb[0] + "] from - " + message
		socket.on "disconnect", ()->
			console.log "Connection " + socket.id + " terminated."
			client = clients[socket.id]
			if client instanceof GameClient
				activeAuthorizations[client.authorization] = null
				removeActiveSession(socket.id)
				console.log "GameClient closed"
			else if client instanceof WebClient
				removeActiveWeb(socket.id)
				console.log "WebClient closed"