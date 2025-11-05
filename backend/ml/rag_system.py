"""
Retrieval-Augmented Generation (RAG) for Medical Literature
Enhances local Llama 3 with medical knowledge retrieval
Based on 2025 best practices: RAG + Fine-tuning (RAFT)
"""
import numpy as np
import pandas as pd
from typing import List, Dict, Optional, Any, Tuple
from dataclasses import dataclass
import logging
import os
import json
from pathlib import Path

logger = logging.getLogger(__name__)

# Vector database for embeddings
try:
    import chromadb
    from chromadb.config import Settings
    CHROMA_AVAILABLE = True
except ImportError:
    CHROMA_AVAILABLE = False
    logger.warning("ChromaDB not installed. Install with: pip install chromadb")

# Embeddings
try:
    from sentence_transformers import SentenceTransformer
    SENTENCE_TRANSFORMERS_AVAILABLE = True
except ImportError:
    SENTENCE_TRANSFORMERS_AVAILABLE = False
    logger.warning("sentence-transformers not installed. Install with: pip install sentence-transformers")

# Fallback: TF-IDF
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity


@dataclass
class Document:
    """Document in knowledge base"""
    id: str
    text: str
    metadata: Dict[str, Any]
    embedding: Optional[np.ndarray] = None


@dataclass
class RetrievalResult:
    """Result from retrieval"""
    documents: List[Document]
    scores: List[float]
    query: str
    method: str  # "semantic", "tfidf", "hybrid"


class MedicalKnowledgeBase:
    """
    Medical literature knowledge base with semantic search
    Supports both neural embeddings (sentence-transformers) and TF-IDF fallback
    """

    def __init__(self, collection_name: str = "medical_literature",
                 embedding_model: str = "all-MiniLM-L6-v2",
                 persist_directory: Optional[str] = None):
        """
        Initialize knowledge base

        Args:
            collection_name: Name of document collection
            embedding_model: Sentence transformer model name
            persist_directory: Directory to persist database
        """
        self.collection_name = collection_name
        self.embedding_model_name = embedding_model
        self.persist_directory = persist_directory or "./data/vector_db"

        # Initialize components
        self.chroma_client = None
        self.collection = None
        self.embedding_model = None
        self.tfidf_vectorizer = None
        self.tfidf_matrix = None
        self.documents = []

        self._initialize()

    def _initialize(self):
        """Initialize vector database and embedding model"""
        # Create persist directory
        Path(self.persist_directory).mkdir(parents=True, exist_ok=True)

        # Try to initialize ChromaDB
        if CHROMA_AVAILABLE:
            try:
                self.chroma_client = chromadb.PersistentClient(
                    path=self.persist_directory
                )
                self.collection = self.chroma_client.get_or_create_collection(
                    name=self.collection_name,
                    metadata={"description": "Medical literature for meta-analysis"}
                )
                logger.info(f"✓ ChromaDB initialized: {len(self.collection.get()['ids'])} documents")
            except Exception as e:
                logger.error(f"Failed to initialize ChromaDB: {str(e)}")
                self.chroma_client = None

        # Try to load embedding model
        if SENTENCE_TRANSFORMERS_AVAILABLE:
            try:
                self.embedding_model = SentenceTransformer(self.embedding_model_name)
                logger.info(f"✓ Sentence transformer loaded: {self.embedding_model_name}")
            except Exception as e:
                logger.error(f"Failed to load embedding model: {str(e)}")
                self.embedding_model = None

        # Initialize TF-IDF as fallback
        self.tfidf_vectorizer = TfidfVectorizer(
            max_features=1000,
            stop_words='english',
            ngram_range=(1, 2)
        )
        logger.info("✓ TF-IDF vectorizer initialized (fallback)")

    def add_document(self, doc_id: str, text: str, metadata: Optional[Dict[str, Any]] = None):
        """
        Add document to knowledge base

        Args:
            doc_id: Unique document ID
            text: Document text
            metadata: Optional metadata (author, year, DOI, etc.)
        """
        metadata = metadata or {}

        # Create document
        doc = Document(id=doc_id, text=text, metadata=metadata)

        # Add to ChromaDB if available
        if self.chroma_client and self.collection:
            try:
                # Generate embedding
                if self.embedding_model:
                    embedding = self.embedding_model.encode(text).tolist()
                else:
                    embedding = None

                self.collection.add(
                    ids=[doc_id],
                    documents=[text],
                    metadatas=[metadata],
                    embeddings=[embedding] if embedding else None
                )
                logger.debug(f"Document {doc_id} added to ChromaDB")
            except Exception as e:
                logger.error(f"Failed to add document to ChromaDB: {str(e)}")

        # Add to in-memory list
        self.documents.append(doc)

    def add_documents_batch(self, documents: List[Tuple[str, str, Dict[str, Any]]]):
        """
        Add multiple documents efficiently

        Args:
            documents: List of (id, text, metadata) tuples
        """
        if not documents:
            return

        ids, texts, metadatas = zip(*documents)

        # Add to ChromaDB
        if self.chroma_client and self.collection:
            try:
                # Generate embeddings
                if self.embedding_model:
                    embeddings = self.embedding_model.encode(list(texts)).tolist()
                else:
                    embeddings = None

                self.collection.add(
                    ids=list(ids),
                    documents=list(texts),
                    metadatas=list(metadatas),
                    embeddings=embeddings
                )
                logger.info(f"✓ Added {len(documents)} documents to ChromaDB")
            except Exception as e:
                logger.error(f"Failed to add batch to ChromaDB: {str(e)}")

        # Add to in-memory list
        for doc_id, text, metadata in documents:
            self.documents.append(Document(id=doc_id, text=text, metadata=metadata))

        # Rebuild TF-IDF index
        self._rebuild_tfidf_index()

    def _rebuild_tfidf_index(self):
        """Rebuild TF-IDF index from documents"""
        if not self.documents:
            return

        texts = [doc.text for doc in self.documents]
        try:
            self.tfidf_matrix = self.tfidf_vectorizer.fit_transform(texts)
            logger.debug(f"TF-IDF index rebuilt: {len(texts)} documents")
        except Exception as e:
            logger.error(f"Failed to rebuild TF-IDF index: {str(e)}")

    def retrieve(self, query: str, top_k: int = 5,
                method: str = "auto") -> RetrievalResult:
        """
        Retrieve relevant documents for query

        Args:
            query: Search query
            top_k: Number of documents to retrieve
            method: "semantic" (embeddings), "tfidf", "auto" (best available)

        Returns:
            RetrievalResult with documents and scores
        """
        # Determine method
        if method == "auto":
            if self.chroma_client and self.collection:
                method = "semantic"
            elif self.tfidf_matrix is not None:
                method = "tfidf"
            else:
                return RetrievalResult(
                    documents=[],
                    scores=[],
                    query=query,
                    method="none"
                )

        # Semantic search with ChromaDB
        if method == "semantic" and self.chroma_client and self.collection:
            try:
                results = self.collection.query(
                    query_texts=[query],
                    n_results=min(top_k, len(self.documents))
                )

                docs = []
                scores = []

                for idx, (doc_id, text, metadata, distance) in enumerate(zip(
                    results['ids'][0],
                    results['documents'][0],
                    results['metadatas'][0],
                    results['distances'][0]
                )):
                    doc = Document(id=doc_id, text=text, metadata=metadata)
                    docs.append(doc)
                    # Convert distance to similarity score (1 - normalized_distance)
                    scores.append(1.0 / (1.0 + distance))

                logger.debug(f"Semantic search: {len(docs)} documents retrieved")

                return RetrievalResult(
                    documents=docs,
                    scores=scores,
                    query=query,
                    method="semantic"
                )

            except Exception as e:
                logger.error(f"Semantic search failed: {str(e)}")
                method = "tfidf"  # Fallback

        # TF-IDF search
        if method == "tfidf" and self.tfidf_matrix is not None:
            try:
                # Transform query
                query_vec = self.tfidf_vectorizer.transform([query])

                # Compute similarities
                similarities = cosine_similarity(query_vec, self.tfidf_matrix)[0]

                # Get top-k
                top_indices = np.argsort(similarities)[::-1][:top_k]

                docs = [self.documents[idx] for idx in top_indices]
                scores = [float(similarities[idx]) for idx in top_indices]

                logger.debug(f"TF-IDF search: {len(docs)} documents retrieved")

                return RetrievalResult(
                    documents=docs,
                    scores=scores,
                    query=query,
                    method="tfidf"
                )

            except Exception as e:
                logger.error(f"TF-IDF search failed: {str(e)}")

        # No results
        return RetrievalResult(
            documents=[],
            scores=[],
            query=query,
            method="none"
        )

    def load_from_csv(self, csv_path: str, id_col: str = "id",
                     text_col: str = "text", metadata_cols: Optional[List[str]] = None):
        """
        Load documents from CSV file

        Args:
            csv_path: Path to CSV file
            id_col: Column name for document ID
            text_col: Column name for document text
            metadata_cols: List of columns to include as metadata
        """
        try:
            df = pd.read_csv(csv_path)

            if id_col not in df.columns or text_col not in df.columns:
                logger.error(f"CSV must have {id_col} and {text_col} columns")
                return

            documents = []
            for _, row in df.iterrows():
                doc_id = str(row[id_col])
                text = str(row[text_col])

                metadata = {}
                if metadata_cols:
                    for col in metadata_cols:
                        if col in df.columns:
                            metadata[col] = str(row[col])

                documents.append((doc_id, text, metadata))

            self.add_documents_batch(documents)
            logger.info(f"✓ Loaded {len(documents)} documents from {csv_path}")

        except Exception as e:
            logger.error(f"Failed to load CSV: {str(e)}")

    def load_meta_analysis_studies(self, studies_df: pd.DataFrame):
        """
        Load studies from meta-analysis as documents
        Creates searchable knowledge base from study data

        Args:
            studies_df: DataFrame with study information
        """
        documents = []

        for idx, row in studies_df.iterrows():
            # Create document ID
            doc_id = f"study_{idx}"

            # Create document text from study fields
            text_parts = []

            if 'study_id' in row:
                text_parts.append(f"Study ID: {row['study_id']}")
            if 'title' in row:
                text_parts.append(f"Title: {row['title']}")
            if 'authors' in row:
                text_parts.append(f"Authors: {row['authors']}")
            if 'abstract' in row:
                text_parts.append(f"Abstract: {row['abstract']}")
            if 'intervention' in row:
                text_parts.append(f"Intervention: {row['intervention']}")
            if 'outcome' in row:
                text_parts.append(f"Outcome: {row['outcome']}")
            if 'population' in row:
                text_parts.append(f"Population: {row['population']}")

            text = " | ".join(text_parts)

            # Create metadata
            metadata = {
                'type': 'meta_analysis_study',
                'index': idx
            }

            for col in ['year', 'study_design', 'risk_of_bias', 'country', 'n']:
                if col in row:
                    metadata[col] = str(row[col])

            documents.append((doc_id, text, metadata))

        self.add_documents_batch(documents)
        logger.info(f"✓ Loaded {len(documents)} meta-analysis studies into knowledge base")


class RAGSystem:
    """
    Complete RAG system integrating knowledge base with LLM
    Follows 2025 best practices for medical AI
    """

    def __init__(self, knowledge_base: MedicalKnowledgeBase,
                 llm_manager: Optional[Any] = None):
        """
        Initialize RAG system

        Args:
            knowledge_base: Medical knowledge base
            llm_manager: Local Llama manager (from llm_integration.py)
        """
        self.knowledge_base = knowledge_base
        self.llm_manager = llm_manager

    def generate_with_context(self, query: str, top_k: int = 5,
                              max_tokens: int = 512) -> Dict[str, Any]:
        """
        Generate response using retrieval-augmented generation

        Args:
            query: User query
            top_k: Number of documents to retrieve
            max_tokens: Maximum tokens in response

        Returns:
            Response with sources and metadata
        """
        # Retrieve relevant documents
        retrieval_result = self.knowledge_base.retrieve(query, top_k=top_k)

        if not retrieval_result.documents:
            context = "No relevant documents found."
        else:
            # Build context from retrieved documents
            context_parts = []
            for idx, (doc, score) in enumerate(zip(retrieval_result.documents,
                                                   retrieval_result.scores)):
                context_parts.append(f"[Source {idx+1}] (relevance: {score:.2f}):\n{doc.text}")

            context = "\n\n".join(context_parts)

        # Create RAG prompt
        rag_prompt = f"""You are a medical research assistant helping with meta-analysis.
Use the following context from relevant studies to answer the question.
If the context doesn't contain enough information, acknowledge the limitations.

Context:
{context}

Question: {query}

Answer (be specific and cite sources when possible):"""

        # Generate response with LLM if available
        if self.llm_manager and self.llm_manager.is_loaded:
            try:
                response = self.llm_manager.generate(rag_prompt, max_tokens=max_tokens)
            except Exception as e:
                logger.error(f"LLM generation failed: {str(e)}")
                response = self._rule_based_response(query, retrieval_result)
        else:
            # Rule-based fallback
            response = self._rule_based_response(query, retrieval_result)

        return {
            'query': query,
            'response': response,
            'sources': [
                {
                    'id': doc.id,
                    'text': doc.text[:200] + "..." if len(doc.text) > 200 else doc.text,
                    'metadata': doc.metadata,
                    'relevance_score': score
                }
                for doc, score in zip(retrieval_result.documents, retrieval_result.scores)
            ],
            'retrieval_method': retrieval_result.method,
            'n_sources': len(retrieval_result.documents)
        }

    def _rule_based_response(self, query: str, retrieval_result: RetrievalResult) -> str:
        """Generate rule-based response when LLM unavailable"""
        if not retrieval_result.documents:
            return "I couldn't find relevant information to answer this question."

        # Extract key information from top documents
        top_doc = retrieval_result.documents[0]

        response = f"Based on the retrieved evidence (relevance: {retrieval_result.scores[0]:.2f}):\n\n"
        response += top_doc.text[:500]

        if len(retrieval_result.documents) > 1:
            response += f"\n\nAdditional sources found: {len(retrieval_result.documents) - 1}"

        return response

    def interpret_with_context(self, query: str, analysis_results: Dict[str, Any],
                              top_k: int = 3) -> str:
        """
        Interpret analysis results with context from literature

        Args:
            query: Interpretation query
            analysis_results: Results from meta-analysis
            top_k: Number of context documents

        Returns:
            Interpretation with evidence
        """
        # Retrieve context
        retrieval_result = self.knowledge_base.retrieve(query, top_k=top_k)

        # Build enhanced prompt
        prompt = f"""Interpret the following meta-analysis results:

Results:
{json.dumps(analysis_results, indent=2)}

Question: {query}

"""

        if retrieval_result.documents:
            prompt += "Relevant context from literature:\n"
            for idx, doc in enumerate(retrieval_result.documents[:3]):
                prompt += f"{idx+1}. {doc.text[:300]}...\n\n"

        prompt += "Interpretation:"

        # Generate
        if self.llm_manager and self.llm_manager.is_loaded:
            try:
                return self.llm_manager.generate(prompt, max_tokens=512)
            except:
                pass

        # Fallback
        return f"Analysis shows: {analysis_results.get('summary', 'Results available')}"


# Global instance (initialized on first use)
_global_knowledge_base: Optional[MedicalKnowledgeBase] = None
_global_rag_system: Optional[RAGSystem] = None


def get_knowledge_base() -> MedicalKnowledgeBase:
    """Get or create global knowledge base"""
    global _global_knowledge_base
    if _global_knowledge_base is None:
        _global_knowledge_base = MedicalKnowledgeBase()
    return _global_knowledge_base


def get_rag_system(llm_manager: Optional[Any] = None) -> RAGSystem:
    """Get or create global RAG system"""
    global _global_rag_system
    if _global_rag_system is None:
        kb = get_knowledge_base()
        _global_rag_system = RAGSystem(kb, llm_manager)
    return _global_rag_system
