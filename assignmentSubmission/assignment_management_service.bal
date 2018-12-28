import ballerina/http;
import ballerina/io;
import ballerina/log;
import ballerina/config;
import ballerina/mysql;
import ballerina/mime;

endpoint http:Listener listener {
    port: config:getAsInt("STU_SUBMISSION_HTTP_PORT")
};

endpoint mysql:Client mysqlEP {
    host: config:getAsString("DATABASE_HOST"),
    port: config:getAsInt("DATABASE_PORT"),
    name: config:getAsString("DATABASE_NAME"),
    username: config:getAsString("DATABASE_USERNAME"),
    password: config:getAsString("DATABASE_PASSWORD"),
    dbOptions: { "useSSL": false },
    poolOptions: { maximumPoolSize: config:getAsInt("DATABASE_POOL_SIZE") }
};

@http:ServiceConfig {
    basePath: "/submission",
    cors: {
        allowOrigins: ["*"],
        allowCredentials: false,
        allowHeaders: ["CORELATION_ID", "Content-Type"],
        exposeHeaders: ["X-CUSTOM-HEADER"],
        maxAge: 84900
    }
}

service<http:Service> assignmentSubmissionService bind listener {

    @http:ResourceConfig {
        methods: ["POST"],
        path: "/{studentId}"
    }
    insertStudentAssigment(endpoint caller, http:Request request, int studentId) {
        http:Response response = new;

        map<json> submission;
        string content = "";
        string fileName = "";

        match request.getBodyParts() {
        //extracts body parts from the request
            mime:Entity[] bodyParts => {
                foreach part in bodyParts {
                    mime:ContentDisposition contentDisposition = part.getContentDisposition();
                    if (contentDisposition.name == "file") {
                        content = handleContent(part);
                        fileName = contentDisposition.fileName;
                    }
                    else {
                        submission[contentDisposition.name] = check part.getBodyAsString();
                    }
                }
            }
            error err => {
                setErrorResponse(response, untaint err, 500);
                log:printError("Error in decoding multiparts! ", err = err);
            }
        }

        if (insertToAssignmentTable(studentId, content, fileName, submission[
            "description"].toString())) {
            match getLastInserted() {
                json lastUpdated => {
                    response.setJsonPayload(untaint lastUpdated);
                    response.statusCode = 201;
                }
                error err => {
                    setErrorResponse(response, untaint err, 500);
                    log:printError("Failure in retrieving last updated assignment!", err = err);
                }
            }
        }
        else {
            log:printError("Error in insertion to assignment table");
            response.setPayload("Error in insertion to assignment table");
        }

        caller->respond(response) but {
            error e => log:printError("Error in responding", err = e)
        };
    }

    @http:ResourceConfig {
        methods: ["GET"],
        path: "/{studentId}"
    }
    getStudentAssignment(endpoint caller, http:Request request, int studentId) {
        http:Response response = new;
        log:printInfo("Requesting Student Assignments: ");

        match getAssignments(studentId) {
            json resources => {
                io:println("Response: ", resources);
                response.setPayload(untaint resources);
            }
            error e => {
                setErrorResponse(response, untaint e, 500);
            }
        }

        caller->respond(response) but {
            error e => log:printError("Error when responding", err = e)
        };
    }

    @http:ResourceConfig {
        methods: ["GET"],
        path: "/file/{submissionId}"
    }
    getSubmission(endpoint caller, http:Request request, int submissionId) {
        http:Response response = new;

        log:printInfo("Downloading Submission...");

        match getStudentSubmission(submissionId) {
            Submission data => {
                string fileName = data.fileName;
                response.setContentType("application/octet-stream");
                response.setHeader("Content-Type", "application/octet-stream");
                response.setHeader("Content-Description", "File Transfer");
                response.setHeader("Transfer-Encoding", "chunked");
                response.setHeader("Content-Disposition", "attachment; filename=" + fileName);
                response.setBinaryPayload(untaint mime:base64DecodeByteArray(data.data));
            }
            error e => {
                log:printError(e.message);
                response.statusCode = 500;
                response.reasonPhrase = e.message;
                response.setJsonPayload(untaint check <json>e);
            }
        }

        caller->respond(untaint response) but {
            error e => log:printError("Error when responding", err = e)
        };
    }

    @http:ResourceConfig {
        methods: ["DELETE"],
        path: "/file/{submissionId}"
    }
    deleteSubmission(endpoint caller, http:Request request, int submissionId) {
        http:Response response = new;
        log:printInfo("Deleting Submission: "+ submissionId);

        deleteAssignment(submissionId);

        caller->respond(response) but {
            error e => log:printError("Error when responding", err = e)
        };
    }
}