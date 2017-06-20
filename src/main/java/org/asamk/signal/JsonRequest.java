//
// Value class for de-serialization of incoming json requests on stdin
//

package org.asamk.signal;

import java.util.List;

class JsonRequest {
    public String type;				// Request type ("send")
    public String id;				// Transaction ID for building async flow with potential client library (optional)
    public String messageBody;		// (type:send) Message body
    public String recipientNumber;	// (type:send) Message recipient (telephone number typically)
    public String recipientGroupId;	// (type:send) Group ID to send to (can not be combined with recipientNumber, it's either)
    public List<String> attachmentFilenames;
    JsonRequest() {
    }
}


