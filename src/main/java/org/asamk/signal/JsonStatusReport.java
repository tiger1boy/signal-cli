//
// "Value class" for emitting json status reports (mostly as replies to json requests)
//

package org.asamk.signal;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonInclude.Include;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.core.*;


@JsonInclude(Include.NON_NULL)
class JsonStatusReport {
    public String type;
    public String id;
    public String status;
    public String message;

    JsonStatusReport( String type, String id, String status) {
        this.type = type;
        this.id = id;
        this.status = status;
    }

    void emit() {
        ObjectMapper mpr = new ObjectMapper();
        try {
            System.out.println( mpr.writeValueAsString(this));
        } catch( JsonProcessingException e) {
            System.err.println("Main::JsonStatusReport failed to serialize json: " + e);
        }
    }
}


