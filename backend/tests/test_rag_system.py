"""
Unit Tests for RAG (Retrieval-Augmented Generation) System
Tests for medical knowledge base, document retrieval, and context-aware generation
"""

import pytest
import pandas as pd
import numpy as np
from dataclasses import asdict
from unittest.mock import Mock, patch, MagicMock
import tempfile
import shutil
import os
import sys

# Add backend to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from ml.rag_system import (
    Document,
    RetrievalResult,
    MedicalKnowledgeBase,
    RAGSystem,
    get_knowledge_base,
    get_rag_system,
    CHROMA_AVAILABLE,
    SENTENCE_TRANSFORMERS_AVAILABLE
)


# =====================================================================
# FIXTURES - Test Data
# =====================================================================

@pytest.fixture
def temp_db_dir():
    """Create temporary directory for vector database"""
    temp_dir = tempfile.mkdtemp()
    yield temp_dir
    # Cleanup
    shutil.rmtree(temp_dir, ignore_errors=True)


@pytest.fixture
def sample_documents():
    """Sample medical documents"""
    return [
        ("doc1", "Meta-analysis shows significant effect of drug treatment on mortality.",
         {"year": 2020, "journal": "Lancet"}),
        ("doc2", "Heterogeneity in meta-analysis can be assessed using I-squared statistic.",
         {"year": 2019, "journal": "BMJ"}),
        ("doc3", "Publication bias is a serious threat to validity of systematic reviews.",
         {"year": 2021, "journal": "JAMA"}),
        ("doc4", "Random-effects model is preferred when heterogeneity is substantial.",
         {"year": 2018, "journal": "Stat Med"}),
        ("doc5", "GRADE approach provides framework for rating quality of evidence.",
         {"year": 2022, "journal": "BMJ"}),
    ]


@pytest.fixture
def sample_studies_df():
    """Sample studies dataframe for RAG"""
    return pd.DataFrame({
        'study_id': ['s1', 's2', 's3'],
        'title': [
            'Effect of Drug A on Mortality',
            'Meta-analysis of Drug A Trials',
            'Systematic Review of Drug A Safety'
        ],
        'abstract': [
            'This RCT evaluated Drug A versus placebo for reducing mortality...',
            'We conducted meta-analysis of 10 RCTs examining Drug A efficacy...',
            'Systematic review of Drug A safety profile across 20 studies...'
        ],
        'year': [2020, 2021, 2022],
        'authors': ['Smith et al.', 'Jones et al.', 'Brown et al.']
    })


@pytest.fixture
def sample_csv_file(tmp_path, sample_documents):
    """Create sample CSV file for testing load_from_csv"""
    csv_path = tmp_path / "documents.csv"

    df = pd.DataFrame([
        {"id": doc_id, "text": text, "year": meta.get("year", 2020)}
        for doc_id, text, meta in sample_documents
    ])

    df.to_csv(csv_path, index=False)
    return str(csv_path)


@pytest.fixture
def mock_embedding_model():
    """Mock sentence transformer model"""
    mock_model = MagicMock()
    mock_model.encode.return_value = np.random.rand(384)  # MiniLM embedding size
    return mock_model


@pytest.fixture
def mock_llm_manager():
    """Mock LLM manager for RAG system"""
    mock_llm = MagicMock()
    mock_llm.is_loaded = True
    mock_llm.generate.return_value = "Based on the context, Drug A shows significant efficacy."
    return mock_llm


# =====================================================================
# TEST: Document Dataclass
# =====================================================================

class TestDocument:
    """Test Document dataclass"""

    def test_document_creation_basic(self):
        """Test creating a basic document"""
        doc = Document(
            id="doc1",
            text="Test document text",
            metadata={"year": 2020}
        )

        assert doc.id == "doc1"
        assert doc.text == "Test document text"
        assert doc.metadata == {"year": 2020}
        assert doc.embedding is None

    def test_document_creation_with_embedding(self):
        """Test creating document with embedding"""
        embedding = np.array([0.1, 0.2, 0.3])
        doc = Document(
            id="doc2",
            text="Text with embedding",
            metadata={},
            embedding=embedding
        )

        assert doc.embedding is not None
        np.testing.assert_array_equal(doc.embedding, embedding)

    def test_document_to_dict(self):
        """Test converting document to dict"""
        doc = Document(
            id="doc3",
            text="Test text",
            metadata={"author": "Smith"}
        )

        doc_dict = asdict(doc)
        assert doc_dict["id"] == "doc3"
        assert doc_dict["text"] == "Test text"
        assert doc_dict["metadata"] == {"author": "Smith"}


# =====================================================================
# TEST: RetrievalResult Dataclass
# =====================================================================

class TestRetrievalResult:
    """Test RetrievalResult dataclass"""

    def test_retrieval_result_creation(self):
        """Test creating retrieval result"""
        docs = [
            Document("d1", "Text 1", {}),
            Document("d2", "Text 2", {})
        ]
        result = RetrievalResult(
            documents=docs,
            scores=[0.9, 0.7],
            query="test query",
            method="semantic"
        )

        assert len(result.documents) == 2
        assert result.scores == [0.9, 0.7]
        assert result.query == "test query"
        assert result.method == "semantic"

    def test_retrieval_result_to_dict(self):
        """Test converting retrieval result to dict"""
        docs = [Document("d1", "Text", {})]
        result = RetrievalResult(
            documents=docs,
            scores=[0.95],
            query="query",
            method="tfidf"
        )

        result_dict = asdict(result)
        assert "documents" in result_dict
        assert "scores" in result_dict
        assert result_dict["method"] == "tfidf"


# =====================================================================
# TEST: MedicalKnowledgeBase Initialization
# =====================================================================

class TestMedicalKnowledgeBaseInitialization:
    """Test MedicalKnowledgeBase initialization"""

    def test_initialization_basic(self, temp_db_dir):
        """Test basic initialization"""
        kb = MedicalKnowledgeBase(
            collection_name="test_collection",
            persist_directory=temp_db_dir
        )

        assert kb.collection_name == "test_collection"
        assert kb.persist_directory == temp_db_dir
        assert kb.documents == []
        assert kb.tfidf_vectorizer is not None  # Always initialized

    def test_initialization_creates_directory(self, temp_db_dir):
        """Test that initialization creates persist directory"""
        new_dir = os.path.join(temp_db_dir, "new_kb")
        assert not os.path.exists(new_dir)

        kb = MedicalKnowledgeBase(persist_directory=new_dir)

        assert os.path.exists(new_dir)

    @pytest.mark.skipif(not CHROMA_AVAILABLE, reason="ChromaDB not available")
    def test_initialization_with_chromadb(self, temp_db_dir):
        """Test initialization with ChromaDB available"""
        kb = MedicalKnowledgeBase(persist_directory=temp_db_dir)

        assert kb.chroma_client is not None
        assert kb.collection is not None

    @pytest.mark.skipif(not SENTENCE_TRANSFORMERS_AVAILABLE,
                        reason="Sentence transformers not available")
    def test_initialization_with_embeddings(self, temp_db_dir):
        """Test initialization with sentence transformers available"""
        kb = MedicalKnowledgeBase(persist_directory=temp_db_dir)

        assert kb.embedding_model is not None


# =====================================================================
# TEST: MedicalKnowledgeBase - Add Documents
# =====================================================================

class TestMedicalKnowledgeBaseAddDocuments:
    """Test adding documents to knowledge base"""

    def test_add_document_basic(self, temp_db_dir):
        """Test adding a single document"""
        kb = MedicalKnowledgeBase(persist_directory=temp_db_dir)

        kb.add_document(
            doc_id="doc1",
            text="Test document about meta-analysis",
            metadata={"year": 2020}
        )

        assert len(kb.documents) == 1
        assert kb.documents[0].id == "doc1"
        assert kb.documents[0].text == "Test document about meta-analysis"

    def test_add_document_without_metadata(self, temp_db_dir):
        """Test adding document without metadata"""
        kb = MedicalKnowledgeBase(persist_directory=temp_db_dir)

        kb.add_document(doc_id="doc2", text="Simple document")

        assert len(kb.documents) == 1
        assert kb.documents[0].metadata == {}

    def test_add_documents_batch(self, temp_db_dir, sample_documents):
        """Test adding multiple documents at once"""
        kb = MedicalKnowledgeBase(persist_directory=temp_db_dir)

        kb.add_documents_batch(sample_documents)

        assert len(kb.documents) == len(sample_documents)
        assert kb.documents[0].id == "doc1"
        assert kb.documents[4].id == "doc5"

    def test_add_documents_updates_tfidf(self, temp_db_dir):
        """Test that adding documents updates TF-IDF index"""
        kb = MedicalKnowledgeBase(persist_directory=temp_db_dir)

        kb.add_document("doc1", "Test document one")
        kb.add_document("doc2", "Test document two")

        assert kb.tfidf_matrix is not None
        assert kb.tfidf_matrix.shape[0] == 2  # 2 documents


# =====================================================================
# TEST: MedicalKnowledgeBase - Retrieval
# =====================================================================

class TestMedicalKnowledgeBaseRetrieval:
    """Test document retrieval from knowledge base"""

    def test_retrieve_tfidf_basic(self, temp_db_dir, sample_documents):
        """Test TF-IDF based retrieval"""
        kb = MedicalKnowledgeBase(persist_directory=temp_db_dir)
        kb.add_documents_batch(sample_documents)

        # Query about heterogeneity
        result = kb.retrieve(
            query="heterogeneity in meta-analysis",
            top_k=3,
            method="tfidf"
        )

        assert isinstance(result, RetrievalResult)
        assert len(result.documents) <= 3
        assert len(result.scores) == len(result.documents)
        assert result.method == "tfidf"
        assert result.query == "heterogeneity in meta-analysis"

        # Check that scores are in descending order
        scores = result.scores
        assert all(scores[i] >= scores[i+1] for i in range(len(scores)-1))

    def test_retrieve_tfidf_relevance(self, temp_db_dir, sample_documents):
        """Test that TF-IDF retrieval returns relevant documents"""
        kb = MedicalKnowledgeBase(persist_directory=temp_db_dir)
        kb.add_documents_batch(sample_documents)

        # Query about publication bias
        result = kb.retrieve(
            query="publication bias systematic review",
            top_k=2,
            method="tfidf"
        )

        # doc3 is about publication bias, should be highly ranked
        doc_ids = [doc.id for doc in result.documents]
        assert "doc3" in doc_ids[:2]  # Should be in top 2

    def test_retrieve_with_top_k(self, temp_db_dir, sample_documents):
        """Test retrieval with different top_k values"""
        kb = MedicalKnowledgeBase(persist_directory=temp_db_dir)
        kb.add_documents_batch(sample_documents)

        result_1 = kb.retrieve("meta-analysis", top_k=1, method="tfidf")
        result_3 = kb.retrieve("meta-analysis", top_k=3, method="tfidf")
        result_10 = kb.retrieve("meta-analysis", top_k=10, method="tfidf")

        assert len(result_1.documents) == 1
        assert len(result_3.documents) == 3
        assert len(result_10.documents) == 5  # Max available

    @pytest.mark.skipif(not SENTENCE_TRANSFORMERS_AVAILABLE,
                        reason="Sentence transformers not available")
    def test_retrieve_semantic(self, temp_db_dir, sample_documents):
        """Test semantic (neural) retrieval"""
        kb = MedicalKnowledgeBase(persist_directory=temp_db_dir)
        kb.add_documents_batch(sample_documents)

        result = kb.retrieve(
            query="how to assess heterogeneity",
            top_k=3,
            method="semantic"
        )

        assert isinstance(result, RetrievalResult)
        assert result.method == "semantic"
        assert len(result.documents) <= 3

    def test_retrieve_empty_kb(self, temp_db_dir):
        """Test retrieval from empty knowledge base"""
        kb = MedicalKnowledgeBase(persist_directory=temp_db_dir)

        result = kb.retrieve("test query", top_k=5)

        assert len(result.documents) == 0
        assert len(result.scores) == 0

    def test_retrieve_fallback_to_tfidf(self, temp_db_dir, sample_documents):
        """Test fallback to TF-IDF when semantic unavailable"""
        kb = MedicalKnowledgeBase(persist_directory=temp_db_dir)
        kb.add_documents_batch(sample_documents)

        # Force embedding model to None
        kb.embedding_model = None

        result = kb.retrieve("query", top_k=3, method="semantic")

        # Should fall back to TF-IDF
        assert isinstance(result, RetrievalResult)
        assert len(result.documents) > 0


# =====================================================================
# TEST: MedicalKnowledgeBase - Load Data
# =====================================================================

class TestMedicalKnowledgeBaseLoadData:
    """Test loading data into knowledge base"""

    def test_load_from_csv_basic(self, temp_db_dir, sample_csv_file):
        """Test loading documents from CSV"""
        kb = MedicalKnowledgeBase(persist_directory=temp_db_dir)

        kb.load_from_csv(
            csv_path=sample_csv_file,
            id_col="id",
            text_col="text"
        )

        assert len(kb.documents) == 5  # 5 documents in sample CSV

    def test_load_from_csv_with_metadata(self, temp_db_dir, sample_csv_file):
        """Test loading CSV with metadata columns"""
        kb = MedicalKnowledgeBase(persist_directory=temp_db_dir)

        kb.load_from_csv(
            csv_path=sample_csv_file,
            id_col="id",
            text_col="text",
            metadata_cols=["year"]
        )

        # Check that metadata was loaded
        assert kb.documents[0].metadata.get("year") is not None

    def test_load_from_csv_missing_file(self, temp_db_dir):
        """Test loading from non-existent CSV file"""
        kb = MedicalKnowledgeBase(persist_directory=temp_db_dir)

        with pytest.raises(Exception):
            kb.load_from_csv("nonexistent.csv")

    def test_load_meta_analysis_studies(self, temp_db_dir, sample_studies_df):
        """Test loading studies from DataFrame"""
        kb = MedicalKnowledgeBase(persist_directory=temp_db_dir)

        kb.load_meta_analysis_studies(sample_studies_df)

        assert len(kb.documents) == 3
        # Check that title and abstract were combined
        assert "Effect of Drug A" in kb.documents[0].text
        assert "This RCT evaluated" in kb.documents[0].text

    def test_load_meta_analysis_studies_metadata(self, temp_db_dir, sample_studies_df):
        """Test that metadata is preserved when loading studies"""
        kb = MedicalKnowledgeBase(persist_directory=temp_db_dir)

        kb.load_meta_analysis_studies(sample_studies_df)

        # Check metadata
        assert kb.documents[0].metadata.get("year") == 2020
        assert kb.documents[0].metadata.get("authors") == "Smith et al."


# =====================================================================
# TEST: RAGSystem Initialization
# =====================================================================

class TestRAGSystemInitialization:
    """Test RAGSystem initialization"""

    def test_initialization_basic(self, temp_db_dir):
        """Test basic RAG system initialization"""
        kb = MedicalKnowledgeBase(persist_directory=temp_db_dir)
        rag = RAGSystem(knowledge_base=kb)

        assert rag.knowledge_base is not None
        assert rag.llm_manager is None  # No LLM provided

    def test_initialization_with_llm(self, temp_db_dir, mock_llm_manager):
        """Test initialization with LLM manager"""
        kb = MedicalKnowledgeBase(persist_directory=temp_db_dir)
        rag = RAGSystem(knowledge_base=kb, llm_manager=mock_llm_manager)

        assert rag.llm_manager is not None
        assert rag.llm_manager.is_loaded == True


# =====================================================================
# TEST: RAGSystem - Generate with Context
# =====================================================================

class TestRAGSystemGenerate:
    """Test RAG system generation methods"""

    def test_generate_with_context_rule_based(self, temp_db_dir, sample_documents):
        """Test rule-based generation (no LLM)"""
        kb = MedicalKnowledgeBase(persist_directory=temp_db_dir)
        kb.add_documents_batch(sample_documents)

        rag = RAGSystem(knowledge_base=kb, llm_manager=None)

        response = rag.generate_with_context(
            query="What is heterogeneity in meta-analysis?",
            top_k=3
        )

        assert isinstance(response, dict)
        assert "response" in response
        assert "sources" in response
        assert "method" in response
        assert response["method"] == "rule_based"
        assert len(response["sources"]) > 0

    def test_generate_with_context_with_llm(self, temp_db_dir, sample_documents, mock_llm_manager):
        """Test generation with LLM"""
        kb = MedicalKnowledgeBase(persist_directory=temp_db_dir)
        kb.add_documents_batch(sample_documents)

        rag = RAGSystem(knowledge_base=kb, llm_manager=mock_llm_manager)

        response = rag.generate_with_context(
            query="Explain publication bias",
            top_k=2,
            max_tokens=200
        )

        assert isinstance(response, dict)
        assert "response" in response
        assert response["method"] == "llm"
        # LLM should have been called
        mock_llm_manager.generate.assert_called_once()

    def test_generate_with_empty_kb(self, temp_db_dir):
        """Test generation with empty knowledge base"""
        kb = MedicalKnowledgeBase(persist_directory=temp_db_dir)
        rag = RAGSystem(knowledge_base=kb)

        response = rag.generate_with_context(
            query="Test query",
            top_k=5
        )

        assert isinstance(response, dict)
        assert "response" in response
        # Should indicate no relevant sources found
        assert len(response["sources"]) == 0

    def test_generate_includes_sources(self, temp_db_dir, sample_documents):
        """Test that response includes source documents"""
        kb = MedicalKnowledgeBase(persist_directory=temp_db_dir)
        kb.add_documents_batch(sample_documents)

        rag = RAGSystem(knowledge_base=kb)

        response = rag.generate_with_context(
            query="publication bias",
            top_k=2
        )

        assert "sources" in response
        assert len(response["sources"]) > 0

        # Check source format
        source = response["sources"][0]
        assert "id" in source
        assert "text" in source
        assert "relevance_score" in source


# =====================================================================
# TEST: RAGSystem - Interpret with Context
# =====================================================================

class TestRAGSystemInterpret:
    """Test RAG system interpretation methods"""

    def test_interpret_with_context_basic(self, temp_db_dir, sample_documents):
        """Test interpreting analysis results with context"""
        kb = MedicalKnowledgeBase(persist_directory=temp_db_dir)
        kb.add_documents_batch(sample_documents)

        rag = RAGSystem(knowledge_base=kb)

        analysis_results = {
            "heterogeneity": {"i_squared": 75, "interpretation": "High"},
            "publication_bias": {"egger_test": 0.03, "interpretation": "Likely"},
            "effect_size": {"pooled_or": 1.5, "ci_lower": 1.2, "ci_upper": 1.9}
        }

        interpretation = rag.interpret_with_context(
            query="Interpret these meta-analysis results",
            analysis_results=analysis_results,
            top_k=3
        )

        assert isinstance(interpretation, dict)
        assert "interpretation" in interpretation
        assert "recommendations" in interpretation
        assert isinstance(interpretation["recommendations"], list)

    def test_interpret_with_empty_results(self, temp_db_dir):
        """Test interpretation with empty analysis results"""
        kb = MedicalKnowledgeBase(persist_directory=temp_db_dir)
        rag = RAGSystem(knowledge_base=kb)

        interpretation = rag.interpret_with_context(
            query="Interpret results",
            analysis_results={},
            top_k=3
        )

        assert isinstance(interpretation, dict)


# =====================================================================
# TEST: Rule-Based Response
# =====================================================================

class TestRuleBasedResponse:
    """Test rule-based response generation"""

    def test_rule_based_response_formats_sources(self, temp_db_dir, sample_documents):
        """Test that rule-based response properly formats sources"""
        kb = MedicalKnowledgeBase(persist_directory=temp_db_dir)
        kb.add_documents_batch(sample_documents[:3])  # Add 3 docs

        rag = RAGSystem(knowledge_base=kb)

        retrieval_result = kb.retrieve("heterogeneity", top_k=2)
        response = rag._rule_based_response("What is heterogeneity?", retrieval_result)

        assert isinstance(response, str)
        assert len(response) > 0
        # Should mention relevant documents
        assert "doc" in response.lower() or "found" in response.lower()


# =====================================================================
# TEST: Factory Functions
# =====================================================================

class TestFactoryFunctions:
    """Test module-level factory functions"""

    def test_get_knowledge_base(self, temp_db_dir):
        """Test get_knowledge_base factory function"""
        kb = get_knowledge_base()

        assert isinstance(kb, MedicalKnowledgeBase)
        assert kb.collection_name == "medical_literature"

    def test_get_rag_system(self, temp_db_dir):
        """Test get_rag_system factory function"""
        rag = get_rag_system()

        assert isinstance(rag, RAGSystem)
        assert rag.knowledge_base is not None


# =====================================================================
# TEST: Edge Cases
# =====================================================================

class TestEdgeCases:
    """Test edge cases and error handling"""

    def test_retrieve_with_zero_top_k(self, temp_db_dir, sample_documents):
        """Test retrieval with top_k=0"""
        kb = MedicalKnowledgeBase(persist_directory=temp_db_dir)
        kb.add_documents_batch(sample_documents)

        result = kb.retrieve("query", top_k=0)

        assert len(result.documents) == 0

    def test_retrieve_with_negative_top_k(self, temp_db_dir, sample_documents):
        """Test retrieval with negative top_k"""
        kb = MedicalKnowledgeBase(persist_directory=temp_db_dir)
        kb.add_documents_batch(sample_documents)

        # Should handle gracefully (treat as 0 or 1)
        result = kb.retrieve("query", top_k=-1)

        assert isinstance(result, RetrievalResult)

    def test_add_document_with_empty_text(self, temp_db_dir):
        """Test adding document with empty text"""
        kb = MedicalKnowledgeBase(persist_directory=temp_db_dir)

        kb.add_document("empty_doc", "")

        assert len(kb.documents) == 1

    def test_retrieve_with_empty_query(self, temp_db_dir, sample_documents):
        """Test retrieval with empty query"""
        kb = MedicalKnowledgeBase(persist_directory=temp_db_dir)
        kb.add_documents_batch(sample_documents)

        result = kb.retrieve("", top_k=3)

        assert isinstance(result, RetrievalResult)

    def test_very_long_document(self, temp_db_dir):
        """Test adding very long document"""
        kb = MedicalKnowledgeBase(persist_directory=temp_db_dir)

        long_text = "word " * 10000  # 10k words
        kb.add_document("long_doc", long_text)

        assert len(kb.documents) == 1
        assert len(kb.documents[0].text) > 10000

    def test_special_characters_in_query(self, temp_db_dir, sample_documents):
        """Test query with special characters"""
        kb = MedicalKnowledgeBase(persist_directory=temp_db_dir)
        kb.add_documents_batch(sample_documents)

        result = kb.retrieve("What is I² (I-squared)? #meta-analysis @statistics", top_k=3)

        assert isinstance(result, RetrievalResult)
        assert len(result.documents) > 0


# =====================================================================
# TEST: Integration Tests
# =====================================================================

class TestRAGIntegration:
    """Integration tests for RAG system"""

    def test_end_to_end_workflow(self, temp_db_dir, sample_documents):
        """Test complete RAG workflow"""
        # 1. Create knowledge base
        kb = MedicalKnowledgeBase(persist_directory=temp_db_dir)

        # 2. Add documents
        kb.add_documents_batch(sample_documents)

        # 3. Create RAG system
        rag = RAGSystem(knowledge_base=kb)

        # 4. Generate response
        response = rag.generate_with_context(
            query="How should I handle heterogeneity in my meta-analysis?",
            top_k=3
        )

        # Verify complete workflow
        assert isinstance(response, dict)
        assert "response" in response
        assert "sources" in response
        assert len(response["sources"]) > 0
        assert "method" in response

    def test_load_and_query_workflow(self, temp_db_dir, sample_studies_df):
        """Test loading studies and querying"""
        # 1. Create KB and load studies
        kb = MedicalKnowledgeBase(persist_directory=temp_db_dir)
        kb.load_meta_analysis_studies(sample_studies_df)

        # 2. Query the loaded studies
        result = kb.retrieve("Drug A efficacy", top_k=2)

        # 3. Verify results are relevant
        assert len(result.documents) > 0
        doc_texts = [doc.text for doc in result.documents]
        # Should find documents about Drug A
        assert any("Drug A" in text for text in doc_texts)


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short", "--cov=ml.rag_system", "--cov-report=term-missing"])
