from typing import Optional, Literal, List

from fastapi import APIRouter, Depends, BackgroundTasks
from pydantic import BaseModel

from dependencies.auth import get_current_user_id
from services.ia_service import (
    load_models,
    get_status,
    recommend_for_user,
    similar_books,
    retrain_models,
    notify_interaction,
)

router = APIRouter(prefix="/ia", tags=["IA"])


class RecommendationOut(BaseModel):
    isbn: str
    titre: str
    auteur: str
    categorie: Optional[str] = None
    image_petite: Optional[str] = None
    resume: Optional[str] = None
    editeur: Optional[str] = None
    langue: Optional[str] = None
    score: float


class SimilarBookOut(BaseModel):
    isbn: str
    titre: str
    auteur: str
    editeur: Optional[str] = None
    image: Optional[str] = None
    similarity: float


class InteractionBody(BaseModel):
    event_type: Literal[
        "collection_add",
        "wishlist_add",
        "rating_add",
        "catalog_update",
        "book_import",
    ]
    isbn: Optional[str] = None


@router.get("/status")
def ia_status():
    return get_status()


@router.get("/recommend", response_model=List[RecommendationOut])
def ia_recommend(
    limit: int = 10,
    current_user_id: int = Depends(get_current_user_id),
):
    return recommend_for_user(current_user_id, limit)


@router.get("/similar", response_model=List[SimilarBookOut])
def ia_similar(
    isbn: str,
    limit: int = 6,
):
    return similar_books(isbn, limit)


@router.post("/reload")
def ia_reload(current_user_id: int = Depends(get_current_user_id)):
    load_models()
    return {"ok": True, "message": "Modèles IA rechargés."}


@router.post("/retrain")
def ia_retrain(
    background_tasks: BackgroundTasks,
    model: Literal["all", "personalized", "content"] = "all",
    current_user_id: int = Depends(get_current_user_id),
):
    background_tasks.add_task(retrain_models, model)
    return {
        "ok": True,
        "message": f"Réentraînement lancé en arrière-plan: {model}",
    }


@router.post("/webhooks/interaction")
def ia_webhook_interaction(
    body: InteractionBody,
    background_tasks: BackgroundTasks,
    current_user_id: int = Depends(get_current_user_id),
):
    result = notify_interaction(body.event_type)

    if result["should_retrain"]:
        background_tasks.add_task(retrain_models, result["model_to_retrain"])

    return result
