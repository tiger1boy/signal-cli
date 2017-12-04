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
    public String groupId;		// (type:update_group) the groupId to update
    public List<String> members;	// (type:update_group) the list of members to add to a group
    public String name;			// (type:update_group) the new name of the group
    public String avatar;		// (type:update_group) the path to the new group image

    JsonRequest() {
    }
}
