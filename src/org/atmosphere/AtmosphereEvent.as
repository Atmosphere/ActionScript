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

	public class AtmosphereEvent extends Event
	{
		public static const onError:String = "onError";
		public static const onClose:String = "onClose";
		public static const onOpen:String = "onOpen";
		public static const onReopen:String = "onReopen";
		public static const onMessage:String = "onMessage";
		public static const onReconnect:String = "onReconnect";
		public static const onMessagePublished:String = "onMessagePublished";
		public static const onTransportFailure:String = "onTransportFailure";
		//public static const onLocalMessage:String = "onLocalMessage";
		//public static const onFailureToReconnect:String = "onFailureToReconnect";
		public static const onClientTimeout:String = "onClientTimeout";
		
		public var socket:Object = null;
		public var msg:* = null;
		public var uuid:String = null;
		public var transport:String = null;
		public var error:int = 0;
		public var errorStr:String = null;
		
		public function AtmosphereEvent(type:String, bubbles:Boolean = false, cancelable:Boolean = false) {
			super(type, bubbles, cancelable);
		}
	}
}