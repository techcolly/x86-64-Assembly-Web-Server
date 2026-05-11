# x86-64 Assembly Web Server
This is the assembly file I wrote for the "Web Server" challenge in the "Computing 101" module for pwn.college. This server can seamlessly support both GET and POST requests concurrently.

---

## GET requests
- A client can request the content of a file on the server.
- If the file does not exist, the server will return `400 Bad Request` and exit with code 1. Otherwise, the contents of the file will be returned to the client along with a `200 OK` to indicate a successful request.
- A `GET` request cannot be more than 2048 bytes long.

## POST requests
- A client can request to put a file on the server.
- If the file does not exist, it will be created.
- If the request is malformed, the server will return `400 Bad Request` and exit with code 1. Otherwise, the file will be modified/created with the contents of the request and the server will return a `200 OK` to indicate a successful request.
