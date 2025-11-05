"""
Quick API test script
Verifies models load and endpoints work
"""

import sys
sys.path.insert(0, '/home/user/Metanew/api')

from main import app
from fastapi.testclient import TestClient

# Create test client
client = TestClient(app)

print("=" * 80)
print("API TESTING")
print("=" * 80)

# Test 1: Root endpoint
print("\n1. Testing root endpoint...")
response = client.get("/")
assert response.status_code == 200
print("✅ Root endpoint working")
print(f"   Response: {response.json()['message']}")

# Test 2: Health check
print("\n2. Testing health check...")
response = client.get("/health")
assert response.status_code == 200
health = response.json()
print("✅ Health check working")
print(f"   Status: {health['status']}")
print(f"   Models loaded: {health['models_loaded']}")

# Test 3: HTA Prediction
print("\n3. Testing HTA prediction...")
hta_data = {
    "effect_size": 0.45,
    "icer_per_qaly": 75000,
    "serious_adverse_events_rate": 0.12,
    "discontinuation_rate": 0.20,
    "n_rcts": 8,
    "n_observational_studies": 3,
    "total_patients_evidence": 2500,
    "cost_effectiveness_score": 7.5,
    "clinical_benefit_score": 6.8,
    "innovation_score": 8.2
}

response = client.post("/predict/hta", json=hta_data)
assert response.status_code == 200
hta_result = response.json()
print("✅ HTA prediction working")
print(f"   Decision: {hta_result['decision']}")
print(f"   Confidence: {hta_result['confidence']:.2%}")

# Test 4: Effect Size Prediction
print("\n4. Testing effect size prediction...")
effect_data = {
    "experimental_n": 250,
    "control_n": 250,
    "experimental_events": 45,
    "control_events": 62,
    "study_year": 2020
}

response = client.post("/predict/effect-size", json=effect_data)
assert response.status_code == 200
effect_result = response.json()
print("✅ Effect size prediction working")
print(f"   Predicted OR: {effect_result['predicted_or']:.3f}")
print(f"   95% CI: [{effect_result['odds_ratio_ci_lower']:.3f}, {effect_result['odds_ratio_ci_upper']:.3f}]")

# Test 5: Batch predictions
print("\n5. Testing batch effect size predictions...")
batch_data = {
    "studies": [
        {"experimental_n": 100, "control_n": 100, "experimental_events": 20, "control_events": 30},
        {"experimental_n": 200, "control_n": 200, "experimental_events": 45, "control_events": 55}
    ]
}

response = client.post("/predict/effect-size/batch", json=batch_data)
assert response.status_code == 200
batch_result = response.json()
print("✅ Batch predictions working")
print(f"   Total: {batch_result['total']}")
print(f"   Successful: {batch_result['successful']}")

# Test 6: Error handling - invalid input
print("\n6. Testing error handling (invalid input)...")
invalid_data = {
    "experimental_n": 250,
    "control_n": 250,
    "experimental_events": 300,  # More events than sample size!
    "control_events": 62
}

response = client.post("/predict/effect-size", json=invalid_data)
assert response.status_code == 422  # Validation error
print("✅ Error handling working")
print(f"   Status code: {response.status_code} (Validation Error)")

print("\n" + "=" * 80)
print("✅ ALL TESTS PASSED - API IS READY!")
print("=" * 80)

print("\n📊 Summary:")
print("  ✅ Root endpoint: Working")
print("  ✅ Health check: Working")
print("  ✅ HTA prediction: Working")
print("  ✅ Effect size prediction: Working")
print("  ✅ Batch predictions: Working")
print("  ✅ Error handling: Working")

print("\n🚀 API is ready for deployment!")
print("   Start server: uvicorn main:app --reload")
print("   Docs: http://localhost:8000/docs")
