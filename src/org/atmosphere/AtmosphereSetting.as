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
	public class AtmosphereSetting
	{
		public var url:String = null;
		public var useBinary:Boolean = false;
		public var trackMessageLength:Boolean = true;
		public var enableAtmoProtocol:Boolean = true;
		public var headers:Object = {};
		public var contentType:String = "application/json";
		public var defaultUrlForLocal:String = "http://localhost:8080/atmosphere-chat-2.1.7/";
		public var ackIntervall:int = 5;
		public var heartbeat:int = 5;
		public var requestTimeout:int = 120;//close when 2mins of connection inactivity
		public var reconnectMaxCount:int = 10;
		public var reconnectTimeout:int = 1;
		public var transport:Array = [Atmosphere.TRANSPORT_WEBSOCKET, Atmosphere.TRANSPORT_LONG_POLLING];
		//public var transport:Array = [FlexAtmosphere.TRANSPORT_LONG_POLLING];
		public var externUuid:String = null;
		
		//websocket vars
		public var proxyHost:String = null;
		public var proxyPort:int = 0;
		
		public function AtmosphereSetting() {
		}
	}
}