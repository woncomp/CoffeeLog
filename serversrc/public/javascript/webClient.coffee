$ ()->

	`
	Array.prototype.mfRemove = function(obj) {
		for(var i in this) {
			if(this[i] === obj){
				this.splice(i, 1);
				return;
			}
		}
	};
	`

	class WebClient
		constructor: ()->
			@authorizations = []
			@sessions = []
			@currentAuthorization = null
			@currentSession = null
			@activeSessions = []
			@logs = []

		getLog: (logId)->
			@logs.push(null) until @logs.length > logId
			if @logs[logId] is null
				log = {id: logId, type:'_', message:null, trace:null}

				strLogId = "0000#{logId}"
				strLogId = strLogId.substring(strLogId.length-4)

				log.$messageLine = $("""
					<td></td>
					""")
				log.$dom = $("""
					<tr>
						<td style="width:60px">#{strLogId}</td>
					</tr>
					""")
				log.$dom.append log.$messageLine
				@logs[logId] = log
			return @logs[logId]

		addLog: (logId, logType, logMessage) ->
			log = @getLog(logId)
			log.type = logType
			log.message = logMessage
			log.$messageLine.html(logMessage)
			switch logType
				when 'I' then log.$dom.addClass("log-message-info")
				when 'W' then log.$dom.addClass("log-message-warning")
				when 'E' then log.$dom.addClass("log-message-danger")
			if not isFilterChecked(logType) then log.$dom.addClass("hidden")
			$logBox.append(log.$dom)
			$("body,html").animate( {scrollTop:$(window).height() }, 10)

		addTrace: (logId, logTrace) ->
			log = @getLog(logId)
			log.trace = logTrace

		sessionById: (id)->
			return session for session in @sessions when session.id == id

	$logBox = $("#logBox")
	$dropdown_authorization = $("#dropdown_authorization")
	$dropdown_session = $("#dropdown_session")
	$list_authorization = $("#list_authorization")
	$list_session = $("#list_session")
	$logFilterI = $("#logFilterI")
	$logFilterW = $("#logFilterW")
	$logFilterE = $("#logFilterE")

	webClient = new WebClient()

	isFilterChecked = (logType)->
		return $("#logFilter"+logType).hasClass("active")

	addListItem = ($list, text, callback)->
		id = Math.ceil(Math.random()*10000000+10000000).toString()
		$list.append(
			"""
			<li role="presentation">
				<a href="#" role="menuitem" tabIndex="-1" id="#{id}">
					#{text}
				</a>
			</li>
			"""
			)
		$id = $("##{id}")
		$id.click(callback)

	updateQuickEntriesDOM = ()->
		$buttons = $(".quick-entry-button")
		$buttons.children().html("-")
		$buttons.attr "disabled", "disabled"

		$dropdown_more = $("#dropdown_more")
		$dropdown_more.attr "disabled", "disabled"
		$list_more = $("#list_more")
		$list_more.empty();

		for index of webClient.activeSessions
			session = webClient.activeSessions[index]
			text = session.authorization
			makeClosure = (_session)->
				return ()->
					selectAuthorization _session.authorization
					selectSession _session
			callback = makeClosure(session)
			if index > 5
				$dropdown_more.removeAttr "disabled"
				addListItem $list_more, text, callback
			else
				$btn = $($buttons[index])
				$btn.removeAttr "disabled"
				$btn.click callback
				$btn.children().html(text)
				$btn.attr "title", session.title
				$btn.tooltip()

	updateOnlineStateDOM = ()->
		if webClient.currentSession.isActive
			$(".navbar-left>.label-success").removeClass("hidden")
			$(".navbar-left>.label-default").addClass("hidden")
		else
			$(".navbar-left>.label-success").addClass("hidden")
			$(".navbar-left>.label-default").removeClass("hidden")

	addAcctiveSession = (session)->
		webClient.activeSessions.unshift session
		session.isActive = true

	removeActiveSession = (session)->
		webClient.activeSessions.mfRemove session
		session.isActive = false
		updateOnlineStateDOM()

	selectAuthorization = (authorization)->
		webClient.currentAuthorization = authorization
		$("#dropdown_authorization>.pull-left").html("Authorization: "+authorization)
		$list_session.empty()
		$dropdown_session.attr("disabled", "disabled")
		for session in webClient.sessions when session.authorization is authorization
			$dropdown_session.removeAttr "disabled"
			makeClosure = (_session)-> return ()-> selectSession _session
			addListItem $list_session, session.title, makeClosure(session)

	selectSession = (session)->
		return if session is webClient.currentSession
		webClient.currentSession = session
		$("#dropdown_session>.pull-left").html("Session: " + session.title)
		$("#currentSession").html("#{session.title}@#{session.authorization}")
		server.send "INSPECT,"+session.id
		updateOnlineStateDOM()

	onInit = (obj)->
		webClient.authorizations = obj.authorizations
		webClient.sessions = obj.sessions
		for authorization in webClient.authorizations
			makeClosure = (_auth)-> return ()->selectAuthorization(_auth)
			addListItem $list_authorization, authorization, makeClosure(authorization)
		for sessionId in obj.activeSessions
			addAcctiveSession webClient.sessionById(sessionId)
		updateQuickEntriesDOM()

		$dropdown_authorization.removeAttr("disabled") if webClient.authorizations.length > 0

		appendLogMessage = (str)->
			$logBox.append("<div>" + str + "</div >")
			$("body,html").animate( {scrollTop:$(window).height() }, 10)
		appendLogMessage "Initialization completed."
		appendLogMessage "TODO: Export txt file"
		appendLogMessage "TODO: Init complete animation."
		appendLogMessage "TODO: Trace toggle"
		appendLogMessage "TODO: Trace expanding button"

	onReady = (logs)->
		$logBox.empty()
		webClient.addLog log.id, log.type, log.message for log in logs

	onLog = (log)->
		webClient.addLog log.id, log.type, log.message

	onBorn = (session)->
		webClient.sessions.push(session);
		addAcctiveSession session
		updateQuickEntriesDOM()
		if(webClient.currentAuthorization isnt null)
			selectAuthorization webClient.currentAuthorization

	onDied = (id)->
		removeActiveSession webClient.sessionById id
		updateQuickEntriesDOM()

	onDisconnect = ()->
		$(".dropdown>.dropdown-toggle").attr "disabled", "disabled"
		$(".quick-entry-button").attr "disabled", "disabled"
		$(".panel.panel-primary").parent().html("""<div class="alert alert-danger">Disconnected from server.</div>""")

	$(".logFilterRadio").parent().addClass("active")

	makeClosure_LogFilter = (logType, logClassName)->()->
		callback = ()->
			if isFilterChecked(logType)
				$(logClassName).removeClass("hidden")
			else
				$(logClassName).addClass("hidden")
		setTimeout callback, 0
	$logFilterI.click makeClosure_LogFilter("I", ".log-message-info")
	$logFilterW.click makeClosure_LogFilter("W", ".log-message-warning")
	$logFilterE.click makeClosure_LogFilter("E", ".log-message-danger")

	server = io.connect(window.location.origin, { reconnect: false })
	server.on "connect", ()->
		server.on "message", (msg)->
			console.log "ClientRecieveMessage: " + msg
		server.on "init", onInit
		server.on "ready", onReady
		server.on "log", onLog
		server.on "born", onBorn
		server.on "died", onDied
		server.on "disconnect", onDisconnect
		server.send "WEB"