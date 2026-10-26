import 'package:display_app/utils/cloud_connector.dart';
import 'package:flutter_test/flutter_test.dart';

String enrollSuccess = """
{
  "data": {
    "ca_path": "/var/lib/cloud-connector/certs/ca.crt",
    "cert_path": "/var/lib/cloud-connector/certs/client.crt",
    "key_path": "/var/lib/cloud-connector/certs/client.key"
  },
  "error": "",
  "request_id": "cli-2419",
  "success": true,
  "type": "response"
}
""";

String enrollFailure = """
{
  "data": {},
  "error": "est: enrollment details: HTTP 403",
  "request_id": "cli-2541",
  "success": false,
  "type": "response"
}
""";

String statusEnrolled = """
{
  "data": {
    "cert_path": "/var/lib/cloud-connector/certs/client.crt",
    "enrolled": true,
    "expires_in_days": 88
  },
  "error": "",
  "request_id": "cli-2241",
  "success": true,
  "type": "response"
}
""";

String statusNotEnrolled = """
{
  "data": {
    "enrolled": false
  },
  "error": "",
  "request_id": "cli-2242",
  "success": true,
  "type": "response"
}
""";

void main() {
  test("successful enrollment is parsed", () {
    final response = CloudConnectorResponse.parse(enrollSuccess, 0);
    expect(response.success, true);
    expect(response.error, "");
    expect(response.data["cert_path"],
        "/var/lib/cloud-connector/certs/client.crt");
  });

  test("failed enrollment exposes the error", () {
    final response = CloudConnectorResponse.parse(enrollFailure, 1);
    expect(response.success, false);
    expect(response.error, "est: enrollment details: HTTP 403");
  });

  test("failed enrollment with exit code 0 is still a failure", () {
    final response = CloudConnectorResponse.parse(enrollFailure, 0);
    expect(response.success, false);
    expect(response.error, "est: enrollment details: HTTP 403");
  });

  test("success with non-zero exit code is a failure", () {
    final response = CloudConnectorResponse.parse(enrollSuccess, 2);
    expect(response.success, false);
    expect(response.error, "exit code 2");
  });

  test("status reports enrolled", () {
    expect(CloudConnectorResponse.parse(statusEnrolled, 0).enrolled, true);
  });

  test("status reports not enrolled", () {
    expect(CloudConnectorResponse.parse(statusNotEnrolled, 0).enrolled, false);
    expect(CloudConnectorResponse.parse(enrollFailure, 1).enrolled, false);
  });

  test("empty output is a failure", () {
    final response = CloudConnectorResponse.parse("", 1);
    expect(response.success, false);
    expect(response.error, "exit code 1");
    expect(response.enrolled, false);
  });

  test("garbage output is a failure containing the output", () {
    final response = CloudConnectorResponse.parse("unknown flag --format\n", 0);
    expect(response.success, false);
    expect(response.error, "unknown flag --format");
  });

  test("exit code based response", () {
    expect(CloudConnectorResponse.fromExitCode(0, "").success, true);
    final failed = CloudConnectorResponse.fromExitCode(5, "Unit not found.\n");
    expect(failed.success, false);
    expect(failed.error, "Unit not found.");
  });

  test("valid json means the daemon answered", () {
    expect(CloudConnectorResponse.parse(statusEnrolled, 0).answered, true);
    expect(CloudConnectorResponse.parse(statusNotEnrolled, 0).answered, true);
    expect(CloudConnectorResponse.parse(enrollFailure, 1).answered, true);
  });

  test("invalid output means the daemon did not answer", () {
    expect(CloudConnectorResponse.parse("", 1).answered, false);
    expect(CloudConnectorResponse.parse("unknown command \"est\"\n", 1).answered, false);
    expect(CloudConnectorResponse.fromExitCode(0, "").answered, false);
  });
}
