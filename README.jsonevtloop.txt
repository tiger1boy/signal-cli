
JSONEVTLOOP

Concept: Making signal-cli more script friendly with predictably output.

Start signal-cli using jsonevtloop command
./build/install/signal-cli/bin/signal-cli -u '+2345' jsonevtloop


To send message, pipe the following to stdin once it as started:
{"type":"send","recipientNumber":"+1234","messageBody":"Test message","id": "12345678"}

Send message to group (you need to know the group ID, which you determine by looking in incoming messages to said group):
{"type":"send","recipientGroupId":"hyo+GHM6IlVAxab348n6kQ\u003d\u003d","messageBody":"Test message to group","id": "12345678"}

Attach files:
{"type":"send","recipientNumber":"+1234","messageBody":"Test","id": "12345678", "attachmentFilenames":["/home/kbin/testpic.jpg"] }

Make API exit:
{"type":"exit"}


Look under perl directory to find simple event driven module for receving messages and replying etc.

