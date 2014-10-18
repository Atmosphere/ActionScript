## Welcome to the Actionscript Client for the Atmosphere Framework
The native actionscript port of the Atmosphere Client transparently supports WebSockets, and Long-Polling.
This project ist in beta state. 
###Limitation
The Actionscript port does not support server side events or JSONP as of now as they do not bring any advantage. Because of Flash Player limitation, websockets are only supported for direct connection or behind transparent proxy adress.
### Install
You can get atmosphere#.#.swc and copy to your lib/flex-lib directory in your flex/flash project. The atmosphere.swc is compiled with Flex SDK 3.6A to ensure broadest compatibility.
Alternatively you can take all the actionscript classes from github, place it in your src/flex-src folder and compile them with a newer version of the Flex SDK.
### Maven

Will be added when the project leave the beta state

### Bower

Will be added when the project leave the beta state

## Docs

The actionscipt port relies on a heavily patched/modified versions of the [as3crypto](http://code.google.com/p/as3crypto) library, the RFC2817Socket.as by Christian Cantrell and now part of [as3corelib](https://github.com/mikechambers/as3corelib) and the [gimite/web-socket-js](https://github.com/gimite/web-socket-js). The modified version sof these libraries are maintained in this repository.
The actionscript port supports v2.2.1+ atmosphere servers.

Full API documentation can be read here.

### The Chat Sample
For demonstrating the capabilities of the actionscript client, one can take the chat sample of the atmosphere and do the following steps to include (Flex Builder is assumed):

* Create a Flash Builder Project and name it chat.
* Add the atmosphere librirary or the atmosphere classes (see install section)
* Download the chat.mxml from the sample directory and replace the main file of the Flex Builder project with its content.
* Compile the project and get the chat.swf.
* Download the chat sample from https://github.com/Atmosphere/atmosphere-samples in version v2.2.1+
* Open the downloaded .war file as zip archive and place the chat.swf in the root 
* Run the example (with Tomcat 8 for example)
* Open the index.html in browser
* Open the chat.swf in browser
* You can send and receive messages from the other client
