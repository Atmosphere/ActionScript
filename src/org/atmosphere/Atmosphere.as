package org.atmosphere
	/*
	* Copyright 2014 Todor Dimitrov
	*
	* Licensed under the Apache License, Version 2.0 (the "License");
	* you may not use this file except in compliance with the License.
	* You may obtain a copy of the License at
	*
	* http://www.apache.org/licenses/LICENSE-2.0
	*
	* Unless required by applicable law or agreed to in writing, software
	* distributed under the License is distributed on an "AS IS" BASIS,
	* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
	* See the License for the specific language governing permissions and
	* limitations under the License.
	*/
{
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.net.URLRequestMethod;
	import flash.net.sendToURL;
	import flash.utils.ByteArray;
	import flash.utils.clearInterval;
	import flash.utils.clearTimeout;
	import flash.utils.getTimer;
	import flash.utils.setInterval;
	import flash.utils.setTimeout;
	
	import mx.core.FlexGlobals;
	import mx.messaging.messages.HTTPRequestMessage;
	import mx.rpc.http.HTTPService;
	import mx.utils.StringUtil;
	
	import net.gimite.websocket.WebSocket;
	import net.gimite.websocket.WebSocketEvent;

	public class Atmosphere extends EventDispatcher
	{
		//constants
		private static const VERSION:String = "2.2.3-javascript";
		private static const MESSAGE_DELIMITER:String = "|";

		private static const PROTOCOL_FILE:String = "file:///";
		private static const PROTOCOL_HTTP:String = "http://";
		private static const PROTOCOL_HTTPS:String = "https://";
		private static const PROTOCOL_WS:String = "ws://";
		private static const PROTOCOL_WSS:String = "wss://";
		
		private static const HEADER_TRACKID:String = "X-Atmosphere-tracking-id";
		private static const HEADER_FRAMEWORK:String = "X-Atmosphere-Framework";
		private static const HEADER_TRANSPORT:String = "X-Atmosphere-Transport";
		private static const HEADER_HEARTBEAT:String = "X-Heartbeat-Server";
		private static const HEADER_TRACKSIZE:String = "X-Atmosphere-TrackMessageSize";
		private static const HEADER_CONTENTTYPE:String = "Content-Type";			
		private static const HEADER_USEPROTOCOL:String = "X-atmo-protocol";

		private static const HEADER_USEBINARY:String = "X-Atmosphere-Binary";

		private static const DEF_ACK:String = "...ACK...";		
		
		public static const TRANSPORT_WEBSOCKET:String = "websocket";
		public static const TRANSPORT_LONG_POLLING:String = "long-polling";
		
		private static const TRANSPORT_POLLING:String = "polling";//used only internal
		private static const TRANSPORT_CLOSE:String = "close";//used only internal
		//private static const TRANSPORT_JSONP:String = "jsonp";//unimplemented not advantages in flash player
		//private static const TRANSPORT_SSE:String = "sse";//not supported in flash player as of now
		//private static const TRANSPORT_STREAMING:String = "streaming";//still w3c draft as of 14.10.2014, not supported in flash player
		
		//obvios constants
		private static const MILLISINASECOND:int = 1000;
		
		private var setting:AtmosphereSetting = null;
		//xhr vars
		
		//websocket vars
		private var wsObj:WebSocket = null;
		private var wsOpenedOnce:Boolean = false;
		private var wsEstablished:Boolean = false;
		private var wsCanSendMsg:Boolean = false;
		
		//long-polling
		private var hsReceive:URLLoader = null;
		private var hsOpenedOnce:Boolean = false;
		private var hsEstablished:Boolean = false;
		private var hsCanSendMsg:Boolean = false;
		
		//connection vars
		private var cUuid:String = "0";
		private var cUrl:String = "0";

		private var cHeartbeatInterval:int = 0;
		private var cHeartbeatString:String = "";
		private var cHeartbeatTimer:int = 0;
		
		private var cAckTimer:int = 0;
		
		//incomming messages vars
		private var inIsFirst:Boolean = true;
		private var inReceived:String = null;
		private var inLengthToReceive:int = 0;
		
		//state vars
		private var sClientClosed:Boolean = false;
		private var sTransportIndex:int = 0;
		private var sRequestTimer:int = 0;
		private var sReconnectTimer:int = 1;
		private var sRetryCount:int = 0;

		//public methods
		public function Atmosphere(setting:AtmosphereSetting) {
			this.setting = setting;
//			if (setting.useBinary)
//				setting.trackMessageLength = false;
			cUrl = getUrl(); 
			if (setting.externUuid)
				cUuid = setting.externUuid; 
			connect();
		}

		public function open(externUuid:String = null):void {
			if (!externUuid)
				cUuid = externUuid;
			connect();
			
		}

		public function close():void {
			if (sClientClosed)
				return;
			sClientClosed = true;
			disconnect();
		}

		public function push(message:*):void {
			if (setting.useBinary) {
				var bt:ByteArray = new ByteArray();
				bt.writeUTF(message is String ? message as String : JSON.stringify(message));
				pushBinary(bt, false);
			} else
				pushString(message is String ? message : JSON.stringify(message), false);
		}
		
		public function get uuid():String {
			return cUuid == "0" ? null : cUuid;
		}

		public function get transport():String {
			return currentTransport();
		}

		//dispatching function
		protected function connect():void {
			clearState();
			switch (currentTransport()) {
				case TRANSPORT_WEBSOCKET: {
					connectWS();
					break;
				}
				case TRANSPORT_LONG_POLLING: {
					connectHS();
					break;
				}
				default: {
					disconnect();
					return;
				}
			}
		}
		
		protected function disconnect():void {
			clearState();
			dispatchEvent(createEvent(AtmosphereEvent.onClose));						
		}

		protected function clearState():void {
			changeRequestTimer(false);
			changeReconnectTimer(false);
			changeHearbeatTimer(false);
			changeAckTime(false);
			inIsFirst = cUuid == "0";
			removeWS();
			removeHS();
		}
		
		protected function changeRequestTimer(enable:Boolean):void {
			if (sRequestTimer)
				clearTimeout(sRequestTimer);
			sRequestTimer = 0;
			if (enable && setting.requestTimeout)
				sRequestTimer = setTimeout(requestTimer, setting.requestTimeout * MILLISINASECOND);
		}
		
		protected function requestTimer():void {
			if (!sRequestTimer)
				return;
			sRequestTimer = 0;
			sClientClosed = true;
			dispatchEvent(createEvent(AtmosphereEvent.onClientTimeout));						
			disconnect();
		}
		
		protected function changeReconnectTimer(enable:Boolean):void {
			if (!enable && sReconnectTimer)
				clearTimeout(sReconnectTimer);
			sReconnectTimer = 0;
			if (enable) {
				dispatchEvent(createEvent(AtmosphereEvent.onReconnect));						
				if (setting.reconnectTimeout)
					sReconnectTimer = setTimeout(reconnectTimer, setting.reconnectTimeout * MILLISINASECOND);
				else
					reconnectTimer();
			}
		}

		protected function reconnectTimer():void {
			sRetryCount++;
			if (setting.reconnectMaxCount <= sRetryCount) {
				dispatchError(0, "maxReconnectOnClose reached");
				moveToNextTransport();
			} else
				connect();
		}

		protected function moveToNextTransport():void {
			sRetryCount = 0;
			dispatchEvent(createEvent(AtmosphereEvent.onTransportFailure));									
			sTransportIndex++;
			connect();
		}

		protected function pushString(message:String, isInternal:Boolean):void {
			if (wsObj) {
				if (wsObj.send(message) && !isInternal)
					dispatchMsgPublished(message);
			} else if (hsReceive)
				hsPushMsg(message, isInternal);
		}

		protected function pushBinary(message:ByteArray, isInternal:Boolean):void {
			if (wsObj)
				if (wsObj.send(message) && !isInternal)
					dispatchMsgPublished(message);
			//else if (hsReceive)
				//hsPushMsg(message);
		}

		private function sendClose(webSocket:WebSocket):void {
			if (!uuid)
				return;
			var request:URLRequest = new URLRequest(formatUrlForHs(cUrl, TRANSPORT_CLOSE));
			request.data = "";
			request.method = URLRequestMethod.GET;
			var receive:URLLoader = new URLLoader();
			var closedFailedOrSuccess:Function = function (event:Event):void {if (webSocket) webSocket.close();	};
			receive.addEventListener(Event.COMPLETE, closedFailedOrSuccess);
			receive.addEventListener(SecurityErrorEvent.SECURITY_ERROR, closedFailedOrSuccess);
			receive.addEventListener(IOErrorEvent.IO_ERROR, closedFailedOrSuccess);
			try {
				receive.load(request);
			} catch (error:Error) {
				closedFailedOrSuccess(null);
			}
		}
		
		//websocket special functions		
		protected function removeWS():void {
			if (wsObj) {
				wsObj.removeEventListener(WebSocketEvent.ERROR, websocketEvent);
				wsObj.removeEventListener(WebSocketEvent.CLOSE, websocketEvent);
				wsObj.removeEventListener(WebSocketEvent.OPEN, websocketEvent);
				wsObj.removeEventListener(WebSocketEvent.TEXT, websocketEvent);
				wsObj.removeEventListener(WebSocketEvent.BINARY, websocketEvent);
				sendClose(wsObj);
				//wsObj.close();
			}
			wsObj = null;
		}
		
		protected function connectWS():void {
			wsEstablished = false;
			wsObj = new WebSocket(0, formatUrlForWs(cUrl), [], null, null, null, setting.proxyHost, setting.proxyPort);
			wsObj.addEventListener(WebSocketEvent.ERROR, websocketEvent);
			wsObj.addEventListener(WebSocketEvent.CLOSE, websocketEvent);
			wsObj.addEventListener(WebSocketEvent.OPEN, websocketEvent);
			wsObj.addEventListener(WebSocketEvent.TEXT, websocketEvent);
			wsObj.addEventListener(WebSocketEvent.BINARY, websocketEvent);
		}
		
		protected function websocketEvent(event:WebSocketEvent):void {
			switch(event.type) {
				case WebSocketEvent.OPEN: {
					changeRequestTimer(true);
					wsCanSendMsg = true;
					if (!setting.enableAtmoProtocol)
						wsSucceded();
					break;
				}
				case WebSocketEvent.CLOSE: {
					changeHearbeatTimer(false);
					changeAckTime(false);
					changeRequestTimer(false);
					if (sClientClosed)
						return;
					if (wsOpenedOnce) {
						changeReconnectTimer(true);
						return;
					}
					break;
				}
				case WebSocketEvent.ERROR: {
					break;
				}
				case WebSocketEvent.TEXT: {
					changeRequestTimer(true);
					if (setting.enableAtmoProtocol && !wsEstablished)
						wsSucceded();
					parseIncommingMessage(unescape(event.message as String));
					break;
				}
				case WebSocketEvent.BINARY: {
					var ba:ByteArray = (event.message as ByteArray);
					parseIncommingMessage((event.message as ByteArray).toString());
					break;//do something???
				}
			}
		}
		
		protected function wsSucceded():void {
			dispatchOpenEvent(wsOpenedOnce);
			sRetryCount = 0;
			wsEstablished = true;
			wsOpenedOnce = true;
			changeRequestTimer(true);
		}
		
		//long-polling
		protected function removeHS():void {
			if (hsReceive) {
				hsReceive.removeEventListener(Event.COMPLETE, hsCompleteHandler);
				hsReceive.removeEventListener(Event.OPEN, hsOpenHandler);
				hsReceive.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, hsSecurityErrorHandler);
				hsReceive.removeEventListener(IOErrorEvent.IO_ERROR, hsIoErrorHandler);
				hsReceive.close();
				sendClose(null);
			}
			hsReceive = null;
		}
		
		private function hsCompleteHandler(event:Event):void {
			if (!hsEstablished)
				hsSucceded();
			parseIncommingMessage(event.target.data);
			if (!hsSendRequest())
				changeReconnectTimer(true);
		}
		
		private function hsOpenHandler(event:Event):void {
			if (hsOpenedOnce && !hsEstablished)
				hsSucceded();
		}
		
		private function hsSecurityErrorHandler(event:SecurityErrorEvent):void {
			hsFault();
		}
		
		private function hsIoErrorHandler(event:IOErrorEvent):void {
			hsFault();
		}
		
		protected function hsSucceded():void {
			dispatchOpenEvent(hsOpenedOnce);
			sRetryCount = 0;
			hsEstablished = true;
			hsOpenedOnce = true;
			changeRequestTimer(true);
		}

				
		private function hsFault():void {
			changeHearbeatTimer(false);
			changeAckTime(false);
			changeRequestTimer(false);
			if (sClientClosed)
				return;
			if (hsOpenedOnce)
				changeReconnectTimer(true);
			else
				moveToNextTransport();
		}

		
		
		protected function connectHS():void {
			hsEstablished = false;
			hsReceive = new URLLoader();
			hsReceive.addEventListener(Event.COMPLETE, hsCompleteHandler);
			hsReceive.addEventListener(Event.OPEN, hsOpenHandler);
			hsReceive.addEventListener(SecurityErrorEvent.SECURITY_ERROR, hsSecurityErrorHandler);
			hsReceive.addEventListener(IOErrorEvent.IO_ERROR, hsIoErrorHandler);
			if (!hsSendRequest())
				moveToNextTransport();
		}	
		
		protected function hsSendRequest():Boolean {
			var request:URLRequest = new URLRequest(formatUrlForHs(cUrl, null));
			request.contentType = "text/plain";
			request.method = HTTPRequestMessage.GET_METHOD;
			try {
				hsReceive.load(request);
			} catch (error:Error) {
				return false;
			}
			return true;
		}

		private function hsPushMsg(message:String, isInternal:Boolean):void {
			var request:URLRequest = new URLRequest(formatUrlForHs(cUrl, TRANSPORT_POLLING));
			request.data = message;
			request.method = URLRequestMethod.POST;
			var receive:URLLoader = new URLLoader();
			if (!isInternal) {
				var sendOnSuccess:Function = function (event:Event):void {dispatchMsgPublished(message);};
				receive.addEventListener(Event.COMPLETE, dispatchMsgPublished);
			}
			try {
				receive.load(request);
			} catch (error:Error) {
			}
		}
		
		//hearbeat and ack timers
		protected function changeHearbeatTimer(enable:Boolean):void {
			if (!enable && cHeartbeatTimer)
				clearInterval(cHeartbeatTimer);
			cHeartbeatTimer = 0;
			if (enable && cHeartbeatInterval) {
				pushString(cHeartbeatString, true);
				cAckTimer = setInterval(pushString, cHeartbeatInterval * MILLISINASECOND, cHeartbeatString, true);
			}
		}
		
		protected function changeAckTime(enable:Boolean):void {
			if (!enable && cAckTimer)
				clearInterval(cAckTimer);
			cAckTimer = 0;
			if (enable && setting.ackIntervall)
				cAckTimer = setInterval(pushString, setting.ackIntervall * MILLISINASECOND, DEF_ACK, true);
		}
		
		//main message parsing
		protected function parseIncommingMessage(s:String):void {
			s = StringUtil.trim(s);
			if (!s.length)
				return;
			if (!setting.enableAtmoProtocol) {
				formatMessageReceivedEvent(s);
			} else {
				if (inReceived) {
					inReceived += s;  
				} else if (setting.trackMessageLength) {
					var firstIndex:int = s.indexOf(MESSAGE_DELIMITER);
					if (firstIndex < 0)
						return;//something went wrong or just an empty time stamp
					inLengthToReceive = new int(s.substring(0, firstIndex));
					inReceived = s.substr(firstIndex + MESSAGE_DELIMITER.length); 
				} else {
					inReceived = s;
				}
				if (setting.trackMessageLength && (inLengthToReceive > inReceived.length))
					return;//waiting for more...
				var moreMsg:String = null;
				if (setting.trackMessageLength && (inLengthToReceive < inReceived.length)) {
					moreMsg = inReceived.substr(inLengthToReceive);
					inReceived = inReceived.substr(0, inLengthToReceive);
				}
				if (inIsFirst) {
					var split:Array = inReceived.split(MESSAGE_DELIMITER);
					if (split.length < 3)
						dispatchError(0, "Different protocol detected. Use 2.2.x");
					cUuid = split[0];
					cHeartbeatInterval = new int(split[1]);
					cHeartbeatString = split[2];
					changeHearbeatTimer(true);
					inIsFirst = false;
					changeAckTime(true);
				} else
					formatMessageReceivedEvent(inReceived, cUuid);					
				inReceived = null;
				if (moreMsg)
					parseIncommingMessage(moreMsg);
			}
		}
		
		//event generation
		protected function formatMessageReceivedEvent(msg:String, uuid:String = null):void {
			var fae:AtmosphereEvent = new AtmosphereEvent(AtmosphereEvent.onMessage);
			fae.transport = currentTransport();
			fae.msg = msg;
			fae.uuid = uuid;
			dispatchEvent(fae);
		}

		protected function dispatchMsgPublished(msg:*):void {
			var event:AtmosphereEvent = createEvent(AtmosphereEvent.onMessagePublished);
			event.msg = msg;
			dispatchEvent(event);						
		}

		protected function dispatchOpenEvent(reopen:Boolean):void {
			dispatchEvent(createEvent(reopen ? AtmosphereEvent.onReopen : AtmosphereEvent.onOpen));						
		}

		private function dispatchError(error:int, errorStr:String):void
		{
			var fae:AtmosphereEvent = new AtmosphereEvent(AtmosphereEvent.onError);
			fae.error = error;
			fae.errorStr = errorStr;
			fae.transport = currentTransport();
			dispatchEvent(fae);						
		}

		private function createEvent(event:String):AtmosphereEvent {
			var fae:AtmosphereEvent = new AtmosphereEvent(event);
			fae.transport = currentTransport();
			fae.socket = this;
			fae.uuid = uuid;
			return fae;
		}

		//url preparation
		private static function swapProtocolForWs(url:String):String {
			if (!url)
				return null;
			if (url.substr(0, PROTOCOL_HTTPS.length).toLowerCase() == PROTOCOL_HTTPS)
				return PROTOCOL_WSS + url.substr(PROTOCOL_HTTPS.length);//secure socket
			if (url.substr(0, PROTOCOL_HTTP.length).toLowerCase() == PROTOCOL_HTTP)
				return PROTOCOL_WS + url.substr(PROTOCOL_HTTP.length);//only socket...
			return null;
		}
		
		private function formatUrlForWs(url:String):String {
			return attachHeaders(swapProtocolForWs(url), getAllHeaders());
		}

		private function formatUrlForHs(url:String, overloadTransport:String):String {
			var o:Object = getAllHeaders();
			if (overloadTransport != null)
				o[HEADER_TRANSPORT] = overloadTransport;
			return attachHeaders(url, o);
		}
		
		private function isHyperTextUrl(url:String):Boolean {
			return (url.substr(0, PROTOCOL_HTTPS.length).toLowerCase() == PROTOCOL_HTTPS) || (url.substr(0, PROTOCOL_HTTP.length).toLowerCase() == PROTOCOL_HTTP);
		}
		
		private function getUrl():String {
			var url:String = StringUtil.trim(setting.url);
			if (isHyperTextUrl(url))
				return url;
			var flexLocaltion:String = FlexGlobals.topLevelApplication.url;
			if (isHyperTextUrl(flexLocaltion))
				var baseUrl:String = flexLocaltion;
			else
				baseUrl = StringUtil.trim(setting.defaultUrlForLocal);
			var i:int = baseUrl.lastIndexOf("/");
			if (i < 0)
				return baseUrl + "/" + url;
			return baseUrl.substring(0, i + 1) + url;
		}

		private function attachHeaders(url:String, headers:Object):String {
			if (url) {
				url += url.indexOf("?") >= 0 ? "&" : "?";
				for (var s:String in headers)
					url += escape(s) + "=" + escape(headers[s]) + "&";
				url += "_=" + getTimer();				
			}
			return url;
		}
		
		private function getAllHeaders():Object {
			var o:Object = {};
			o[HEADER_TRACKID] = cUuid;
			o[HEADER_FRAMEWORK] = VERSION;
			o[HEADER_TRANSPORT] = currentTransport();
			if (setting.heartbeat)
				o[HEADER_HEARTBEAT] = setting.heartbeat;
			if (setting.useBinary)
				o[HEADER_USEBINARY] = "true";
			if (setting.trackMessageLength)
				o[HEADER_TRACKSIZE] = "true";
			if (setting.contentType)
				o[HEADER_CONTENTTYPE] = setting.contentType;			
			if (setting.enableAtmoProtocol)
				o[HEADER_USEPROTOCOL] = "true";
			for (var s:String in setting.headers)
				o[s] = setting.headers[s];
			return o;			
		}
		
		//utils
		private function currentTransport():String {
			return setting.transport[sTransportIndex];
		}
	}
}