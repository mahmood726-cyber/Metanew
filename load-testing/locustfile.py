"""
Load Testing for EvidenceOS PRIME

This Locust script tests various API endpoints and scenarios:
- Health checks
- Study uploads and analysis
- ML predictions (Ensemble, AutoML)
- RAG document queries
- Meta-analysis operations
- Cache performance
"""

import json
import random
import time
from locust import HttpUser, task, between, events
from locust.exception import StopUser


class EvidenceOSUser(HttpUser):
    """Simulates a typical user interacting with EvidenceOS PRIME."""

    # Wait 1-3 seconds between tasks
    wait_time = between(1, 3)

    # Test data
    sample_studies = []
    uploaded_study_ids = []
    rag_document_ids = []

    def on_start(self):
        """Setup: Login and prepare test data."""
        # Generate sample study data
        self.sample_studies = self._generate_sample_studies(10)

        # Check if backend is healthy
        with self.client.get("/health", catch_response=True) as response:
            if response.status_code != 200:
                response.failure("Health check failed")
                raise StopUser()

    @task(10)
    def health_check(self):
        """Test health endpoint (lightweight, frequent)."""
        self.client.get("/health")

    @task(5)
    def detailed_health_check(self):
        """Test detailed health endpoint."""
        self.client.get("/health/detailed")

    @task(8)
    def upload_study(self):
        """Test study upload endpoint."""
        study = random.choice(self.sample_studies)
        with self.client.post(
            "/api/studies",
            json=study,
            catch_response=True,
            name="/api/studies [POST]"
        ) as response:
            if response.status_code == 201:
                data = response.json()
                if "id" in data:
                    self.uploaded_study_ids.append(data["id"])
                response.success()
            else:
                response.failure(f"Failed to upload study: {response.status_code}")

    @task(6)
    def get_studies(self):
        """Test getting list of studies."""
        self.client.get("/api/studies", name="/api/studies [GET]")

    @task(4)
    def get_study_by_id(self):
        """Test getting specific study by ID."""
        if self.uploaded_study_ids:
            study_id = random.choice(self.uploaded_study_ids)
            self.client.get(f"/api/studies/{study_id}", name="/api/studies/:id [GET]")
        else:
            # Fallback: test with random ID
            self.client.get("/api/studies/test-study-1", name="/api/studies/:id [GET]")

    @task(7)
    def meta_analysis(self):
        """Test meta-analysis endpoint."""
        analysis_request = {
            "studies": self.sample_studies[:5],
            "method": "random_effects",
            "model_type": "DerSimonian-Laird"
        }
        self.client.post(
            "/api/analysis/meta",
            json=analysis_request,
            name="/api/analysis/meta [POST]"
        )

    @task(5)
    def ensemble_prediction(self):
        """Test ensemble ML prediction."""
        prediction_request = {
            "features": self._generate_ml_features(),
            "model_type": "bagging",
            "n_estimators": 10
        }
        self.client.post(
            "/api/ml/predict/ensemble",
            json=prediction_request,
            name="/api/ml/predict/ensemble [POST]"
        )

    @task(4)
    def automl_train(self):
        """Test AutoML training endpoint."""
        training_request = {
            "data": [self._generate_ml_features() for _ in range(100)],
            "target": "effect_size",
            "time_budget": 60  # 1 minute
        }
        with self.client.post(
            "/api/ml/automl/train",
            json=training_request,
            timeout=120,
            catch_response=True,
            name="/api/ml/automl/train [POST]"
        ) as response:
            if response.status_code in [200, 201, 202]:
                response.success()
            else:
                response.failure(f"AutoML training failed: {response.status_code}")

    @task(6)
    def explainability_shap(self):
        """Test ML explainability with SHAP."""
        explainability_request = {
            "model_id": "test_model",
            "features": self._generate_ml_features(),
            "method": "shap"
        }
        self.client.post(
            "/api/ml/explain",
            json=explainability_request,
            name="/api/ml/explain [POST]"
        )

    @task(5)
    def rag_upload_document(self):
        """Test RAG document upload."""
        document = {
            "title": f"Research Paper {random.randint(1, 1000)}",
            "content": self._generate_research_paper_content(),
            "metadata": {
                "year": random.randint(2015, 2024),
                "authors": ["Author A", "Author B"],
                "journal": "Nature"
            }
        }
        with self.client.post(
            "/api/rag/documents",
            json=document,
            catch_response=True,
            name="/api/rag/documents [POST]"
        ) as response:
            if response.status_code == 201:
                data = response.json()
                if "id" in data:
                    self.rag_document_ids.append(data["id"])
                response.success()
            else:
                response.failure(f"Failed to upload document: {response.status_code}")

    @task(8)
    def rag_query(self):
        """Test RAG semantic search."""
        queries = [
            "What are the effects of intervention X on outcome Y?",
            "Show me meta-analyses about treatment effectiveness",
            "Find studies with high heterogeneity",
            "What is the publication bias in these studies?",
            "Explain the random effects model"
        ]
        query_request = {
            "query": random.choice(queries),
            "top_k": 5
        }
        self.client.post(
            "/api/rag/query",
            json=query_request,
            name="/api/rag/query [POST]"
        )

    @task(3)
    def cache_performance_test(self):
        """Test cache performance by repeated queries."""
        # First request - likely cache miss
        study_id = "test-study-cache-1"
        self.client.get(f"/api/studies/{study_id}", name="/api/studies/:id [Cache Miss]")

        # Wait a bit
        time.sleep(0.1)

        # Second request - should be cache hit
        with self.client.get(
            f"/api/studies/{study_id}",
            catch_response=True,
            name="/api/studies/:id [Cache Hit]"
        ) as response:
            if response.elapsed.total_seconds() < 0.1:  # Should be very fast
                response.success()
            else:
                response.failure("Cache hit too slow")

    @task(2)
    def knowledge_graph_query(self):
        """Test knowledge graph operations."""
        self.client.get("/api/knowledge-graph/stats", name="/api/knowledge-graph/stats [GET]")

    @task(2)
    def study_deduplication(self):
        """Test study deduplication."""
        dedup_request = {
            "studies": self.sample_studies[:3],
            "threshold": 0.8
        }
        self.client.post(
            "/api/studies/deduplicate",
            json=dedup_request,
            name="/api/studies/deduplicate [POST]"
        )

    # Helper methods

    def _generate_sample_studies(self, n: int) -> list:
        """Generate sample study data for testing."""
        studies = []
        interventions = ["Drug A", "Drug B", "Therapy X", "Treatment Y", "Intervention Z"]
        outcomes = ["Mortality", "Quality of Life", "Pain", "Anxiety", "Depression"]

        for i in range(n):
            study = {
                "study_id": f"study_{i}_{random.randint(1000, 9999)}",
                "title": f"Study {i}: Effects of {random.choice(interventions)} on {random.choice(outcomes)}",
                "year": random.randint(2010, 2024),
                "yi": random.uniform(-1.0, 1.0),  # Effect size
                "vi": random.uniform(0.01, 0.2),  # Variance
                "n": random.randint(50, 500),     # Sample size
                "intervention": random.choice(interventions),
                "outcome": random.choice(outcomes),
                "risk_of_bias": random.choice(["low", "moderate", "high"])
            }
            studies.append(study)

        return studies

    def _generate_ml_features(self) -> dict:
        """Generate sample ML feature data."""
        return {
            "sample_size": random.randint(50, 500),
            "effect_size": random.uniform(-1.0, 1.0),
            "variance": random.uniform(0.01, 0.2),
            "year": random.randint(2010, 2024),
            "heterogeneity": random.uniform(0, 100),
            "publication_bias": random.uniform(0, 1),
            "quality_score": random.uniform(0, 10)
        }

    def _generate_research_paper_content(self) -> str:
        """Generate sample research paper content."""
        templates = [
            "This study investigates the effects of intervention on outcome. "
            "We conducted a randomized controlled trial with {n} participants. "
            "Results showed a significant effect (p < 0.05). "
            "The findings suggest that the intervention is effective.",

            "Meta-analysis of {n} studies examining the relationship between exposure and outcome. "
            "We used random effects models due to high heterogeneity (I² = {het}%). "
            "The pooled effect size was {es} (95% CI: [{ci_low}, {ci_high}]). "
            "Publication bias assessment using funnel plots revealed no significant asymmetry.",

            "Systematic review including {n} studies published between 2010 and 2024. "
            "Quality assessment using Cochrane Risk of Bias tool indicated moderate quality. "
            "Subgroup analyses revealed differential effects by population characteristics. "
            "Recommendations for future research include larger sample sizes and longer follow-up."
        ]

        template = random.choice(templates)
        return template.format(
            n=random.randint(50, 500),
            het=random.randint(0, 100),
            es=round(random.uniform(0.2, 0.8), 2),
            ci_low=round(random.uniform(0.1, 0.4), 2),
            ci_high=round(random.uniform(0.5, 1.0), 2)
        )


class AdminUser(HttpUser):
    """Simulates admin user performing management tasks."""

    wait_time = between(2, 5)

    @task(5)
    def view_metrics(self):
        """Check Prometheus metrics endpoint."""
        self.client.get("/metrics")

    @task(3)
    def detailed_health(self):
        """Check detailed health status."""
        self.client.get("/health/detailed")

    @task(2)
    def system_metrics(self):
        """Check system metrics endpoint."""
        self.client.get("/health/metrics")

    @task(1)
    def admin_stats(self):
        """Check admin statistics."""
        self.client.get("/api/admin/stats", auth=("admin", "admin123"))


# Event handlers for custom metrics

@events.init_command_line_parser.add_listener
def _(parser):
    """Add custom command line arguments."""
    parser.add_argument("--api-host", type=str, default="http://localhost:8000",
                        help="API host URL")


@events.test_start.add_listener
def _(environment, **kwargs):
    """Log test start."""
    print(f"🚀 Starting load test against {environment.host}")


@events.test_stop.add_listener
def _(environment, **kwargs):
    """Log test completion."""
    print("✅ Load test completed")


if __name__ == "__main__":
    # Can run this file directly for testing
    import os
    os.system("locust -f locustfile.py --host=http://localhost:8000")
