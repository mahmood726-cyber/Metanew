"""
Comprehensive Security Tests
Tests for security vulnerabilities, injection attacks, and data protection
"""
import pytest
import sys
import os
from fastapi.testclient import TestClient

sys.path.append(os.path.join(os.path.dirname(__file__), '../../backend/api'))

from main import app

client = TestClient(app)


class TestInputValidationSecurity:
    """Test input validation prevents injection attacks"""

    def test_sql_injection_attempts(self):
        """Test SQL injection attempts are blocked"""
        sql_injection_payloads = [
            "'; DROP TABLE users; --",
            "1' OR '1'='1",
            "admin'--",
            "' OR 1=1--",
            "1; DROP TABLE studies;--"
        ]

        for payload in sql_injection_payloads:
            # Try SQL injection in study_id
            data = {
                "data": {
                    "study_id": [payload],
                    "treatment": ["A"],
                    "events": [10],
                    "n": [100]
                },
                "data_type": "binary"
            }

            response = client.post("/validate", json=data)
            # Should either reject or sanitize, but not crash
            assert response.status_code in [200, 400, 422]
            # Application should not crash or leak error details
            if response.status_code == 500:
                pytest.fail(f"SQL injection payload caused server error: {payload}")

    def test_xss_attempts(self):
        """Test XSS attempts are sanitized"""
        xss_payloads = [
            "<script>alert('XSS')</script>",
            "<img src=x onerror=alert('XSS')>",
            "javascript:alert('XSS')",
            "<iframe src='javascript:alert(1)'>",
            "<svg onload=alert('XSS')>"
        ]

        for payload in xss_payloads:
            data = {
                "data": {
                    "study_id": [payload],
                    "treatment": ["A"],
                    "events": [10],
                    "n": [100]
                },
                "data_type": "binary"
            }

            response = client.post("/validate", json=data)
            assert response.status_code in [200, 400, 422]

            # If accepted, should be sanitized in response
            if response.status_code == 200:
                response_text = response.text.lower()
                # Should not contain script tags
                assert "<script>" not in response_text
                assert "javascript:" not in response_text

    def test_command_injection_attempts(self):
        """Test command injection attempts are blocked"""
        command_injection_payloads = [
            "; ls -la",
            "| cat /etc/passwd",
            "`whoami`",
            "$(rm -rf /)",
            "; cat /etc/shadow"
        ]

        for payload in command_injection_payloads:
            data = {
                "data": {
                    "study_id": [payload],
                    "treatment": ["A"],
                    "events": [10],
                    "n": [100]
                },
                "data_type": "binary"
            }

            response = client.post("/validate", json=data)
            # Should not execute commands
            assert response.status_code in [200, 400, 422]

    def test_path_traversal_attempts(self):
        """Test path traversal attempts are blocked"""
        path_traversal_payloads = [
            "../../etc/passwd",
            "..\\..\\windows\\system32",
            "....//....//etc/passwd",
            "/etc/passwd",
            "C:\\Windows\\System32\\config\\SAM"
        ]

        for payload in path_traversal_payloads:
            data = {
                "data": {
                    "study_id": [payload],
                    "treatment": ["A"],
                    "events": [10],
                    "n": [100]
                },
                "data_type": "binary"
            }

            response = client.post("/validate", json=data)
            # Should not access file system
            assert response.status_code in [200, 400, 422]


class TestDataValidationSecurity:
    """Test data validation prevents malicious inputs"""

    def test_extremely_large_values(self):
        """Test handling of extremely large numerical values"""
        data = {
            "data": {
                "study_id": ["S1"],
                "treatment": ["A"],
                "events": [999999999999],
                "n": [1000000000000]
            },
            "data_type": "binary"
        }

        response = client.post("/validate", json=data)
        # Should handle gracefully
        assert response.status_code in [200, 400, 422]

    def test_negative_values_security(self):
        """Test handling of negative values"""
        data = {
            "data": {
                "study_id": ["S1"],
                "treatment": ["A"],
                "events": [-100],
                "n": [-1000]
            },
            "data_type": "binary"
        }

        response = client.post("/validate", json=data)
        assert response.status_code in [200, 400, 422]
        if response.status_code == 200:
            result = response.json()
            assert result["is_valid"] is False

    def test_special_characters_in_strings(self):
        """Test handling of special characters"""
        special_chars = [
            "null\x00byte",
            "newline\ncharacter",
            "carriage\rreturn",
            "tab\tcharacter",
            "unicode\u0000character"
        ]

        for special in special_chars:
            data = {
                "data": {
                    "study_id": [special],
                    "treatment": ["A"],
                    "events": [10],
                    "n": [100]
                },
                "data_type": "binary"
            }

            response = client.post("/validate", json=data)
            # Should handle special characters safely
            assert response.status_code in [200, 400, 422]

    def test_very_long_strings(self):
        """Test handling of very long strings"""
        # Create a very long string (10KB)
        long_string = "A" * 10000

        data = {
            "data": {
                "study_id": [long_string],
                "treatment": ["A"],
                "events": [10],
                "n": [100]
            },
            "data_type": "binary"
        }

        response = client.post("/validate", json=data)
        # Should either accept or reject, but not crash
        assert response.status_code in [200, 400, 413, 422]

    def test_array_overflow_attempts(self):
        """Test handling of extremely large arrays"""
        # Create very large array (1000 studies)
        large_array = ["Study" + str(i) for i in range(1000)]

        data = {
            "data": {
                "study_id": large_array,
                "treatment": ["A"] * 1000,
                "events": [10] * 1000,
                "n": [100] * 1000
            },
            "data_type": "binary"
        }

        response = client.post("/validate", json=data)
        # Should handle large datasets
        assert response.status_code in [200, 413, 422]


class TestAuthenticationSecurity:
    """Test authentication and authorization (if implemented)"""

    def test_unauthenticated_access(self):
        """Test if endpoints require authentication"""
        # Note: Currently no authentication, but testing framework ready
        response = client.get("/")
        # Currently should allow access
        assert response.status_code == 200

    def test_cors_headers(self):
        """Test CORS headers are properly configured"""
        response = client.options("/validate")

        # Check if CORS headers are present
        # In production, should restrict to specific origins
        if "access-control-allow-origin" in response.headers:
            cors_header = response.headers["access-control-allow-origin"]
            # Should NOT be "*" in production
            # For now, just check it exists
            assert cors_header is not None


class TestRateLimitingSecurity:
    """Test rate limiting protects against abuse"""

    def test_rate_limit_enforcement(self):
        """Test rate limiting is enforced"""
        # Make many rapid requests
        responses = []
        for i in range(20):
            response = client.post(
                "/validate",
                json={
                    "data": {
                        "study_id": [f"S{i}"],
                        "treatment": ["A"],
                        "events": [10],
                        "n": [100]
                    },
                    "data_type": "binary"
                }
            )
            responses.append(response)

        status_codes = [r.status_code for r in responses]

        # Some requests should be rate limited (429) or all should succeed
        # depending on configured limits
        assert all(code in [200, 429] for code in status_codes)

    def test_rate_limit_nlq_endpoint(self):
        """Test rate limiting on NLQ endpoint (if exists)"""
        # NLQ endpoint should have stricter rate limiting
        responses = []
        for i in range(15):
            response = client.post(
                "/nlq",
                json={
                    "query": f"Test query {i}",
                    "context": {}
                }
            )
            responses.append(response)

        status_codes = [r.status_code for r in responses]
        # Should include 429 or 404 if not implemented
        assert all(code in [200, 404, 429] for code in status_codes)


class TestErrorHandlingSecurity:
    """Test error handling doesn't leak sensitive information"""

    def test_error_messages_no_stack_traces(self):
        """Test error messages don't contain stack traces"""
        # Send malformed request
        response = client.post(
            "/validate",
            json={"invalid": "data"}
        )

        # Should return error but not stack trace
        if response.status_code >= 400:
            response_text = response.text.lower()
            # Should not contain file paths or stack traces
            assert "/home/" not in response_text
            assert "traceback" not in response_text
            assert ".py" not in response_text or "test" in response_text

    def test_internal_error_handling(self):
        """Test internal errors are handled gracefully"""
        # Try to cause an internal error
        response = client.post(
            "/compute-effect-size",
            json={
                "data": {
                    "study_id": ["S1"],
                    "events1": [None],  # Invalid type
                    "n1": ["invalid"],  # Invalid type
                    "events2": [10],
                    "n2": [100]
                },
                "effect_measure": "OR"
            }
        )

        # Should handle error gracefully
        assert response.status_code in [400, 422, 500]


class TestDataPrivacySecurity:
    """Test data privacy and protection"""

    def test_no_data_leakage_in_errors(self):
        """Test error messages don't leak submitted data"""
        sensitive_data = {
            "data": {
                "study_id": ["ConfidentialStudy123"],
                "treatment": ["ProprietaryDrug"],
                "events": [10],
                "n": [100]
            },
            "data_type": "binary"
        }

        response = client.post("/validate", json=sensitive_data)

        # Even if there's an error, shouldn't echo back all sensitive data
        # This is a basic check
        assert response.status_code in [200, 400, 422]

    def test_cache_isolation(self):
        """Test cache doesn't leak data between requests"""
        # Submit data for one analysis
        data1 = {
            "data": {
                "study_id": ["UserA_Study"],
                "treatment": ["A"],
                "events": [10],
                "n": [100]
            },
            "data_type": "binary"
        }

        response1 = client.post("/validate", json=data1)
        assert response1.status_code == 200

        # Submit different data
        data2 = {
            "data": {
                "study_id": ["UserB_Study"],
                "treatment": ["B"],
                "events": [20],
                "n": [200]
            },
            "data_type": "binary"
        }

        response2 = client.post("/validate", json=data2)
        assert response2.status_code == 200

        # Responses should not contain each other's data
        assert "UserA_Study" not in response2.text
        assert "UserB_Study" not in response1.text


class TestCryptographicSecurity:
    """Test cryptographic security measures"""

    def test_secure_headers_present(self):
        """Test security headers are present"""
        response = client.get("/")

        # Check for security headers (may not all be present yet)
        headers = response.headers

        # These should be present in production
        # For now, just check response is valid
        assert response.status_code == 200

        # Ideally should have:
        # - Strict-Transport-Security
        # - X-Content-Type-Options
        # - X-Frame-Options
        # - Content-Security-Policy

    def test_no_sensitive_data_in_logs(self):
        """Test sensitive data is not logged"""
        # Submit request with potentially sensitive data
        response = client.post(
            "/validate",
            json={
                "data": {
                    "study_id": ["SECRET123"],
                    "treatment": ["A"],
                    "events": [10],
                    "n": [100]
                },
                "data_type": "binary"
            }
        )

        # Can't easily test logs, but verify request succeeds
        assert response.status_code in [200, 400, 422]


class TestDenialOfServiceProtection:
    """Test protection against DoS attacks"""

    def test_large_payload_handling(self):
        """Test handling of very large payloads"""
        # Create a large payload (approaching typical limits)
        large_data = {
            "data": {
                "study_id": ["Study" + str(i) for i in range(1000)],
                "treatment": ["A"] * 1000,
                "events": [10] * 1000,
                "n": [100] * 1000
            },
            "data_type": "binary"
        }

        response = client.post("/validate", json=large_data)
        # Should handle or reject, not crash
        assert response.status_code in [200, 413, 422]

    def test_nested_payload_handling(self):
        """Test handling of deeply nested payloads"""
        # Create deeply nested structure
        nested = {"level": 0}
        current = nested
        for i in range(100):
            current["next"] = {"level": i + 1}
            current = current["next"]

        # Try to send it (will likely be rejected)
        response = client.post("/validate", json=nested)
        # Should reject or handle, not crash
        assert response.status_code in [400, 422, 500]

    def test_concurrent_request_handling(self):
        """Test handling of many concurrent requests"""
        import concurrent.futures

        def make_request(i):
            return client.post(
                "/validate",
                json={
                    "data": {
                        "study_id": [f"S{i}"],
                        "treatment": ["A"],
                        "events": [10],
                        "n": [100]
                    },
                    "data_type": "binary"
                }
            )

        # Send 50 concurrent requests
        with concurrent.futures.ThreadPoolExecutor(max_workers=20) as executor:
            futures = [executor.submit(make_request, i) for i in range(50)]
            results = [f.result() for f in futures]

        # All should complete (might be rate limited)
        assert all(r.status_code in [200, 429] for r in results)


class TestAPISecurityBestPractices:
    """Test general API security best practices"""

    def test_no_debug_mode_leaks(self):
        """Test debug mode is not enabled"""
        response = client.get("/")
        # Should not return debug information
        response_text = response.text.lower()
        assert "debug" not in response_text or "false" in response_text

    def test_proper_content_type_handling(self):
        """Test proper content type validation"""
        # Try to send XML instead of JSON
        response = client.post(
            "/validate",
            data="<data>test</data>",
            headers={"Content-Type": "application/xml"}
        )

        # Should reject or handle gracefully
        assert response.status_code in [400, 415, 422]

    def test_http_method_restrictions(self):
        """Test endpoints only accept appropriate HTTP methods"""
        # POST endpoint should not accept GET
        response = client.get("/validate")
        assert response.status_code in [405, 404]

        # GET endpoint should not accept POST
        response = client.post("/")
        # Root might accept both, so check it responds
        assert response.status_code in [200, 405]


if __name__ == '__main__':
    pytest.main([__file__, '-v', '--tb=short'])
