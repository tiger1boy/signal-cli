
	================
    JSONEVTLOOP MODE
	================

Purpose: JSON-based asynchronous API for signal-cli.

This mode is not intended to be used directly from the command line, but to 
provide an easy adoptable API for other scripting languages.

signal-cli listens for JSON requests on stdin. Each JSON request must be
a single valid JSON object (enclosed in {}), followed by LF. The JSON text
itself hence must not contain linefeeds (only escaped as \n and no pretty
printing enabled).

When incoming messages are received from the signal back-end, they are
in turned JSON encoded and sent out on stdout.

Any error messages or debug information is sent out on stderr as expected.

Look under perl/ directory to find simple event driven module (SignalCLI.pm)
for receving messages and replying etc. There is also example perl program
that makes use of the module.

To start signal-cli using jsonevtloop command
	./build/install/signal-cli/bin/signal-cli -u '+2345' jsonevtloop

Currently the only "commands" implemented are "send" and "exit". 

Note the "id" property (string) that is always copied to the corresponding result
message to map requests and results together (async operation means
things might not come in order of submittal).

To send message, pipe the following to stdin once it as started:
{"type":"send","recipientNumber":"+1234","messageBody":"Test message","id": "12345678"}

Send message to group (you need to know the group ID, which you determine by looking in incoming messages to said group):
{"type":"send","recipientGroupId":"hyo+GHM6IlVAxab348n6kQ\u003d\u003d","messageBody":"Test message to group","id": "12345678"}

Attach files:
{"type":"send","recipientNumber":"+1234","messageBody":"Test","id": "12345678", "attachmentFilenames":["/home/kbin/testpic.jpg"] }

Make API request to exit signal-cli jsonevtloop mode and terminate:
{"type":"exit"}


Received JSON messages/events on stdout should always have a "type" field
indicating what type of object it is.

Valid types:
	jsonevtloop_start		Event emitted when jsonevtloop mode is initialized
							and ready
	jsonevtloop_alive		Regularly emitted whenever timeout occurs in 
							signal-cli receiveMessages
	jsonevtloop_exit		Emitted right before jsonevt loop exits
	message 				Incoming message (direct/groupmessage/receipt/
							groupInfo)
	error					An error has occured when processing a request
	error_exception			An exception error has occured in signal-cli
	result					Result from a previous request


Examples of JSON output (prettified for easier reading):

API is started:
	{
	  "type":"jsonevtloop_start"
	}

Incoming direct message:
	{
	  "type": "message",
	  "envelope": {
	    "callMessage": null,
	    "source": "+1234",
	    "sourceDevice": 1,
	    "relay": null,
	    "timestamp": 1497981941401,
	    "timestampISO": "2017-06-20T18:05:41.401Z",
	    "isReceipt": false,
	    "dataMessage": {
	      "groupInfo": null,
	      "attachments": [],
	      "expiresInSeconds": 0,
	      "message": "Test",
	      "timestamp": 1497981941401
	    },
	    "syncMessage": null
	  }
	}

Incoming message with attachment:
	{
	  "type": "message",
	  "envelope": {
	    "callMessage": null,
	    "source": "+1234",
	    "sourceDevice": 1,
	    "relay": null,
	    "timestamp": 1497982097691,
	    "timestampISO": "2017-06-20T18:08:17.691Z",
	    "isReceipt": false,
	    "dataMessage": {
	      "groupInfo": null,
	      "attachments": [
	        {
	          "storedFilename": "/home/kb/.config/signal/attachments/7827360170741426329",
	          "size": 1739491,
	          "id": 7827360170741426000,
	          "contentType": "image/jpeg"
	        }
	      ],
	      "expiresInSeconds": 0,
	      "message": "",
	      "timestamp": 1497982097691
	    },
	    "syncMessage": null
	  }
	}


Incoming group message:
	{
	  "type": "message",
	  "envelope": {
	    "callMessage": null,
	    "source": "+1234",
	    "sourceDevice": 1,
	    "relay": null,
	    "timestamp": 1497982321063,
	    "timestampISO": "2017-06-20T18:12:01.063Z",
	    "isReceipt": false,
	    "dataMessage": {
	      "groupInfo": {
	        "type": "DELIVER",
	        "name": "testgruppen testabbet",
	        "members": null,
	        "groupId": "hyo+GHM6IlVAxab348n6kQ=="
	      },
	      "attachments": [],
	      "expiresInSeconds": 86400,
	      "message": "Test",
	      "timestamp": 1497982321063
	    },
	    "syncMessage": null
	  }
	}


Group info was updated:
	{
	  "type": "message",
	  "envelope": {
	    "callMessage": null,
	    "source": "+1234",
	    "sourceDevice": 1,
	    "relay": null,
	    "timestamp": 1497982379102,
	    "timestampISO": "2017-06-20T18:12:59.102Z",
	    "isReceipt": false,
	    "dataMessage": {
	      "groupInfo": {
	        "type": "UPDATE",
	        "name": "testgruppen testabbet",
	        "members": [
	          "+1234",
	          "+2345"
	        ],
	        "groupId": "hyo+GHM6IlVAxab348n6kQ=="
	      },
	      "attachments": [],
	      "expiresInSeconds": 0,
	      "message": "",
	      "timestamp": 1497982379102
	    },
	    "syncMessage": null
	  }
	}


Message delivery receipt:
	{
	  "type": "message",
	  "envelope": {
	    "callMessage": null,
	    "source": "+1234",
	    "sourceDevice": 2,
	    "relay": null,
	    "timestamp": 1497972908801,
	    "timestampISO": "2017-06-20T15:35:08.801Z",
	    "isReceipt": true,
	    "dataMessage": null,
	    "syncMessage": null
	  }
	}

NOTE: Regarding receipts, there is currently nothing that ties a
particular receipt to a sent message, making this currently a 
bit useless. My hopes are that there is some kind of message ID
that is generated on submit that is then echoed back in the 
receipt, only I dont know how to access those properties (yet).

