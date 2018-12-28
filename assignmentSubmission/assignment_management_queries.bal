@final string QUERY_TO_INSERT_DATA_TO_SUBMISSION =
"INSERT INTO Submission (studentId, data, fileName, description, created, updated) VALUES (?,?,?,?,now(),now());";

@final string QUERY_TO_GET_STUDENT_ASSIGNMENTS_BY_STUDENT_ID =
"SELECT id, fileName, description FROM Submission WHERE studentId=? AND status = ?;";

@final string QUERY_TO_GET_SUBMISSION_DATA_BY_ID =
"SELECT fileName, data FROM Submission WHERE ID=?";

@final string QUERY_TO_GET_LAST =
"SELECT id,fileName FROM Submission WHERE id=(Select LAST_INSERT_ID());";

@final string QUERY_TO_DELETE_SUBMISSION =
"DELETE FROM Submission WHERE id = ?;";