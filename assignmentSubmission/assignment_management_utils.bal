
public type Submission record{
    string fileName;
    byte[] data;
};


function handleContent(mime:Entity bodyPart) returns string {
    mime:MediaType mediaType = check mime:getMediaType(bodyPart.getContentType());
    string baseType = mediaType.getBaseType();
    byte[] data = check bodyPart.getByteArray();
    string base64 = mime:byteArrayToString(mime:base64EncodeByteArray(data), "UTF8");
    return base64;
}

function insertToAssignmentTable(int studentId, string content, string fileName, string description) returns boolean {
    log:printInfo("Inserting Data to Submission Table: ");
    boolean success = false;

    transaction with retries = 4, oncommit = onCommitFunction, onabort = onAbortFunction {
        var result = mysqlEP->update(QUERY_TO_INSERT_DATA_TO_SUBMISSION, studentId, content, fileName, description);

        match result {
            int c => {
                if (c < 0) {
                    log:printError("Unable to insert Data into Submission table:");
                } else {
                    log:printInfo("Successful! Inserted Into Submission Table: ");
                    success = true;
                }
            }
            error err => {
                log:printError(err.message);
            }
        }
    } onretry {
        io:println("Retrying transaction");
    }
    return success;
}

function getLastInserted() returns json|error{
    var response = mysqlEP->select(QUERY_TO_GET_LAST, ());

    match response {
        table entries => {
            json j = check <json>entries;
            return j;
        }
        error e => {
            return e;
        }
    }

}



function getAssignments(int studentId) returns json|error {
    log:printInfo("Retrieving Student Assignments for student ID: " + studentId);
    var response = mysqlEP->select(QUERY_TO_GET_STUDENT_ASSIGNMENTS_BY_STUDENT_ID, (), studentId, "Active");

    match response {
        table results => {
            match <json>results{
                json jsonResults => {
                    match <json[]>jsonResults{
                        json[] resultsArray => return resultsArray;
                        error e => return e;
                    }
                }
                error e => return e;
            }
        }
        error e => return e;
    }

}

function getStudentSubmission(int submissionId) returns Submission|error {

    log:printInfo("Searching Submission Data for id: " + submissionId);
    var response = mysqlEP->select(QUERY_TO_GET_SUBMISSION_DATA_BY_ID, Submission, submissionId);

    match response {
        table<Submission> entries => {
            while (entries.hasNext()) {
                match <Submission>entries.getNext()  {
                    Submission dia => {
                        return dia;
                    }
                    error e => {
                        log:printError("Unable to get Submission Data", err = e);
                        return e;
                    }
                }
            }
        }
        error e => {
            log:printError("Unable to get Submission Status", err = e);
            return e;
        }
    }
}

function deleteAssignment(int submissionId) {
    log:printInfo("Deleteing Submission id: " + submissionId);
    transaction with retries = 3, oncommit = onCommitFunction, onabort = onAbortFunction {
        var result = mysqlEP->update(QUERY_TO_DELETE_SUBMISSION, submissionId);
        handleUpdate(result, "Delete Assignment");
    }
}


function setErrorResponse(http:Response response, error e, int statusCode) {
    response.statusCode = statusCode;
    response.reasonPhrase = e.message;
    response.setJsonPayload(check <json>e);
}

function onCommitFunction(string transactionId) {
    io:println("Transaction: " + transactionId + " committed");
}
function onAbortFunction(string transactionId) {
    io:println("Transaction: " + transactionId + " aborted");
}
function handleUpdate(int|error returned, string message) {
    match returned {
        int retInt => io:println(message + " status: " + retInt);
        error err => io:println(message + " failed: " + err.message);
    }
}



