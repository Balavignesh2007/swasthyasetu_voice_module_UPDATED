"""Retrieval-Augmented Generation (RAG) Engine for SwasthyaSetu.

Indexes rural health FAQ knowledge base (maternal health, immunization, emergency first aid,
child nutrition, common village diseases, public health schemes).
Uses SentenceTransformers for semantic search with rapid token-overlap fallback.
"""

import os
import json
import logging
import numpy as np
from typing import List, Dict, Any, Optional

logger = logging.getLogger(__name__)

FAQ_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "data", "medical_faq.json")


class RAGEngine:
    def __init__(self, faq_file: str = FAQ_PATH):
        self.faq_file = faq_file
        self.documents: List[Dict[str, Any]] = []
        self._embeddings: Optional[np.ndarray] = None
        self._model = None
        self._model_load_attempted = False
        self.load_documents()

    @property
    def faq_items(self) -> List[Dict[str, Any]]:
        return self.documents

    def search(self, query: str, top_k: int = 3) -> List[Dict[str, Any]]:
        return self.retrieve(query, top_k=top_k)

    def retrieve_context(self, query: str, top_k: int = 3) -> str:
        results = self.retrieve(query, top_k=top_k)
        return self.format_context(results)

    def load_documents(self):
        """Loads FAQ questions and answers from JSON file."""
        if not os.path.exists(self.faq_file):
            logger.warning(f"FAQ file not found at {self.faq_file}")
            self.documents = []
            return

        try:
            with open(self.faq_file, "r", encoding="utf-8") as f:
                self.documents = json.load(f)
            logger.info(f"Loaded {len(self.documents)} medical FAQ entries.")
        except Exception as e:
            logger.error(f"Failed to load FAQ knowledge base: {e}")
            self.documents = []

    def _get_embedding_model(self):
        """Lazy load sentence-transformers model without blocking on remote downloads."""
        if not self._model_load_attempted:
            self._model_load_attempted = True
            try:
                from sentence_transformers import SentenceTransformer
                model_name = os.getenv("SENTENCE_TRANSFORMER_MODEL", "sentence-transformers/all-MiniLM-L6-v2")
                # Attempt to load only from local cache to prevent network hang
                self._model = SentenceTransformer(model_name, local_files_only=True)
                logger.info(f"RAGEngine: Loaded cached SentenceTransformer {model_name}")
            except Exception:
                logger.info("RAGEngine: Using fast deterministic lexical retrieval for FAQ RAG.")
                self._model = None
        return self._model

    def _build_embeddings(self):
        """Precompute embeddings for all FAQ entries."""
        model = self._get_embedding_model()
        if model is None or not self.documents:
            return

        texts = [f"{doc.get('category', '')}: {doc.get('question', '')} {doc.get('answer', '')}" for doc in self.documents]
        try:
            self._embeddings = model.encode(texts, convert_to_numpy=True, normalize_embeddings=True)
            logger.info(f"Indexed {len(texts)} document embeddings for RAG.")
        except Exception as e:
            logger.error(f"Error computing document embeddings: {e}")
            self._embeddings = None

    def retrieve(self, query: str, top_k: int = 3) -> List[Dict[str, Any]]:
        """Retrieve most relevant medical FAQ items for a given query."""
        if not query or not self.documents:
            return []

        # 1. Try Dense Semantic Search if cached locally
        model = self._get_embedding_model()
        if model is not None:
            if self._embeddings is None:
                self._build_embeddings()

            if self._embeddings is not None:
                try:
                    q_emb = model.encode([query], convert_to_numpy=True, normalize_embeddings=True)[0]
                    scores = np.dot(self._embeddings, q_emb)
                    top_indices = np.argsort(scores)[::-1][:top_k]

                    results = []
                    for idx in top_indices:
                        score = float(scores[idx])
                        if score > 0.20:
                            results.append({**self.documents[idx], "score": round(score, 3)})
                    if results:
                        return results
                except Exception as e:
                    logger.warning(f"Dense retrieval error: {e}. Falling back to lexical search.")

        # 2. Lexical / Keyword Token-Overlap Fallback
        query_words = set(re.findall(r"\w+", query.lower()))
        stop_words = {"the", "a", "an", "is", "are", "in", "on", "at", "to", "for", "of", "and", "or", "what", "how", "why", "when", "can"}
        content_words = query_words - stop_words
        if not content_words:
            content_words = query_words

        scored_docs = []
        for doc in self.documents:
            q_text = doc.get("question", "").lower()
            a_text = doc.get("answer", "").lower()
            cat = doc.get("category", "").lower()

            q_tokens = set(re.findall(r"\w+", q_text))
            a_tokens = set(re.findall(r"\w+", a_text))
            cat_tokens = set(re.findall(r"\w+", cat))

            q_overlap = len(content_words.intersection(q_tokens))
            cat_overlap = len(content_words.intersection(cat_tokens))
            a_overlap = len(content_words.intersection(a_tokens))

            total_score = (q_overlap * 4.0) + (cat_overlap * 3.0) + (a_overlap * 1.0)
            if total_score > 0:
                scored_docs.append((total_score, doc))

        scored_docs.sort(key=lambda x: x[0], reverse=True)
        return [{**doc, "score": round(score, 2)} for score, doc in scored_docs[:top_k]]


    @property
    def faq_items(self) -> List[Dict[str, Any]]:
        return self.documents

    def search(self, query: str, top_k: int = 3) -> List[Dict[str, Any]]:
        """Alias for retrieve to support search interface."""
        return self.retrieve(query, top_k=top_k)

    def retrieve_context(self, query: str, top_k: int = 3) -> str:
        """Retrieve matching FAQ entries and format as context string."""
        docs = self.retrieve(query, top_k=top_k)
        return self.format_context(docs)

    def format_context(self, items: List[Dict[str, Any]]) -> str:
        """Format retrieved FAQ items into clean text block for LLM prompt."""
        if not items:
            return ""
        blocks = []
        for i, item in enumerate(items, 1):
            blocks.append(
                f"[{i}] Topic: {item.get('category', 'General')}\n"
                f"Question: {item.get('question', '')}\n"
                f"Answer: {item.get('answer', '')}"
            )
        return "\n\n".join(blocks)


rag_engine = RAGEngine()

