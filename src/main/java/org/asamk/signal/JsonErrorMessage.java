//
// "Value class" for emitting json error messages to stdout
//


package org.asamk.signal;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonInclude.Include;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.core.*;


@JsonInclude(Include.NON_NULL)
class JsonErrorMessage {
    public String type;
    public String id;			// Transaction ID, copied from request
    public String error;        // Error name (fixed string)
    public String message;      // Human readable error message
    public String subject;      // Telephone number, groupId or otherwise context relevant information about the error

    JsonErrorMessage( String error, String message, String subject) {
        this.type = "error";
        this.error = error;
        this.message = message;
        this.subject = subject;
    }

    JsonErrorMessage( String error, String message, String subject, JsonRequest req) {
        this.type = "error";
        if( req.id != null)
        	this.id = req.id;
        this.error = error;
        this.message = message;
        this.subject = subject;                
    }

    void emit() {
        ObjectMapper mpr = new ObjectMapper();
        try {
            System.out.println( mpr.writeValueAsString(this));
        } catch( JsonProcessingException e) {
            System.err.println("Main::JsonErrorMessage failed to serialize json: " + e);
        }
    }
}

